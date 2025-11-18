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

    # Concatenate all specified prompts
    for prompt_name in "${SYSTEM_PROMPTS[@]}"; do
        local prompt_file="$WORKFLOW_PROMPT_PREFIX/${prompt_name}.txt"
        if [[ ! -f "$prompt_file" ]]; then
            echo "Error: System prompt file not found: $prompt_file" >&2
            build_success=false
            break
        fi
        cat "$prompt_file" >> "$temp_prompt"
    done

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

# Estimate token count for system, task, and context prompts
# Only estimates if COUNT_TOKENS flag is set
# Exits if COUNT_TOKENS without DRY_RUN (standalone estimation)
#
# Args:
#   $1 - system_prompt_file: Path to system prompt file
#   $2 - task_source: Path to task file OR string content
#   $3 - context_prompt_file: Path to context file
# Requires:
#   COUNT_TOKENS: Boolean flag
#   DRY_RUN: Boolean flag
# Returns:
#   0 normally, or exits if COUNT_TOKENS && !DRY_RUN
estimate_tokens() {
    local system_file="$1"
    local task_source="$2"
    local context_file="$3"

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
    local total_tokens=$((systc + tasktc + contexttc))
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
# Combines system prompt with project descriptions
# Combines context with task for user prompt
#
# Args:
#   $1 - system_prompt_file: Path to system prompt file
#   $2 - project_root: Project root directory (or empty if no project)
#   $3 - context_prompt_file: Path to context file
#   $4 - task_source: Path to task file OR task string content
#   $5 - output_format: Output format (for format hint)
# Sets global variables:
#   SYSTEM_PROMPT: Final system prompt
#   USER_PROMPT: Final user prompt
build_prompts() {
    local system_file="$1"
    local project_root="$2"
    local context_file="$3"
    local task_source="$4"
    local output_format="$5"

    # Read system prompt
    SYSTEM_PROMPT=$(<"$system_file")

    # Append aggregated project descriptions from nested hierarchy
    if [[ -n "$project_root" ]] && aggregate_nested_project_descriptions "$project_root"; then
        local project_desc_cache="$project_root/.workflow/prompts/project.txt"
        local project_desc
        project_desc=$(<"$project_desc_cache")
        SYSTEM_PROMPT="${SYSTEM_PROMPT}"$'\n'"<project-description>"$'\n'"${project_desc}</project-description>"
    fi

    # Build user prompt: combine context with task
    local task_content
    if [[ -f "$task_source" ]]; then
        # Task is a file
        task_content=$(<"$task_source")
    else
        # Task is inline string
        task_content="$task_source"
    fi

    if [[ -s "$context_file" ]]; then
        # Run mode uses filecat for context, task mode uses plain cat
        if [[ -f "$task_source" ]]; then
            # Task is a file - use filecat for both
            USER_PROMPT="$(filecat "$context_file" "$task_source")"
        else
            # Task is inline - concatenate context + task
            USER_PROMPT="$(cat "$context_file")"$'\n'"$task_content"
        fi
    else
        USER_PROMPT="$task_content"
    fi

    # Add output format hint for non-markdown formats
    if [[ "$output_format" != "md" ]]; then
        USER_PROMPT="${USER_PROMPT}"$'\n'"<output-format>${output_format}</output-format>"
    fi
}

# =============================================================================
# Context Aggregation
# =============================================================================

# Aggregate context files from various sources based on mode
# Run mode: dependencies + config patterns/files + CLI patterns/files
# Task mode: CLI patterns/files only
#
# Args:
#   $1 - mode: "run" or "task"
#   $2 - context_file: Path where aggregated context should be written
#   $3 - project_root: Project root (for run mode, empty for task standalone)
# Requires (run mode):
#   DEPENDS_ON: Array of workflow dependencies
#   CONTEXT_PATTERN: Config context pattern
#   CONTEXT_FILES: Array of config context files
# Requires (both modes):
#   CLI_CONTEXT_PATTERN: CLI context pattern
#   CLI_CONTEXT_FILES: Array of CLI context files
# Side effects:
#   Writes aggregated context to context_file
aggregate_context() {
    local mode="$1"
    local context_file="$2"
    local project_root="$3"

    echo "Building context..."

    # Start with empty context
    > "$context_file"

    # Run mode: Add workflow dependencies
    if [[ "$mode" == "run" && ${#DEPENDS_ON[@]} -gt 0 ]]; then
        echo "  Adding dependencies..."
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
        filecat "${dep_files[@]}" >> "$context_file"
    fi

    # Run mode: Add files from config CONTEXT_PATTERN (project-relative)
    if [[ "$mode" == "run" && -n "$CONTEXT_PATTERN" ]]; then
        echo "  Adding files from config pattern: $CONTEXT_PATTERN"
        (cd "$project_root" && eval "filecat $CONTEXT_PATTERN") >> "$context_file"
    fi

    # Both modes: Add files from CLI --context-pattern (PWD-relative)
    if [[ -n "$CLI_CONTEXT_PATTERN" ]]; then
        echo "  Adding files from CLI pattern: $CLI_CONTEXT_PATTERN"
        eval "filecat $CLI_CONTEXT_PATTERN" >> "$context_file"
    fi

    # Run mode: Add explicit files from config CONTEXT_FILES (project-relative)
    if [[ "$mode" == "run" && ${#CONTEXT_FILES[@]} -gt 0 ]]; then
        echo "  Adding explicit files from config..."
        local resolved_files=()
        for file in "${CONTEXT_FILES[@]}"; do
            local resolved_file="$project_root/$file"
            if [[ ! -f "$resolved_file" ]]; then
                echo "Error: Context file not found: $file (resolved: $resolved_file)"
                exit 1
            fi
            resolved_files+=("$resolved_file")
        done
        filecat "${resolved_files[@]}" >> "$context_file"
    fi

    # Both modes: Add explicit files from CLI --context-file (PWD-relative)
    if [[ ${#CLI_CONTEXT_FILES[@]} -gt 0 ]]; then
        echo "  Adding explicit files from CLI..."
        local validated_files=()
        for file in "${CLI_CONTEXT_FILES[@]}"; do
            if [[ ! -f "$file" ]]; then
                echo "Error: Context file not found: $file"
                exit 1
            fi
            validated_files+=("$file")
        done
        filecat "${validated_files[@]}" >> "$context_file"
    fi

    # Check if any context was provided
    if [[ ! -s "$context_file" ]]; then
        echo "Warning: No context provided. Task will run without context."
        if [[ "$mode" == "run" ]]; then
            echo "  Use --context-file, --context-pattern, or --depends-on to add context"
        else
            echo "  Use --context-file or --context-pattern to add context"
        fi
    fi
}
