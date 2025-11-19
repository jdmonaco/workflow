# =============================================================================
# Workflow Execution Functions
# =============================================================================
# Shared execution logic for run and task modes.
# Houses common functions for system prompt building, context aggregation,
# token estimation, dry-run handling, and API request execution.
# This file is sourced by workflow.sh and lib/task.sh.
# =============================================================================

# =============================================================================
# System Prompt Building
# =============================================================================

# Build system prompt from SYSTEM_PROMPTS configuration array
# Concatenates prompt files from WORKFLOW_PROMPT_PREFIX directory
#
# Args:
#   $1 - system_prompt_file: Path where composed prompt should be saved
# Requires:
#   WORKFLOW_PROMPT_PREFIX: Directory containing *.txt prompt files
#   SYSTEM_PROMPTS: Array of prompt names (without .txt extension)
# Returns:
#   0 on success, 1 on error
# Side effects:
#   Writes composed prompt to system_prompt_file
#   May use cached version if rebuild fails
build_system_prompt() {
    local system_prompt_file="$1"

    # Validate prompt directory configuration
    if [[ -z "$WORKFLOW_PROMPT_PREFIX" ]]; then
        echo "Error: WORKFLOW_PROMPT_PREFIX environment variable is not set" >&2
        echo "Set WORKFLOW_PROMPT_PREFIX to the directory containing your *.txt prompt files" >&2
        return 1
    fi

    if [[ ! -d "$WORKFLOW_PROMPT_PREFIX" ]]; then
        echo "Error: System prompt directory not found: $WORKFLOW_PROMPT_PREFIX" >&2
        return 1
    fi

    echo "Building system prompt from: ${SYSTEM_PROMPTS[*]}"

    # Ensure parent directory exists
    mkdir -p "$(dirname "$system_prompt_file")"

    # Build to temp file for atomic write (XML text for debugging)
    local temp_prompt
    temp_prompt=$(mktemp)
    local build_success=true

    # Also build JSON content for API
    local system_prompts_text=""

    # Write opening XML tag
    echo "<system-prompts>" >> "$temp_prompt"
    echo "" >> "$temp_prompt"

    # Concatenate all specified prompts (no extra indentation)
    for prompt_name in "${SYSTEM_PROMPTS[@]}"; do
        local prompt_file="$WORKFLOW_PROMPT_PREFIX/${prompt_name}.txt"
        if [[ ! -f "$prompt_file" ]]; then
            echo "Error: System prompt file not found: $prompt_file" >&2
            build_success=false
            break
        fi

        # Add to XML file
        cat "$prompt_file" >> "$temp_prompt"
        echo "" >> "$temp_prompt"

        # Also accumulate for JSON block
        system_prompts_text+=$(cat "$prompt_file")
        system_prompts_text+=$'\n\n'
    done

    # Write closing XML tag
    echo "</system-prompts>" >> "$temp_prompt"

    # Handle build result
    if [[ "$build_success" == true ]]; then
        mv "$temp_prompt" "$system_prompt_file"

        # Build JSON content block for system prompts with cache_control
        local system_prompts_block
        system_prompts_block=$(jq -n \
            --arg type "text" \
            --arg text "$system_prompts_text" \
            '{
                type: $type,
                text: $text,
                cache_control: {type: "ephemeral"}
            }')

        # Add to SYSTEM_BLOCKS array
        SYSTEM_BLOCKS+=("$system_prompts_block")

        echo "System prompt built successfully"
        return 0
    else
        rm -f "$temp_prompt"
        # Fall back to cached version if available
        if [[ -f "$system_prompt_file" ]]; then
            echo "Warning: Using cached system prompt (rebuild failed)" >&2
            return 0
        else
            echo "Error: Cannot build system prompt and no cached version available" >&2
            return 1
        fi
    fi
}

# Build project description content block (with cache_control)
# Args:
#   $1 - project_root: Project root directory
# Returns:
#   0 if project description exists and block was created, 1 otherwise
# Side effects:
#   Appends block to SYSTEM_BLOCKS array if successful
build_project_description_block() {
    local project_root="$1"

    if [[ -z "$project_root" ]]; then
        return 1
    fi

    # Try to aggregate nested project descriptions
    if aggregate_nested_project_descriptions "$project_root"; then
        local project_desc_cache="$project_root/.workflow/prompts/project.txt"
        local project_desc
        project_desc=$(<"$project_desc_cache")

        # Build JSON content block with cache_control
        local project_desc_block
        project_desc_block=$(jq -n \
            --arg type "text" \
            --arg text "$project_desc" \
            '{
                type: $type,
                text: $text,
                cache_control: {type: "ephemeral"}
            }')

        # Add to SYSTEM_BLOCKS array
        SYSTEM_BLOCKS+=("$project_desc_block")
        return 0
    else
        return 1
    fi
}

# Build current date content block (without cache_control - intentionally volatile)
# No args required
# Side effects:
#   Appends block to SYSTEM_BLOCKS array
build_current_date_block() {
    # Use date-only format (not datetime) to prevent minute-by-minute cache invalidation
    local current_date
    current_date=$(date -u +"%Y-%m-%d")

    # Build JSON content block (no cache_control)
    local date_block
    date_block=$(jq -n \
        --arg type "text" \
        --arg text "Today's date: $current_date" \
        '{
            type: $type,
            text: $text
        }')

    # Add to SYSTEM_BLOCKS array
    SYSTEM_BLOCKS+=("$date_block")
}

# =============================================================================
# Token Estimation
# =============================================================================

# Estimate token count for system, task, input documents, and context prompts
# Only estimates if COUNT_TOKENS flag is set
# Exits if COUNT_TOKENS without DRY_RUN (standalone estimation)
#
# Args:
#   $1 - system_prompt_file: Path to system prompt file
#   $2 - task_source: Path to task file OR string content
#   $3 - input_prompt_file: Path to input documents file
#   $4 - context_prompt_file: Path to context file
# Requires:
#   COUNT_TOKENS: Boolean flag
#   DRY_RUN: Boolean flag
# Returns:
#   0 normally, or exits if COUNT_TOKENS && !DRY_RUN
estimate_tokens() {
    local system_file="$1"
    local task_source="$2"
    local input_file="$3"
    local context_file="$4"

    # Skip if not requested
    [[ "$COUNT_TOKENS" != true ]] && return 0

    # System tokens
    local syswc systc
    syswc=$(wc -w < "$system_file")
    systc=$((syswc * 13 / 10 + 4096))
    echo "Estimated system tokens: $systc"

    # Task tokens (handle file or string)
    local taskwc tasktc
    if [[ -f "$task_source" ]]; then
        taskwc=$(wc -w < "$task_source")
    else
        taskwc=$(echo "$task_source" | wc -w)
    fi
    tasktc=$((taskwc * 13 / 10 + 4096))
    echo "Estimated task tokens: $tasktc"

    # Input documents tokens
    local inputtc
    if [[ -s "$input_file" ]]; then
        local inputwc
        inputwc=$(wc -w < "$input_file")
        inputtc=$((inputwc * 13 / 10 + 4096))
        echo "Estimated input documents tokens: $inputtc"
    else
        inputtc=0
    fi

    # Context tokens
    local contexttc
    if [[ -s "$context_file" ]]; then
        local contextwc
        contextwc=$(wc -w < "$context_file")
        contexttc=$((contextwc * 13 / 10 + 4096))
        echo "Estimated context tokens: $contexttc"
    else
        contexttc=0
    fi

    # Total (heuristic)
    local total_tokens=$((systc + tasktc + inputtc + contexttc))
    echo "Estimated total input tokens (heuristic): $total_tokens"
    echo ""

    # Call Anthropic token counting API for exact count
    # Validate API key first
    if ! anthropic_validate "$ANTHROPIC_API_KEY" 2>/dev/null; then
        echo "Note: ANTHROPIC_API_KEY not set, skipping API token count"
        echo ""
    else
        echo "Calling Anthropic count_tokens API for exact count..."

        # Assemble content blocks (same logic as execute_api_request)
        local system_blocks_json
        if [[ ${#SYSTEM_BLOCKS[@]} -eq 0 ]]; then
            echo "Error: No system blocks available for token counting" >&2
            echo ""
        else
            system_blocks_json=$(printf '%s\n' "${SYSTEM_BLOCKS[@]}" | jq -s '.')

            local -a all_user_blocks=()
            for block in "${CONTEXT_BLOCKS[@]}"; do
                all_user_blocks+=("$block")
            done
            for block in "${DEPENDENCY_BLOCKS[@]}"; do
                all_user_blocks+=("$block")
            done
            for block in "${INPUT_BLOCKS[@]}"; do
                all_user_blocks+=("$block")
            done
            all_user_blocks+=("$TASK_BLOCK")

            local user_blocks_json
            user_blocks_json=$(printf '%s\n' "${all_user_blocks[@]}" | jq -s '.')

            # Pass JSON via temp files to avoid parameter parsing issues
            local temp_system=$(mktemp)
            local temp_user=$(mktemp)
            echo "$system_blocks_json" > "$temp_system"
            echo "$user_blocks_json" > "$temp_user"

            local api_result
            api_result=$(anthropic_count_tokens \
                api_key="$ANTHROPIC_API_KEY" \
                model="$MODEL" \
                system_blocks_file="$temp_system" \
                user_blocks_file="$temp_user" 2>&1)
            local api_status=$?

            # Cleanup temp files
            rm -f "$temp_system" "$temp_user"

            if [[ $api_status -eq 0 ]]; then
                local exact_tokens
                exact_tokens=$(echo "$api_result" | jq -r '.input_tokens')
                echo "Exact total input tokens (from API): $exact_tokens"

                # Show difference
                local diff=$((exact_tokens - total_tokens))
                if [[ $diff -gt 0 ]]; then
                    echo "  (API count is $diff tokens higher than heuristic)"
                elif [[ $diff -lt 0 ]]; then
                    echo "  (API count is ${diff#-} tokens lower than heuristic)"
                else
                    echo "  (Heuristic matched API count exactly)"
                fi
            else
                echo "Warning: Token counting API failed"
                echo "$api_result"
            fi
            echo ""
        fi
    fi

    # Exit if only counting tokens (not combined with dry-run)
    if [[ "$DRY_RUN" == false ]]; then
        exit 0
    fi

    return 0
}

# =============================================================================
# Dry-Run Mode Handling
# =============================================================================

# Handle dry-run mode: save prompts to files and open in editor
# Only activates if DRY_RUN flag is set
#
# Args:
#   $1 - mode: "run" or "task"
#   $2 - workflow_dir: Workflow directory (for run mode) or empty (for task mode)
# Requires:
#   DRY_RUN: Boolean flag
#   COUNT_TOKENS: Boolean flag
#   SYSTEM_PROMPT: Final system prompt string
#   USER_PROMPT: Final user prompt string
# Returns:
#   Exits script (does not return)
handle_dry_run_mode() {
    local mode="$1"
    local workflow_dir="$2"

    # Skip if not in dry-run mode
    [[ "$DRY_RUN" != true ]] && return 0

    local dry_run_system
    local dry_run_user
    local dry_run_json_request
    local dry_run_json_blocks

    if [[ "$mode" == "run" ]]; then
        # Run mode: Save to workflow directory
        dry_run_system="$workflow_dir/dry-run-system.txt"
        dry_run_user="$workflow_dir/dry-run-user.txt"
        dry_run_json_request="$workflow_dir/dry-run-request.json"
        dry_run_json_blocks="$workflow_dir/dry-run-blocks.json"
    else
        # Task mode: Save to temp files with cleanup trap
        dry_run_system=$(mktemp -t dry-run-system.XXXXXX)
        dry_run_user=$(mktemp -t dry-run-user.XXXXXX)
        dry_run_json_request=$(mktemp -t dry-run-request.XXXXXX.json)
        dry_run_json_blocks=$(mktemp -t dry-run-blocks.XXXXXX.json)
        trap "rm -f '$dry_run_system' '$dry_run_user' '$dry_run_json_request' '$dry_run_json_blocks'" EXIT
    fi

    # Save XML prompts (for readability)
    echo "$SYSTEM_PROMPT" > "$dry_run_system"
    echo "$USER_PROMPT" > "$dry_run_user"

    # Assemble content blocks (same logic as execute_api_request)
    local system_blocks_json
    system_blocks_json=$(printf '%s\n' "${SYSTEM_BLOCKS[@]}" | jq -s '.')

    local -a all_user_blocks=()
    for block in "${CONTEXT_BLOCKS[@]}"; do
        all_user_blocks+=("$block")
    done
    for block in "${DEPENDENCY_BLOCKS[@]}"; do
        all_user_blocks+=("$block")
    done
    for block in "${INPUT_BLOCKS[@]}"; do
        all_user_blocks+=("$block")
    done
    all_user_blocks+=("$TASK_BLOCK")

    local user_blocks_json
    user_blocks_json=$(printf '%s\n' "${all_user_blocks[@]}" | jq -s '.')

    # Build complete API request JSON payload
    local request_payload
    request_payload=$(jq -n \
        --arg model "$MODEL" \
        --argjson max_tokens "$MAX_TOKENS" \
        --argjson temperature "$TEMPERATURE" \
        --argjson system "$system_blocks_json" \
        --argjson user_content "$user_blocks_json" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            temperature: $temperature,
            system: $system,
            messages: [
                {
                    role: "user",
                    content: $user_content
                }
            ]
        }')

    # Save JSON request payload
    echo "$request_payload" | jq '.' > "$dry_run_json_request"

    # Save content blocks for inspection
    jq -n \
        --argjson system "$system_blocks_json" \
        --argjson user "$user_blocks_json" \
        '{
            system_blocks: $system,
            user_blocks: $user,
            total_blocks: ($system | length) + ($user | length)
        }' > "$dry_run_json_blocks"

    echo "Dry-run mode: Prompts and JSON payload saved for inspection"
    echo "  System prompt (XML):  $dry_run_system"
    echo "  User prompt (XML):    $dry_run_user"
    echo "  API request (JSON):   $dry_run_json_request"
    echo "  Content blocks (JSON): $dry_run_json_blocks"
    echo ""

    # If count-tokens was also requested, prompt before opening
    if [[ "$COUNT_TOKENS" == true ]]; then
        read -p "Press Enter to inspect in editor (or Ctrl+C to cancel): " -r
        echo ""
    fi

    # Open in editor
    edit_files "$dry_run_system" "$dry_run_user" "$dry_run_json_request" "$dry_run_json_blocks"
    exit 0
}

# =============================================================================
# Prompt Building
# =============================================================================

# Build final system and user prompts for API request
# Creates hierarchical XML structure following Anthropic best practices
#
# SYSTEM_PROMPT structure:
#   <system>
#     <system-prompts>...</system-prompts>
#     <project-description>...</project-description>
#     <current-datetime>...</current-datetime>
#   </system>
#
# USER_PROMPT structure:
#   <user>
#     <documents>...</documents>
#     <context>...</context>
#     <task>...</task>
#   </user>
#
# Args:
#   $1 - system_prompt_file: Path to system prompt file (already contains <system-prompts> wrapper)
#   $2 - project_root: Project root directory (or empty if no project)
#   $3 - input_prompt_file: Path to input documents file
#   $4 - context_prompt_file: Path to context file
#   $5 - task_source: Path to task file OR task string content
# Sets global variables:
#   SYSTEM_PROMPT: Final system prompt with XML structure
#   USER_PROMPT: Final user prompt with XML structure
build_prompts() {
    local system_file="$1"
    local project_root="$2"
    local input_file="$3"
    local context_file="$4"
    local task_source="$5"

    # =============================================================================
    # Build System Message Blocks (for JSON API)
    # =============================================================================

    # Note: System prompts block already added to SYSTEM_BLOCKS by build_system_prompt()

    # Add project description block (if exists)
    if [[ -n "$project_root" ]]; then
        build_project_description_block "$project_root" || true
    fi

    # Add current date block (always)
    build_current_date_block

    # =============================================================================
    # Build System Message XML (for debugging and token estimation)
    # =============================================================================

    # Read system prompts (already wrapped in <system-prompts> tags by build_system_prompt)
    local system_prompts_content
    system_prompts_content=$(<"$system_file")

    # Start building complete system prompt
    SYSTEM_PROMPT="<system>"$'\n'
    SYSTEM_PROMPT+="${system_prompts_content}"$'\n'

    # Add aggregated project descriptions from nested hierarchy
    if [[ -n "$project_root" ]] && aggregate_nested_project_descriptions "$project_root"; then
        local project_desc_cache="$project_root/.workflow/prompts/project.txt"
        local project_desc
        project_desc=$(<"$project_desc_cache")
        SYSTEM_PROMPT+=$'\n'"<project-description>"$'\n'"${project_desc}"$'\n'"</project-description>"$'\n'
    fi

    # Add current date (changed from datetime to prevent minute-by-minute cache invalidation)
    local current_date
    current_date=$(date -u +"%Y-%m-%d")
    SYSTEM_PROMPT+=$'\n'"<current-date>${current_date}</current-date>"$'\n'

    # Close system prompt
    SYSTEM_PROMPT+=$'\n'"</system>"

    # Build user prompt with XML structure
    local task_content
    if [[ -f "$task_source" ]]; then
        # Task is a file
        task_content=$(<"$task_source")
    else
        # Task is inline string
        task_content="$task_source"
    fi

    # Start building user prompt
    USER_PROMPT="<user>"$'\n'

    # Add documents section if input exists
    if [[ -s "$input_file" ]]; then
        local input_content
        input_content=$(<"$input_file")
        USER_PROMPT+=$'\n'"<documents>"$'\n'
        USER_PROMPT+="${input_content}"$'\n'
        USER_PROMPT+="</documents>"$'\n'
    fi

    # Add context section if context exists
    if [[ -s "$context_file" ]]; then
        local context_content
        context_content=$(<"$context_file")
        USER_PROMPT+=$'\n'"<context>"$'\n'
        USER_PROMPT+="${context_content}"$'\n'
        USER_PROMPT+="</context>"$'\n'
    fi

    # Add task section
    USER_PROMPT+=$'\n'"<task>"$'\n'
    USER_PROMPT+="${task_content}"$'\n'
    USER_PROMPT+="</task>"$'\n'

    # Close user prompt
    USER_PROMPT+=$'\n'"</user>"

    # =============================================================================
    # Build User Message Blocks (for JSON API)
    # =============================================================================

    # Assemble user blocks in order: context → dependencies → input → task
    # (CONTEXT_BLOCKS, DEPENDENCY_BLOCKS, INPUT_BLOCKS already populated by aggregate_context)

    # Build task block (most volatile, no cache_control)
    TASK_BLOCK=$(jq -n \
        --arg type "text" \
        --arg text "$task_content" \
        '{
            type: $type,
            text: $text
        }')

    # Note: Complete user message will be assembled in API request from:
    # CONTEXT_BLOCKS + DEPENDENCY_BLOCKS + INPUT_BLOCKS + TASK_BLOCK
}

# =============================================================================
# Context Aggregation
# =============================================================================

# Aggregate input and context files from various sources based on mode
# Builds both XML text files (for debugging) and JSON content blocks (for API)
# Aggregation order (stable → volatile): context → dependencies → input
# Within each category: FILES → PATTERN → CLI
# Run mode: config patterns/files + CLI patterns/files
# Task mode: CLI patterns/files only
#
# Args:
#   $1 - mode: "run" or "task"
#   $2 - input_file: Path where aggregated input documents XML should be written
#   $3 - context_file: Path where aggregated context XML should be written
#   $4 - project_root: Project root (for run mode, empty for task standalone)
# Requires (run mode):
#   INPUT_PATTERN: Config input pattern
#   INPUT_FILES: Array of config input files
#   DEPENDS_ON: Array of workflow dependencies
#   CONTEXT_PATTERN: Config context pattern
#   CONTEXT_FILES: Array of config context files
# Requires (both modes):
#   CLI_INPUT_PATTERN: CLI input pattern
#   CLI_INPUT_FILES: Array of CLI input files
#   CLI_CONTEXT_PATTERN: CLI context pattern
#   CLI_CONTEXT_FILES: Array of CLI context files
# Side effects:
#   Writes aggregated XML to input_file and context_file
#   Populates CONTEXT_BLOCKS, DEPENDENCY_BLOCKS, and INPUT_BLOCKS arrays
aggregate_context() {
    local mode="$1"
    local input_file="$2"
    local context_file="$3"
    local project_root="$4"

    echo "Building input documents and context..."

    # Start with empty XML files
    > "$input_file"
    > "$context_file"

    # =============================================================================
    # CONTEXT FILES AGGREGATION (most stable)
    # Order: CONTEXT_FILES → CONTEXT_PATTERN → CLI_CONTEXT_FILES → CLI_CONTEXT_PATTERN
    # =============================================================================

    # Run mode: Add explicit files from config CONTEXT_FILES (project-relative, most stable)
    if [[ "$mode" == "run" && ${#CONTEXT_FILES[@]} -gt 0 ]]; then
        echo "  Adding explicit context files from config..."
        for file in "${CONTEXT_FILES[@]}"; do
            local resolved_file="$project_root/$file"
            if [[ ! -f "$resolved_file" ]]; then
                echo "Error: Context file not found: $file (resolved: $resolved_file)"
                exit 1
            fi

            # Add to XML file for debugging
            contextcat "$resolved_file" >> "$context_file"

            # Build JSON content block
            local block
            block=$(build_text_content_block "$resolved_file" "context")
            CONTEXT_BLOCKS+=("$block")
        done
    fi

    # Run mode: Add files from config CONTEXT_PATTERN (project-relative)
    if [[ "$mode" == "run" && -n "$CONTEXT_PATTERN" ]]; then
        echo "  Adding context from config pattern: $CONTEXT_PATTERN"
        local pattern_files
        pattern_files=($(cd "$project_root" && eval "echo $CONTEXT_PATTERN"))

        for file in "${pattern_files[@]}"; do
            local abs_file="$project_root/$file"
            if [[ -f "$abs_file" ]]; then
                # Add to XML file
                contextcat "$abs_file" >> "$context_file"

                # Build JSON content block
                local block
                block=$(build_text_content_block "$abs_file" "context")
                CONTEXT_BLOCKS+=("$block")
            fi
        done
    fi

    # Both modes: Add explicit files from CLI --context-file (PWD-relative)
    if [[ ${#CLI_CONTEXT_FILES[@]} -gt 0 ]]; then
        echo "  Adding explicit context files from CLI..."
        for file in "${CLI_CONTEXT_FILES[@]}"; do
            if [[ ! -f "$file" ]]; then
                echo "Error: Context file not found: $file"
                exit 1
            fi

            # Add to XML file
            contextcat "$file" >> "$context_file"

            # Build JSON content block
            local block
            block=$(build_text_content_block "$file" "context")
            CONTEXT_BLOCKS+=("$block")
        done
    fi

    # Both modes: Add files from CLI --context-pattern (PWD-relative, most volatile)
    if [[ -n "$CLI_CONTEXT_PATTERN" ]]; then
        echo "  Adding context from CLI pattern: $CLI_CONTEXT_PATTERN"
        local pattern_files
        pattern_files=($(eval "echo $CLI_CONTEXT_PATTERN"))

        for file in "${pattern_files[@]}"; do
            if [[ -f "$file" ]]; then
                # Add to XML file
                contextcat "$file" >> "$context_file"

                # Build JSON content block
                local block
                block=$(build_text_content_block "$file" "context")
                CONTEXT_BLOCKS+=("$block")
            fi
        done
    fi

    # Add cache_control to last context block if any exist
    if [[ ${#CONTEXT_BLOCKS[@]} -gt 0 ]]; then
        local last_idx=$((${#CONTEXT_BLOCKS[@]} - 1))
        CONTEXT_BLOCKS[$last_idx]=$(echo "${CONTEXT_BLOCKS[$last_idx]}" | jq '. + {cache_control: {type: "ephemeral"}}')
    fi

    # =============================================================================
    # WORKFLOW DEPENDENCIES (medium stability)
    # =============================================================================

    # Run mode: Add workflow dependencies
    if [[ "$mode" == "run" && ${#DEPENDS_ON[@]} -gt 0 ]]; then
        echo "  Adding context from dependencies..."
        for dep in "${DEPENDS_ON[@]}"; do
            # Find dependency output with any extension
            local dep_file
            dep_file=$(ls "$project_root/.workflow/output/${dep}".* 2>/dev/null | head -1)
            if [[ -z "$dep_file" ]]; then
                echo "Error: Dependency output not found for workflow: $dep"
                echo "Expected file matching: $project_root/.workflow/output/${dep}.*"
                echo "Ensure workflow '$dep' has been executed successfully"
                exit 1
            fi
            echo "    - $dep_file"

            # Add to XML file
            contextcat "$dep_file" >> "$context_file"

            # Build JSON content block
            local block
            block=$(build_text_content_block "$dep_file" "dependency" "workflow" "$dep")
            DEPENDENCY_BLOCKS+=("$block")
        done

        # Add cache_control to last dependency block if any exist
        if [[ ${#DEPENDENCY_BLOCKS[@]} -gt 0 ]]; then
            local last_idx=$((${#DEPENDENCY_BLOCKS[@]} - 1))
            DEPENDENCY_BLOCKS[$last_idx]=$(echo "${DEPENDENCY_BLOCKS[$last_idx]}" | jq '. + {cache_control: {type: "ephemeral"}}')
        fi
    fi

    # =============================================================================
    # INPUT DOCUMENTS AGGREGATION (most volatile)
    # Order: INPUT_FILES → INPUT_PATTERN → CLI_INPUT_FILES → CLI_INPUT_PATTERN
    # =============================================================================

    # Run mode: Add explicit files from config INPUT_FILES (project-relative, most stable)
    if [[ "$mode" == "run" && ${#INPUT_FILES[@]} -gt 0 ]]; then
        echo "  Adding explicit input files from config..."
        for file in "${INPUT_FILES[@]}"; do
            local resolved_file="$project_root/$file"
            if [[ ! -f "$resolved_file" ]]; then
                echo "Error: Input file not found: $file (resolved: $resolved_file)"
                exit 1
            fi

            # Add to XML file for debugging
            documentcat "$resolved_file" >> "$input_file"

            # Build JSON content block
            local block
            block=$(build_text_content_block "$resolved_file" "input")
            INPUT_BLOCKS+=("$block")
        done
    fi

    # Run mode: Add files from config INPUT_PATTERN (project-relative)
    if [[ "$mode" == "run" && -n "$INPUT_PATTERN" ]]; then
        echo "  Adding input documents from config pattern: $INPUT_PATTERN"
        local pattern_files
        pattern_files=($(cd "$project_root" && eval "echo $INPUT_PATTERN"))

        for file in "${pattern_files[@]}"; do
            local abs_file="$project_root/$file"
            if [[ -f "$abs_file" ]]; then
                # Add to XML file
                documentcat "$abs_file" >> "$input_file"

                # Build JSON content block
                local block
                block=$(build_text_content_block "$abs_file" "input")
                INPUT_BLOCKS+=("$block")
            fi
        done
    fi

    # Both modes: Add explicit files from CLI --input-file (PWD-relative)
    if [[ ${#CLI_INPUT_FILES[@]} -gt 0 ]]; then
        echo "  Adding explicit input files from CLI..."
        for file in "${CLI_INPUT_FILES[@]}"; do
            if [[ ! -f "$file" ]]; then
                echo "Error: Input file not found: $file"
                exit 1
            fi

            # Add to XML file
            documentcat "$file" >> "$input_file"

            # Build JSON content block
            local block
            block=$(build_text_content_block "$file" "input")
            INPUT_BLOCKS+=("$block")
        done
    fi

    # Both modes: Add files from CLI --input-pattern (PWD-relative, most volatile)
    if [[ -n "$CLI_INPUT_PATTERN" ]]; then
        echo "  Adding input documents from CLI pattern: $CLI_INPUT_PATTERN"
        local pattern_files
        pattern_files=($(eval "echo $CLI_INPUT_PATTERN"))

        for file in "${pattern_files[@]}"; do
            if [[ -f "$file" ]]; then
                # Add to XML file
                documentcat "$file" >> "$input_file"

                # Build JSON content block
                local block
                block=$(build_text_content_block "$file" "input")
                INPUT_BLOCKS+=("$block")
            fi
        done
    fi

    # Add cache_control to last input block if any exist
    if [[ ${#INPUT_BLOCKS[@]} -gt 0 ]]; then
        local last_idx=$((${#INPUT_BLOCKS[@]} - 1))
        INPUT_BLOCKS[$last_idx]=$(echo "${INPUT_BLOCKS[$last_idx]}" | jq '. + {cache_control: {type: "ephemeral"}}')
    fi

    # =============================================================================
    # Summary
    # =============================================================================

    # Check if any input or context was provided
    local has_input=false
    local has_context=false
    [[ -s "$input_file" ]] && has_input=true
    [[ -s "$context_file" ]] && has_context=true

    if [[ "$has_input" == false && "$has_context" == false ]]; then
        echo "Warning: No input documents or context provided. Task will run without supporting materials."
        if [[ "$mode" == "run" ]]; then
            echo "  Use --input-file, --input-pattern, --context-file, --context-pattern, or --depends-on"
        else
            echo "  Use --input-file, --input-pattern, --context-file, or --context-pattern"
        fi
    fi
}

# =============================================================================
# API Request Execution
# =============================================================================

# Execute API request with mode-specific output handling
# Validates API key, escapes prompts, and executes streaming or single-shot request
#
# Args:
#   $1 - mode: "run" or "task"
#   $2 - output_file: Path to output file
#   $3 - output_file_path: Explicit output file path (task mode, optional)
# Requires:
#   SYSTEM_PROMPT: Final system prompt
#   USER_PROMPT: Final user prompt
#   ANTHROPIC_API_KEY: API key
#   MODEL: Model name
#   MAX_TOKENS: Token limit
#   TEMPERATURE: Temperature setting
#   STREAM_MODE: Boolean flag
# Side effects:
#   Backs up existing output file (run mode only)
#   Executes API request
#   Displays to stdout (task mode, non-stream, no explicit file)
execute_api_request() {
    local mode="$1"
    local output_file="$2"
    local output_file_path="${3:-}"

    # =============================================================================
    # Assemble Content Blocks for JSON API
    # =============================================================================

    # Assemble system content blocks array (already populated by build_system_prompt and build_prompts)
    # SYSTEM_BLOCKS contains: system-prompts block, project-description block (if exists), current-date block
    local system_blocks_json
    system_blocks_json=$(printf '%s\n' "${SYSTEM_BLOCKS[@]}" | jq -s '.')

    # Assemble user content blocks array in order: context → dependencies → input → task
    local user_blocks_json
    local -a all_user_blocks=()

    # Add context blocks (if any)
    for block in "${CONTEXT_BLOCKS[@]}"; do
        all_user_blocks+=("$block")
    done

    # Add dependency blocks (if any)
    for block in "${DEPENDENCY_BLOCKS[@]}"; do
        all_user_blocks+=("$block")
    done

    # Add input blocks (if any)
    for block in "${INPUT_BLOCKS[@]}"; do
        all_user_blocks+=("$block")
    done

    # Add task block (always present)
    all_user_blocks+=("$TASK_BLOCK")

    # Convert to JSON array
    user_blocks_json=$(printf '%s\n' "${all_user_blocks[@]}" | jq -s '.')

    # =============================================================================
    # Backward Compatibility: Also escape string prompts for debugging
    # =============================================================================

    SYSTEM_JSON=$(escape_json "$SYSTEM_PROMPT")
    USER_JSON=$(escape_json "$USER_PROMPT")

    # Run mode: Backup any previous output files before API call
    if [[ "$mode" == "run" && -f "$output_file" ]]; then
        echo "Backing up previous output file..."
        local output_bak="${output_file%.*}-$(date +"%Y%m%d%H%M%S").${output_file##*.}"
        mv -v "$output_file" "$output_bak"
        echo ""
    fi

    # Validate API key
    anthropic_validate "$ANTHROPIC_API_KEY" || exit 1

    # Pass JSON via temp files to avoid parameter parsing issues
    local temp_system=$(mktemp)
    local temp_user=$(mktemp)
    echo "$system_blocks_json" > "$temp_system"
    echo "$user_blocks_json" > "$temp_user"

    # Execute API request (stream or single mode)
    if [[ "$STREAM_MODE" == true ]]; then
        anthropic_execute_stream \
            api_key="$ANTHROPIC_API_KEY" \
            model="$MODEL" \
            max_tokens="$MAX_TOKENS" \
            temperature="$TEMPERATURE" \
            system_blocks_file="$temp_system" \
            user_blocks_file="$temp_user" \
            output_file="$output_file" || exit 1
    else
        anthropic_execute_single \
            api_key="$ANTHROPIC_API_KEY" \
            model="$MODEL" \
            max_tokens="$MAX_TOKENS" \
            temperature="$TEMPERATURE" \
            system_blocks_file="$temp_system" \
            user_blocks_file="$temp_user" \
            output_file="$output_file" || exit 1

        # Task mode: Display output to stdout if no explicit output file
        if [[ "$mode" == "task" && -z "$output_file_path" ]]; then
            cat "$output_file"
        fi
    fi

    # Cleanup temp files
    rm -f "$temp_system" "$temp_user"
}
