# =============================================================================
# Run Mode Execution Functions
# =============================================================================
# Execute workflows with full context aggregation and dependency resolution.
# =============================================================================

# Execute workflow in run mode
# Arguments:
#   $@ - Execution options (model, temperature, input files, etc.)
execute_run_mode() {
    # Set execution parameter defaults (respect WIREFLOW_DRY_RUN env var)
    local stream_mode=false  # Default to batch in run mode
    local count_tokens_only=false
    local dry_run="${WIREFLOW_DRY_RUN:-false}"
    
    # Initialize CLI override arrays (paths can be files or directories)
    local -a cli_input_paths=()
    local -a cli_context_paths=()
    
    # Parse execution options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --stream|-s)
                stream_mode=true
                shift
                ;;
            --dry-run|-n)
                dry_run=true
                shift
                ;;
            --count-tokens)
                count_tokens_only=true
                shift
                ;;
            --input|-in)
                shift
                [[ $# -eq 0 || "$1" =~ ^- ]] && { echo "Error: --input requires at least one argument" >&2; return 1; }
                while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                    cli_input_paths+=("$1")
                    shift
                done
                ;;
            --context|-cx)
                shift
                [[ $# -eq 0 || "$1" =~ ^- ]] && { echo "Error: --context requires at least one argument" >&2; return 1; }
                while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                    cli_context_paths+=("$1")
                    shift
                done
                ;;
            --)
                shift
                # All remaining arguments are input file/directory paths
                while [[ $# -gt 0 ]]; do
                    cli_input_paths+=("$1")
                    shift
                done
                ;;
            --depends-on|-dp)
                shift
                [[ $# -eq 0 || "$1" =~ ^- ]] && { echo "Error: --depends-on requires at least one argument" >&2; return 1; }
                while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                    DEPENDS_ON+=("$1")
                    shift
                done
                WORKFLOW_SOURCE_MAP[DEPENDS_ON]="cli"
                ;;
            --export|-ex)
                shift
                [[ $# -eq 0 ]] && { echo "Error: --export requires argument" >&2; return 1; }
                EXPORT_PATH="$1"
                WORKFLOW_SOURCE_MAP[EXPORT_PATH]="cli"
                shift
                ;;
            --profile)
                shift
                [[ $# -eq 0 ]] && { echo "Error: --profile requires argument" >&2; return 1; }
                PROFILE="$1"
                CONFIG_SOURCE_MAP[PROFILE]="cli"
                shift
                ;;
            --model|-m)
                shift
                [[ $# -eq 0 ]] && { echo "Error: --model requires argument" >&2; return 1; }
                MODEL="$1"
                CONFIG_SOURCE_MAP[MODEL]="cli"
                shift
                ;;
            --enable-thinking)
                ENABLE_THINKING=true
                CONFIG_SOURCE_MAP[ENABLE_THINKING]="cli"
                shift
                ;;
            --disable-thinking)
                ENABLE_THINKING=false
                CONFIG_SOURCE_MAP[ENABLE_THINKING]="cli"
                shift
                ;;
            --thinking-budget)
                shift
                [[ $# -eq 0 ]] && { echo "Error: --thinking-budget requires argument" >&2; return 1; }
                THINKING_BUDGET="$1"
                CONFIG_SOURCE_MAP[THINKING_BUDGET]="cli"
                shift
                ;;
            --effort)
                shift
                [[ $# -eq 0 ]] && { echo "Error: --effort requires argument" >&2; return 1; }
                EFFORT="$1"
                CONFIG_SOURCE_MAP[EFFORT]="cli"
                shift
                ;;
            --temperature|-t)
                shift
                [[ $# -eq 0 ]] && { echo "Error: --temperature requires argument" >&2; return 1; }
                TEMPERATURE="$1"
                CONFIG_SOURCE_MAP[TEMPERATURE]="cli"
                shift
                ;;
            --max-tokens)
                shift
                [[ $# -eq 0 ]] && { echo "Error: --max-tokens requires argument" >&2; return 1; }
                MAX_TOKENS="$1"
                CONFIG_SOURCE_MAP[MAX_TOKENS]="cli"
                shift
                ;;
            --system|-p)
                shift
                [[ $# -eq 0 ]] && { echo "Error: --system requires argument" >&2; return 1; }
                IFS=',' read -ra SYSTEM_PROMPTS <<< "$1"
                CONFIG_SOURCE_MAP[SYSTEM_PROMPTS]="cli"
                shift
                ;;
            --format|-f)
                shift
                [[ $# -eq 0 ]] && { echo "Error: --format requires argument" >&2; return 1; }
                OUTPUT_FORMAT="$1"
                CONFIG_SOURCE_MAP[OUTPUT_FORMAT]="cli"
                shift
                ;;
            --enable-citations)
                ENABLE_CITATIONS=true
                CONFIG_SOURCE_MAP[ENABLE_CITATIONS]="cli"
                shift
                ;;
            --disable-citations)
                ENABLE_CITATIONS=false
                CONFIG_SOURCE_MAP[ENABLE_CITATIONS]="cli"
                shift
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                show_quick_help_run
                return 1
                ;;
        esac
    done
    
    # =============================================================================
    # Setup Paths
    # =============================================================================
    
    # Task prompt file
    local task_prompt_file="$WORKFLOW_DIR/task.txt"
    
    # Validate task file exists
    if [[ ! -f "$task_prompt_file" ]]; then
        echo "Error: Task file not found: $task_prompt_file" >&2
        echo "Workflow may be incomplete. Re-create with: $SCRIPT_NAME new $WORKFLOW_NAME" >&2
        return 1
    fi
    
    # JSON block files for API
    local system_blocks_file="$WORKFLOW_DIR/system-blocks.json"
    local user_blocks_file="$WORKFLOW_DIR/user-blocks.json"
    local request_json_file="$WORKFLOW_DIR/request.json"
    local document_map_file="$WORKFLOW_DIR/document-map.json"
    
    # Output files
    local output_file="$WORKFLOW_DIR/output.${OUTPUT_FORMAT}"
    local output_link="$OUTPUT_DIR/${WORKFLOW_NAME}.${OUTPUT_FORMAT}"
    
    # Set CLI-provided paths for aggregation (must match execute.sh variable names)
    # These can be files or directories; execute.sh handles expansion
    CLI_INPUT_PATHS=("${cli_input_paths[@]}")
    CLI_CONTEXT_PATHS=("${cli_context_paths[@]}")

    # Reset global content block arrays for this run
    SYSTEM_BLOCKS=()
    CONTEXT_BLOCKS=()
    DEPENDENCY_BLOCKS=()
    INPUT_BLOCKS=()
    IMAGE_BLOCKS=()
    DOCUMENT_INDEX_MAP=()

    # =============================================================================
    # Build System Prompt
    # =============================================================================
    
    if ! build_system_prompt; then
        echo "Error: Failed to build system prompt" >&2
        return 1
    fi
    
    # =============================================================================
    # Context Aggregation
    # =============================================================================
    
    aggregate_context "run" "$PROJECT_ROOT" "$WORKFLOW_DIR"
    
    # =============================================================================
    # Build Final Prompts
    # =============================================================================
    
    build_prompts "$PROJECT_ROOT" "$task_prompt_file"

    # =============================================================================
    # Token Estimation (if requested)
    # =============================================================================

    if $count_tokens_only; then
        estimate_tokens
        return 0
    fi
    
    # =============================================================================
    # Dry-Run Mode
    # =============================================================================
    
    if $dry_run; then
        handle_dry_run_mode "run" "$WORKFLOW_DIR"
        return 0
    fi
    
    # =============================================================================
    # Execute API Request
    # =============================================================================

    # Check if workflow has BATCH_MODE=true in config - route to batch subcommand
    if [[ "$BATCH_MODE" == "true" ]]; then
        echo "Note: This workflow has BATCH_MODE=true configured."
        echo "Routing to batch processing mode..."
        echo ""

        # Execute batch mode
        execute_batch_mode "run" "$PROJECT_ROOT" "$WORKFLOW_DIR"
        local batch_result=$?

        if [[ $batch_result -ne 0 ]]; then
            echo "Error: Batch submission failed" >&2
            return $batch_result
        fi

        # Note: cmd_batch displays management commands after execute_batch_mode
        # so we only show them here for BATCH_MODE=true workflows run via `wfw run`
        echo ""
        echo "Use '$SCRIPT_NAME batch status|results|cancel $WORKFLOW_NAME' to manage this batch."
        return 0
    fi

    # Set streaming mode
    STREAM_MODE=$stream_mode

    # Execute API request
    execute_api_request "run" "$output_file" ""
    local api_result=$?

    if [[ $api_result -ne 0 ]]; then
        echo "Error: API request failed" >&2
        return $api_result
    fi
    
    # =============================================================================
    # Post-Processing
    # =============================================================================
    
    # Convert JSON files to XML (optional, if yq available)
    convert_json_to_xml "$WORKFLOW_DIR"
    
    echo "Response saved to: $(display_absolute_path "$output_file")"
    
    # Format-specific post-processing
    if [[ -f "$output_file" ]]; then
        case "$OUTPUT_FORMAT" in
            md|markdown)
                if command -v mdformat &>/dev/null; then
                    echo "Formatting output with mdformat..."
                    mdformat --no-validate "$output_file"
                fi
                ;;
            json)
                if command -v jq &>/dev/null; then
                    echo "Formatting output with jq..."
                    jq . "$output_file" > "${output_file}.tmp" && mv "${output_file}.tmp" "$output_file"
                fi
                ;;
            # txt, html, etc. - no formatting needed
        esac
    fi
    
    # Create/update hardlink in output directory
    mkdir -p "$OUTPUT_DIR"
    if [[ -f "$output_link" ]]; then
        rm "$output_link"
    fi
    ln "$output_file" "$output_link"
    echo "Hardlink created: $(display_absolute_path "$output_link")"
    
    # Copy output file to EXPORT_PATH if specified
    if [[ -n "$EXPORT_PATH" ]]; then
        # Resolve path: expand ~/, resolve relative paths to project root
        local resolved_path="${EXPORT_PATH/#\~/$HOME}"
        if [[ "$resolved_path" != /* ]]; then
            resolved_path="$PROJECT_ROOT/$resolved_path"
        fi
        
        # Create parent directories
        local export_dir=$(dirname "$resolved_path")
        if mkdir -p "$export_dir" 2>/dev/null; then
            # Copy with preserved timestamps
            if cp -p "$output_file" "$resolved_path" 2>/dev/null; then
                echo "Response exported to: $(display_absolute_path "$resolved_path")"
            else
                echo "Warning: Export failed to $resolved_path" >&2
            fi
        else
            echo "Warning: Failed to create export directory $export_dir" >&2
        fi
    fi
    
    echo
    echo "Workflow '$WORKFLOW_NAME' completed successfully!"
    
    return 0
}
