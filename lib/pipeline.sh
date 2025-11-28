# =============================================================================
# Pipeline Functions - Workflow Dependency Resolution and Execution Caching
# =============================================================================
# Functions for automatic dependency execution, staleness detection, and
# workflow execution logging.
# =============================================================================

# =============================================================================
# Execution Log Management
# =============================================================================

# Write execution log after successful workflow completion
# Arguments:
#   $1 - workflow_name: Name of the workflow
#   $2 - workflow_dir: Workflow directory path
#   $3 - output_file: Path to output file
#   $4 - project_root: Project root directory
# Side effects:
#   Creates execution.json in workflow directory
write_execution_log() {
    local workflow_name="$1"
    local workflow_dir="$2"
    local output_file="$3"
    local project_root="$4"

    local exec_log="$workflow_dir/execution.json"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Compute execution hash
    local exec_hash
    exec_hash=$(compute_execution_hash "$workflow_name" "$workflow_dir" "$project_root")

    # Build config object
    local config_json
    config_json=$(jq -n \
        --arg profile "$PROFILE" \
        --arg model "$MODEL" \
        --arg temperature "$TEMPERATURE" \
        --arg max_tokens "$MAX_TOKENS" \
        --arg enable_thinking "$ENABLE_THINKING" \
        --arg thinking_budget "$THINKING_BUDGET" \
        --arg effort "$EFFORT" \
        --arg enable_citations "$ENABLE_CITATIONS" \
        --arg output_format "$OUTPUT_FORMAT" \
        --argjson system_prompts "$(printf '%s\n' "${SYSTEM_PROMPTS[@]}" | jq -R . | jq -s .)" \
        '{
            profile: $profile,
            model: $model,
            temperature: ($temperature | tonumber),
            max_tokens: ($max_tokens | tonumber),
            enable_thinking: ($enable_thinking == "true"),
            thinking_budget: ($thinking_budget | tonumber),
            effort: $effort,
            enable_citations: ($enable_citations == "true"),
            output_format: $output_format,
            system_prompts: $system_prompts
        }')

    # Build config_sources object
    local config_sources_json
    config_sources_json=$(jq -n \
        --arg profile "${CONFIG_SOURCE_MAP[PROFILE]}" \
        --arg model "${CONFIG_SOURCE_MAP[MODEL]}" \
        --arg temperature "${CONFIG_SOURCE_MAP[TEMPERATURE]}" \
        --arg max_tokens "${CONFIG_SOURCE_MAP[MAX_TOKENS]}" \
        --arg enable_thinking "${CONFIG_SOURCE_MAP[ENABLE_THINKING]}" \
        --arg thinking_budget "${CONFIG_SOURCE_MAP[THINKING_BUDGET]}" \
        --arg effort "${CONFIG_SOURCE_MAP[EFFORT]}" \
        --arg enable_citations "${CONFIG_SOURCE_MAP[ENABLE_CITATIONS]}" \
        --arg output_format "${CONFIG_SOURCE_MAP[OUTPUT_FORMAT]}" \
        --arg system_prompts "${CONFIG_SOURCE_MAP[SYSTEM_PROMPTS]}" \
        '{
            profile: $profile,
            model: $model,
            temperature: $temperature,
            max_tokens: $max_tokens,
            enable_thinking: $enable_thinking,
            thinking_budget: $thinking_budget,
            effort: $effort,
            enable_citations: $enable_citations,
            output_format: $output_format,
            system_prompts: $system_prompts
        }')

    # Build context array
    local context_json="[]"
    for file in "${CONTEXT[@]}"; do
        local abs_path="$project_root/$file"
        [[ ! -f "$abs_path" ]] && continue
        local file_mtime file_size file_hash
        file_mtime=$(stat -f%m "$abs_path" 2>/dev/null) || continue
        file_size=$(stat -f%z "$abs_path" 2>/dev/null) || continue
        # Only compute hash for files <= 10MB
        if [[ $file_size -le 10485760 ]]; then
            file_hash="sha256:$(shasum -a 256 "$abs_path" 2>/dev/null | cut -c1-16)"
        else
            file_hash="sha256:skipped-large-file"
        fi
        context_json=$(echo "$context_json" | jq \
            --arg path "$file" \
            --arg abs_path "$abs_path" \
            --argjson mtime "$file_mtime" \
            --argjson size "$file_size" \
            --arg hash "$file_hash" \
            '. + [{path: $path, abs_path: $abs_path, mtime: $mtime, size: $size, hash: $hash}]')
    done

    # Build input array
    local input_json="[]"
    for file in "${INPUT[@]}"; do
        local abs_path="$project_root/$file"
        [[ ! -f "$abs_path" ]] && continue
        local file_mtime file_size file_hash
        file_mtime=$(stat -f%m "$abs_path" 2>/dev/null) || continue
        file_size=$(stat -f%z "$abs_path" 2>/dev/null) || continue
        if [[ $file_size -le 10485760 ]]; then
            file_hash="sha256:$(shasum -a 256 "$abs_path" 2>/dev/null | cut -c1-16)"
        else
            file_hash="sha256:skipped-large-file"
        fi
        input_json=$(echo "$input_json" | jq \
            --arg path "$file" \
            --arg abs_path "$abs_path" \
            --argjson mtime "$file_mtime" \
            --argjson size "$file_size" \
            --arg hash "$file_hash" \
            '. + [{path: $path, abs_path: $abs_path, mtime: $mtime, size: $size, hash: $hash}]')
    done

    # Build depends_on array
    local depends_json="[]"
    for dep in "${DEPENDS_ON[@]}"; do
        local dep_exec_log="$RUN_DIR/$dep/execution.json"
        local dep_hash=""
        local dep_output=""
        if [[ -f "$dep_exec_log" ]]; then
            dep_hash=$(jq -r '.execution_hash // ""' "$dep_exec_log" 2>/dev/null)
            dep_output=$(jq -r '.output.path // ""' "$dep_exec_log" 2>/dev/null)
        fi
        depends_json=$(echo "$depends_json" | jq \
            --arg workflow "$dep" \
            --arg exec_hash "$dep_hash" \
            --arg output_path "$dep_output" \
            '. + [{workflow: $workflow, execution_hash: $exec_hash, output_path: $output_path}]')
    done

    # Build output object
    local output_json
    local output_size output_hash
    if [[ -f "$output_file" ]]; then
        output_size=$(stat -f%z "$output_file" 2>/dev/null) || output_size=0
        output_hash="sha256:$(shasum -a 256 "$output_file" 2>/dev/null | cut -c1-16)"
    else
        output_size=0
        output_hash=""
    fi
    # Convert absolute path to project-relative
    local output_rel_path="${output_file#$project_root/}"
    output_json=$(jq -n \
        --arg path "$output_rel_path" \
        --argjson size "$output_size" \
        --arg hash "$output_hash" \
        '{path: $path, size: $size, hash: $hash}')

    # Assemble final execution log
    jq -n \
        --argjson version 1 \
        --arg workflow "$workflow_name" \
        --arg executed_at "$now" \
        --arg execution_hash "$exec_hash" \
        --argjson config "$config_json" \
        --argjson config_sources "$config_sources_json" \
        --argjson context "$context_json" \
        --argjson input "$input_json" \
        --argjson depends_on "$depends_json" \
        --argjson output "$output_json" \
        '{
            version: $version,
            workflow: $workflow,
            executed_at: $executed_at,
            execution_hash: $execution_hash,
            config: $config,
            config_sources: $config_sources,
            context: $context,
            input: $input,
            depends_on: $depends_on,
            output: $output
        }' > "$exec_log"
}

# Read execution log from workflow directory
# Arguments:
#   $1 - workflow_dir: Workflow directory path
# Returns:
#   0 - Success
#   1 - No execution log found
# Side effects:
#   Sets EXEC_LOG_* variables with parsed values
read_execution_log() {
    local workflow_dir="$1"
    local exec_log="$workflow_dir/execution.json"

    [[ ! -f "$exec_log" ]] && return 1

    EXEC_LOG_HASH=$(jq -r '.execution_hash // ""' "$exec_log")
    EXEC_LOG_TIMESTAMP=$(jq -r '.executed_at // ""' "$exec_log")
    EXEC_LOG_OUTPUT=$(jq -r '.output.path // ""' "$exec_log")

    return 0
}

# =============================================================================
# Staleness Detection
# =============================================================================

# Compute execution hash for cache validation
# Arguments:
#   $1 - workflow_name: Name of the workflow
#   $2 - workflow_dir: Workflow directory path
#   $3 - project_root: Project root directory
# Returns:
#   stdout - 16-character hash of execution state
compute_execution_hash() {
    local workflow_name="$1"
    local workflow_dir="$2"
    local project_root="$3"

    local hash_input=""

    # Config state (sorted for determinism)
    hash_input+="config:$PROFILE|$MODEL|$TEMPERATURE|$MAX_TOKENS|"
    hash_input+="thinking:$ENABLE_THINKING|$THINKING_BUDGET|"
    hash_input+="effort:$EFFORT|citations:$ENABLE_CITATIONS|"
    hash_input+="format:$OUTPUT_FORMAT|"
    hash_input+="prompts:$(printf '%s,' "${SYSTEM_PROMPTS[@]}")|"

    # Context file hashes (sorted for determinism)
    for file in "${CONTEXT[@]}"; do
        local abs_path="$project_root/$file"
        if [[ -f "$abs_path" ]]; then
            local file_hash
            file_hash=$(shasum -a 256 "$abs_path" 2>/dev/null | cut -c1-16)
            hash_input+="cx:$file:$file_hash|"
        fi
    done

    # Input file hashes
    for file in "${INPUT[@]}"; do
        local abs_path="$project_root/$file"
        if [[ -f "$abs_path" ]]; then
            local file_hash
            file_hash=$(shasum -a 256 "$abs_path" 2>/dev/null | cut -c1-16)
            hash_input+="in:$file:$file_hash|"
        fi
    done

    # Dependency execution hashes (recursive validation)
    for dep in "${DEPENDS_ON[@]}"; do
        local dep_exec_log="$RUN_DIR/$dep/execution.json"
        local dep_hash=""
        if [[ -f "$dep_exec_log" ]]; then
            dep_hash=$(jq -r '.execution_hash // ""' "$dep_exec_log" 2>/dev/null)
        fi
        hash_input+="dep:$dep:$dep_hash|"
    done

    # Task file hash
    local task_file="$workflow_dir/task.txt"
    if [[ -f "$task_file" ]]; then
        local task_hash
        task_hash=$(shasum -a 256 "$task_file" 2>/dev/null | cut -c1-16)
        hash_input+="task:$task_hash"
    fi

    echo "$hash_input" | shasum -a 256 | cut -c1-16
}

# Check if workflow execution is stale
# Arguments:
#   $1 - workflow_name: Name of the workflow
# Returns:
#   0 - Stale (needs re-run)
#   1 - Fresh (cache valid)
is_execution_stale() {
    local workflow_name="$1"
    local workflow_dir="$RUN_DIR/$workflow_name"
    local exec_log="$workflow_dir/execution.json"

    # No execution log = definitely stale
    [[ ! -f "$exec_log" ]] && return 0

    # Check if output file exists
    local output_path
    output_path=$(jq -r '.output.path // ""' "$exec_log")
    [[ -z "$output_path" || ! -f "$PROJECT_ROOT/$output_path" ]] && return 0

    # Fast path: mtime check
    local exec_timestamp
    exec_timestamp=$(jq -r '.executed_at // ""' "$exec_log")
    [[ -z "$exec_timestamp" ]] && return 0

    # Convert ISO timestamp to epoch (macOS)
    local exec_epoch
    exec_epoch=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$exec_timestamp" +%s 2>/dev/null) || return 0

    # Check if any source file is newer than execution
    local any_newer=false

    # Check context files
    while IFS= read -r file_info; do
        [[ -z "$file_info" ]] && continue
        local abs_path stored_mtime
        abs_path=$(echo "$file_info" | jq -r '.abs_path')
        stored_mtime=$(echo "$file_info" | jq -r '.mtime')

        local current_mtime
        current_mtime=$(stat -f%m "$abs_path" 2>/dev/null) || continue
        if [[ "$current_mtime" -gt "$stored_mtime" ]]; then
            any_newer=true
            break
        fi
    done < <(jq -c '.context[]?' "$exec_log" 2>/dev/null)

    # Check input files if context was all fresh
    if [[ "$any_newer" == "false" ]]; then
        while IFS= read -r file_info; do
            [[ -z "$file_info" ]] && continue
            local abs_path stored_mtime
            abs_path=$(echo "$file_info" | jq -r '.abs_path')
            stored_mtime=$(echo "$file_info" | jq -r '.mtime')

            local current_mtime
            current_mtime=$(stat -f%m "$abs_path" 2>/dev/null) || continue
            if [[ "$current_mtime" -gt "$stored_mtime" ]]; then
                any_newer=true
                break
            fi
        done < <(jq -c '.input[]?' "$exec_log" 2>/dev/null)
    fi

    # Check task file mtime
    if [[ "$any_newer" == "false" ]]; then
        local task_file="$workflow_dir/task.txt"
        if [[ -f "$task_file" ]]; then
            local task_mtime
            task_mtime=$(stat -f%m "$task_file" 2>/dev/null) || true
            [[ -n "$task_mtime" && "$task_mtime" -gt "$exec_epoch" ]] && any_newer=true
        fi
    fi

    # Check dependency staleness
    if [[ "$any_newer" == "false" ]]; then
        while IFS= read -r dep_info; do
            [[ -z "$dep_info" ]] && continue
            local dep_name stored_dep_hash
            dep_name=$(echo "$dep_info" | jq -r '.workflow')
            stored_dep_hash=$(echo "$dep_info" | jq -r '.execution_hash')

            # Check if dependency's execution hash changed
            local dep_exec_log="$RUN_DIR/$dep_name/execution.json"
            if [[ -f "$dep_exec_log" ]]; then
                local current_dep_hash
                current_dep_hash=$(jq -r '.execution_hash // ""' "$dep_exec_log")
                if [[ "$current_dep_hash" != "$stored_dep_hash" ]]; then
                    any_newer=true
                    break
                fi
            else
                # Dependency has no execution log - stale
                any_newer=true
                break
            fi
        done < <(jq -c '.depends_on[]?' "$exec_log" 2>/dev/null)
    fi

    # Fast path: nothing newer = still fresh
    [[ "$any_newer" == "false" ]] && return 1

    # Slow path: verify with hash comparison
    local stored_hash current_hash
    stored_hash=$(jq -r '.execution_hash // ""' "$exec_log")
    current_hash=$(compute_execution_hash "$workflow_name" "$workflow_dir" "$PROJECT_ROOT")

    [[ "$stored_hash" != "$current_hash" ]]
}

# Get staleness reason for display
# Arguments:
#   $1 - workflow_name: Name of the workflow
# Returns:
#   stdout - Staleness reason string
get_staleness_reason() {
    local workflow_name="$1"
    local workflow_dir="$RUN_DIR/$workflow_name"
    local exec_log="$workflow_dir/execution.json"

    [[ ! -f "$exec_log" ]] && echo "not run" && return

    local output_path
    output_path=$(jq -r '.output.path // ""' "$exec_log")
    [[ -z "$output_path" || ! -f "$PROJECT_ROOT/$output_path" ]] && echo "output missing" && return

    # Check for newer files (simplified check)
    local exec_timestamp exec_epoch
    exec_timestamp=$(jq -r '.executed_at // ""' "$exec_log")
    exec_epoch=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$exec_timestamp" +%s 2>/dev/null) || { echo "invalid timestamp"; return; }

    # Check task file
    local task_file="$workflow_dir/task.txt"
    if [[ -f "$task_file" ]]; then
        local task_mtime
        task_mtime=$(stat -f%m "$task_file" 2>/dev/null)
        [[ -n "$task_mtime" && "$task_mtime" -gt "$exec_epoch" ]] && echo "task changed" && return
    fi

    # Check context/input files
    while IFS= read -r file_info; do
        [[ -z "$file_info" ]] && continue
        local abs_path stored_mtime
        abs_path=$(echo "$file_info" | jq -r '.abs_path')
        stored_mtime=$(echo "$file_info" | jq -r '.mtime')
        local current_mtime
        current_mtime=$(stat -f%m "$abs_path" 2>/dev/null) || continue
        [[ "$current_mtime" -gt "$stored_mtime" ]] && echo "context changed" && return
    done < <(jq -c '.context[]?, .input[]?' "$exec_log" 2>/dev/null)

    # Check dependencies
    while IFS= read -r dep_info; do
        [[ -z "$dep_info" ]] && continue
        local dep_name stored_dep_hash
        dep_name=$(echo "$dep_info" | jq -r '.workflow')
        stored_dep_hash=$(echo "$dep_info" | jq -r '.execution_hash')
        local dep_exec_log="$RUN_DIR/$dep_name/execution.json"
        if [[ -f "$dep_exec_log" ]]; then
            local current_dep_hash
            current_dep_hash=$(jq -r '.execution_hash // ""' "$dep_exec_log")
            [[ "$current_dep_hash" != "$stored_dep_hash" ]] && echo "dependency changed" && return
        else
            echo "dependency not run" && return
        fi
    done < <(jq -c '.depends_on[]?' "$exec_log" 2>/dev/null)

    echo "fresh"
}

# =============================================================================
# Dependency Resolution
# =============================================================================

# Extract DEPENDS_ON array from a workflow config file
# Arguments:
#   $1 - config_file: Path to workflow config file
# Returns:
#   stdout - Space-separated list of dependency names
extract_depends_on() {
    local config_file="$1"

    [[ ! -f "$config_file" ]] && return 0

    # Source config in subshell and extract DEPENDS_ON
    (
        DEPENDS_ON=()
        source "$config_file" 2>/dev/null || true
        printf '%s\n' "${DEPENDS_ON[@]}"
    )
}

# Resolve dependency execution order using topological sort
# Arguments:
#   $1 - target_workflow: The workflow to resolve dependencies for
# Returns:
#   0 - Success (outputs execution order to stdout, one workflow per line)
#   1 - Circular dependency detected
resolve_dependency_order() {
    local target_workflow="$1"
    local -A visited=()
    local -A in_stack=()
    local -a order=()
    local -a cycle_path=()

    visit_workflow() {
        local wf="$1"

        # Cycle detection
        if [[ "${in_stack[$wf]}" == "1" ]]; then
            echo "Error: Circular dependency detected: ${cycle_path[*]} -> $wf" >&2
            return 1
        fi

        # Already processed
        [[ "${visited[$wf]}" == "1" ]] && return 0

        in_stack[$wf]=1
        cycle_path+=("$wf")

        # Load workflow's DEPENDS_ON
        local wf_config="$RUN_DIR/$wf/config"
        if [[ -f "$wf_config" ]]; then
            local deps
            deps=$(extract_depends_on "$wf_config")
            while IFS= read -r dep; do
                [[ -z "$dep" ]] && continue

                # Check dependency workflow exists
                if [[ ! -d "$RUN_DIR/$dep" ]]; then
                    echo "Error: Dependency workflow not found: '$dep'" >&2
                    echo "Create it with: $SCRIPT_NAME new $dep" >&2
                    return 1
                fi

                visit_workflow "$dep" || return 1
            done <<< "$deps"
        fi

        in_stack[$wf]=0
        unset 'cycle_path[-1]'
        visited[$wf]=1
        order+=("$wf")
        return 0
    }

    visit_workflow "$target_workflow" || return 1

    # Return order (dependencies first, target last)
    printf '%s\n' "${order[@]}"
}

# =============================================================================
# Dependency Execution
# =============================================================================

# Execute a dependency workflow in an isolated subprocess
# Arguments:
#   $1 - dep: Dependency workflow name
# Returns:
#   0 - Success
#   1 - Failure
execute_dependency() {
    local dep="$1"

    # Execute in subshell for complete config isolation
    (
        # Reset workflow context for the dependency
        WORKFLOW_NAME="$dep"
        WORKFLOW_DIR="$RUN_DIR/$dep"
        WORKFLOW_CONFIG="$WORKFLOW_DIR/config"

        # Restore project-level config state from cache
        reset_workflow_config

        # Apply dependency's workflow config on top of project baseline
        load_workflow_config || exit 1

        # Execute without auto-deps to prevent infinite recursion
        execute_run_mode --no-auto-deps
    )
    local dep_exit_code=$?

    if [[ $dep_exit_code -ne 0 ]]; then
        echo "Error: Dependency '$dep' failed with exit code $dep_exit_code" >&2
        return 1
    fi

    return 0
}

# Restore project-level config from cache
# Called in subshell before loading dependency's workflow config
reset_workflow_config() {
    local key

    # Restore all cached scalars
    for key in "${!PROJECT_CONFIG_CACHE[@]}"; do
        printf -v "$key" '%s' "${PROJECT_CONFIG_CACHE[$key]}"
    done

    # Restore all cached arrays
    for key in "${!PROJECT_CONFIG_ARRAYS[@]}"; do
        declare -n arr="$key"
        if [[ -n "${PROJECT_CONFIG_ARRAYS[$key]}" ]]; then
            IFS=$'\n' read -r -d '' -a arr <<< "${PROJECT_CONFIG_ARRAYS[$key]}" || true
        else
            arr=()
        fi
        unset -n arr
    done

    # Clear workflow-specific settings (not inheritable from project)
    DEPENDS_ON=()
    INPUT=()

    # Reset source tracking for workflow-level keys
    for key in "${WORKFLOW_KEYS[@]}"; do
        WORKFLOW_SOURCE_MAP[$key]="unset"
    done
}

# =============================================================================
# Display Helpers
# =============================================================================

# Get execution status for workflow listing display
# Arguments:
#   $1 - workflow_name: Name of the workflow
# Returns:
#   stdout - Status string like "[fresh]" or "[stale: input changed]"
get_execution_status() {
    local workflow_name="$1"
    local workflow_dir="$RUN_DIR/$workflow_name"
    local exec_log="$workflow_dir/execution.json"

    if [[ ! -f "$exec_log" ]]; then
        echo "[pending]"
        return
    fi

    if is_execution_stale "$workflow_name"; then
        local reason
        reason=$(get_staleness_reason "$workflow_name")
        echo "[stale: $reason]"
    else
        echo "[fresh]"
    fi
}

# Get last execution timestamp for display
# Arguments:
#   $1 - workflow_name: Name of the workflow
# Returns:
#   stdout - Formatted timestamp or "(not run)"
get_execution_timestamp() {
    local workflow_name="$1"
    local exec_log="$RUN_DIR/$workflow_name/execution.json"

    if [[ ! -f "$exec_log" ]]; then
        echo "(not run)"
        return
    fi

    local timestamp
    timestamp=$(jq -r '.executed_at // ""' "$exec_log")
    if [[ -n "$timestamp" ]]; then
        # Convert to local time format
        date -jf "%Y-%m-%dT%H:%M:%SZ" "$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$timestamp"
    else
        echo "(unknown)"
    fi
}
