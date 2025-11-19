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

    # Build to temp file for atomic write
    local temp_prompt
    temp_prompt=$(mktemp)
    local build_success=true

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
        cat "$prompt_file" >> "$temp_prompt"
        echo "" >> "$temp_prompt"
    done

    # Write closing XML tag
    echo "</system-prompts>" >> "$temp_prompt"

    # Handle build result
    if [[ "$build_success" == true ]]; then
        mv "$temp_prompt" "$system_prompt_file"
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

    # Total
    local total_tokens=$((systc + tasktc + inputtc + contexttc))
    echo "Estimated total input tokens: $total_tokens"
    echo ""

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

    if [[ "$mode" == "run" ]]; then
        # Run mode: Save to workflow directory
        dry_run_system="$workflow_dir/dry-run-system.txt"
        dry_run_user="$workflow_dir/dry-run-user.txt"
    else
        # Task mode: Save to temp files with cleanup trap
        dry_run_system=$(mktemp -t dry-run-system.XXXXXX)
        dry_run_user=$(mktemp -t dry-run-user.XXXXXX)
        trap "rm -f '$dry_run_system' '$dry_run_user'" EXIT
    fi

    # Save prompts
    echo "$SYSTEM_PROMPT" > "$dry_run_system"
    echo "$USER_PROMPT" > "$dry_run_user"

    echo "Dry-run mode: Prompts saved for inspection"
    echo "  System prompt: $dry_run_system"
    echo "  User prompt:   $dry_run_user"
    echo ""

    # If count-tokens was also requested, prompt before opening
    if [[ "$COUNT_TOKENS" == true ]]; then
        read -p "Press Enter to inspect prompts in editor (or Ctrl+C to cancel): " -r
        echo ""
    fi

    # Open in editor
    edit_files "$dry_run_system" "$dry_run_user"
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
        SYSTEM_PROMPT+=$'\n'"<project-description>"$'\n'"${project_desc}</project-description>"$'\n'
    fi

    # Add current datetime
    local current_datetime
    current_datetime=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    SYSTEM_PROMPT+=$'\n'"<current-datetime>${current_datetime}</current-datetime>"$'\n'

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
}

# =============================================================================
# Context Aggregation
# =============================================================================

# Aggregate input and context files from various sources based on mode
# Separates primary input documents from supporting context materials
# Run mode: config patterns/files + CLI patterns/files
# Task mode: CLI patterns/files only
#
# Args:
#   $1 - mode: "run" or "task"
#   $2 - input_file: Path where aggregated input documents should be written
#   $3 - context_file: Path where aggregated context should be written
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
#   Writes aggregated input documents to input_file using documentcat()
#   Writes aggregated context to context_file using contextcat()
aggregate_context() {
    local mode="$1"
    local input_file="$2"
    local context_file="$3"
    local project_root="$4"

    echo "Building input documents and context..."

    # Start with empty files
    > "$input_file"
    > "$context_file"

    # =============================================================================
    # INPUT DOCUMENTS AGGREGATION (using documentcat)
    # =============================================================================

    # Run mode: Add files from config INPUT_PATTERN (project-relative)
    if [[ "$mode" == "run" && -n "$INPUT_PATTERN" ]]; then
        echo "  Adding input documents from config pattern: $INPUT_PATTERN"
        (cd "$project_root" && eval "documentcat $INPUT_PATTERN") >> "$input_file"
    fi

    # Both modes: Add files from CLI --input-pattern (PWD-relative)
    if [[ -n "$CLI_INPUT_PATTERN" ]]; then
        echo "  Adding input documents from CLI pattern: $CLI_INPUT_PATTERN"
        eval "documentcat $CLI_INPUT_PATTERN" >> "$input_file"
    fi

    # Run mode: Add explicit files from config INPUT_FILES (project-relative)
    if [[ "$mode" == "run" && ${#INPUT_FILES[@]} -gt 0 ]]; then
        echo "  Adding explicit input files from config..."
        local resolved_files=()
        for file in "${INPUT_FILES[@]}"; do
            local resolved_file="$project_root/$file"
            if [[ ! -f "$resolved_file" ]]; then
                echo "Error: Input file not found: $file (resolved: $resolved_file)"
                exit 1
            fi
            resolved_files+=("$resolved_file")
        done
        documentcat "${resolved_files[@]}" >> "$input_file"
    fi

    # Both modes: Add explicit files from CLI --input-file (PWD-relative)
    if [[ ${#CLI_INPUT_FILES[@]} -gt 0 ]]; then
        echo "  Adding explicit input files from CLI..."
        local validated_files=()
        for file in "${CLI_INPUT_FILES[@]}"; do
            if [[ ! -f "$file" ]]; then
                echo "Error: Input file not found: $file"
                exit 1
            fi
            validated_files+=("$file")
        done
        documentcat "${validated_files[@]}" >> "$input_file"
    fi

    # =============================================================================
    # CONTEXT AGGREGATION (using contextcat)
    # =============================================================================

    # Run mode: Add workflow dependencies
    if [[ "$mode" == "run" && ${#DEPENDS_ON[@]} -gt 0 ]]; then
        echo "  Adding context from dependencies..."
        local dep_files=()
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
            dep_files+=("$dep_file")
        done
        contextcat "${dep_files[@]}" >> "$context_file"
    fi

    # Run mode: Add files from config CONTEXT_PATTERN (project-relative)
    if [[ "$mode" == "run" && -n "$CONTEXT_PATTERN" ]]; then
        echo "  Adding context from config pattern: $CONTEXT_PATTERN"
        (cd "$project_root" && eval "contextcat $CONTEXT_PATTERN") >> "$context_file"
    fi

    # Both modes: Add files from CLI --context-pattern (PWD-relative)
    if [[ -n "$CLI_CONTEXT_PATTERN" ]]; then
        echo "  Adding context from CLI pattern: $CLI_CONTEXT_PATTERN"
        eval "contextcat $CLI_CONTEXT_PATTERN" >> "$context_file"
    fi

    # Run mode: Add explicit files from config CONTEXT_FILES (project-relative)
    if [[ "$mode" == "run" && ${#CONTEXT_FILES[@]} -gt 0 ]]; then
        echo "  Adding explicit context files from config..."
        local resolved_files=()
        for file in "${CONTEXT_FILES[@]}"; do
            local resolved_file="$project_root/$file"
            if [[ ! -f "$resolved_file" ]]; then
                echo "Error: Context file not found: $file (resolved: $resolved_file)"
                exit 1
            fi
            resolved_files+=("$resolved_file")
        done
        contextcat "${resolved_files[@]}" >> "$context_file"
    fi

    # Both modes: Add explicit files from CLI --context-file (PWD-relative)
    if [[ ${#CLI_CONTEXT_FILES[@]} -gt 0 ]]; then
        echo "  Adding explicit context files from CLI..."
        local validated_files=()
        for file in "${CLI_CONTEXT_FILES[@]}"; do
            if [[ ! -f "$file" ]]; then
                echo "Error: Context file not found: $file"
                exit 1
            fi
            validated_files+=("$file")
        done
        contextcat "${validated_files[@]}" >> "$context_file"
    fi

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

    # JSON-escape prompts
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

    # Execute API request (stream or single mode)
    if [[ "$STREAM_MODE" == true ]]; then
        anthropic_execute_stream \
            api_key="$ANTHROPIC_API_KEY" \
            model="$MODEL" \
            max_tokens="$MAX_TOKENS" \
            temperature="$TEMPERATURE" \
            system_prompt="$SYSTEM_JSON" \
            user_prompt="$USER_JSON" \
            output_file="$output_file" || exit 1
    else
        anthropic_execute_single \
            api_key="$ANTHROPIC_API_KEY" \
            model="$MODEL" \
            max_tokens="$MAX_TOKENS" \
            temperature="$TEMPERATURE" \
            system_prompt="$SYSTEM_JSON" \
            user_prompt="$USER_JSON" \
            output_file="$output_file" || exit 1

        # Task mode: Display output to stdout if no explicit output file
        if [[ "$mode" == "task" && -z "$output_file_path" ]]; then
            cat "$output_file"
        fi
    fi
}
