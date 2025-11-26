# =============================================================================
# Task Mode Execution Functions
# =============================================================================
# Lightweight one-off task execution without creating workflow directories.
# Supports named tasks from files or inline task specifications.
# =============================================================================

# Execute task in standalone mode
# Arguments:
#   $1 - Task content (text)
#   $2 - Task source (name or "inline")
#   $@ - Execution options (model, temperature, input files, etc.)
execute_task_mode() {
    local task_content="$1"
    local task_source="$2"
    shift 2
    
    # Validate task content
    if [[ -z "$task_content" ]]; then
        echo "Error: Empty task content" >&2
        return 1
    fi
    
    # Initialize task-specific variables (paths can be files or directories)
    local -a cli_input_paths=()
    local -a cli_context_paths=()
    local output_file_path=""
    local stream_mode=true  # Default to streaming in task mode
    local count_tokens_only=false
    local dry_run="${WIREFLOW_DRY_RUN:-false}"
    
    # Parse execution options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --input|-in)
                shift
                [[ $# -eq 0 ]] && { echo "Error: --input requires argument" >&2; return 1; }
                cli_input_paths+=("$1")
                shift
                ;;
            --context|-cx)
                shift
                [[ $# -eq 0 ]] && { echo "Error: --context requires argument" >&2; return 1; }
                cli_context_paths+=("$1")
                shift
                ;;
            --)
                shift
                # All remaining arguments are input file/directory paths
                while [[ $# -gt 0 ]]; do
                    cli_input_paths+=("$1")
                    shift
                done
                ;;
            --export|-ex)
                shift
                [[ $# -eq 0 ]] && { echo "Error: --export requires argument" >&2; return 1; }
                output_file_path="$1"
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
            --stream|-s)
                stream_mode=true
                shift
                ;;
            --no-stream|-b)
                stream_mode=false
                shift
                ;;
            --count-tokens)
                count_tokens_only=true
                shift
                ;;
            --dry-run|-n)
                dry_run=true
                shift
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                show_quick_help_task
                return 1
                ;;
        esac
    done
    
    # =============================================================================
    # Optional Project Discovery and Configuration
    # =============================================================================
    
    # Try to find project root (non-fatal)
    local project_root
    project_root=$(find_project_root 2>/dev/null) || true
    
    # Load project and ancestor configs if in a project
    if [[ -n "$project_root" ]]; then
        echo "Using project context from: $(display_absolute_path "$project_root")"
        
        # Load ancestor configs
        load_ancestor_configs
        
        # Load project config
        load_project_config "$project_root/.workflow/config"
    else
        echo "Running in standalone mode (no project context)"
    fi
    
    # =============================================================================
    # System Prompt Building
    # =============================================================================
    
    # Build system prompt from current configuration
    if ! build_system_prompt; then
        echo "Error: Failed to build system prompt" >&2
        return 1
    fi
    
    # =============================================================================
    # Context Aggregation
    # =============================================================================
    
    # Set CLI-provided paths for aggregation (must match execute.sh variable names)
    # These can be files or directories; execute.sh handles expansion
    CLI_INPUT_PATHS=("${cli_input_paths[@]}")
    CLI_CONTEXT_PATHS=("${cli_context_paths[@]}")
    
    # Create temporary cache directory for image processing
    local task_cache_dir
    task_cache_dir=$(mktemp -d)
    trap "rm -rf $task_cache_dir" EXIT

    # Reset global content block arrays for this task
    SYSTEM_BLOCKS=()
    CONTEXT_BLOCKS=()
    DEPENDENCY_BLOCKS=()
    INPUT_BLOCKS=()
    IMAGE_BLOCKS=()
    DOCUMENT_INDEX_MAP=()

    # Aggregate context (no workflow dependencies in task mode)
    aggregate_context "task" "$project_root" "$task_cache_dir"
    
    # =============================================================================
    # Build Final Prompts
    # =============================================================================
    
    build_prompts "$project_root" "$task_content"
    
    # =============================================================================
    # Token Estimation (if requested)
    # =============================================================================
    
    if $count_tokens_only; then
        estimate_tokens
        return 0
    fi
    
    # =============================================================================
    # Dry-Run Mode - Save Prompts and Inspect
    # =============================================================================
    
    if $dry_run; then
        handle_dry_run_mode "task" "$task_source"
        return 0
    fi
    
    # =============================================================================
    # Output File Setup
    # =============================================================================
    
    local output_file
    if [[ -n "$output_file_path" ]]; then
        # User specified explicit output file
        output_file="$output_file_path"
        
        # Backup if file exists
        if [[ -f "$output_file" ]]; then
            echo "Backing up previous output file..."
            local output_bak="${output_file%.*}-$(date +"%Y%m%d%H%M%S").${output_file##*.}"
            mv -v "$output_file" "$output_bak"
            echo
        fi
    else
        # No output file - use temp file for API function
        output_file=$(mktemp)
        trap "rm -f $output_file" EXIT
    fi
    
    # =============================================================================
    # Execute API Request
    # =============================================================================

    # Set streaming mode
    STREAM_MODE=$stream_mode

    # Execute API request
    execute_api_request "task" "$output_file" "$output_file_path"
    local api_result=$?

    if [[ $api_result -ne 0 ]]; then
        echo "Error: API request failed" >&2
        return $api_result
    fi
    
    # =============================================================================
    # Post-Processing
    # =============================================================================
    
    # Handle citations output
    if [[ "$ENABLE_CITATIONS" == "true" && -n "$CITATIONS_FILE_PATH" && -f "$CITATIONS_FILE_PATH" && -s "$CITATIONS_FILE_PATH" ]]; then
        if [[ -z "$output_file_path" ]]; then
            # Stdout mode: append citations to stdout after separator
            echo
            echo "---"
            echo
            cat "$CITATIONS_FILE_PATH"
        else
            # Explicit output file: move citations alongside with proper naming
            local output_dir=$(dirname "$output_file")
            local output_base=$(basename "$output_file" ".${OUTPUT_FORMAT}")
            local citations_output="${output_dir}/${output_base}-citations.md"
            mv "$CITATIONS_FILE_PATH" "$citations_output"
            echo "Citations saved to: $(display_absolute_path "$citations_output")"
        fi
    fi
    
    # Only post-process if output file was explicitly specified
    if [[ -n "$output_file_path" && -f "$output_file" ]]; then
        echo
        echo "Response saved to: $(display_absolute_path "$output_file")"
        
        # Format-specific post-processing
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
        
        echo
        echo "Task completed successfully!"
    fi
    
    return 0
}
