# =============================================================================
# Batch Processing Functions
# =============================================================================
# Functions for batch mode execution using the Anthropic Message Batches API.
# Handles batch request building, state management, and results processing.
# =============================================================================

# =============================================================================
# Batch State Management
# =============================================================================

# Save batch state to workflow directory
# Arguments:
#   $1 - workflow_dir: Workflow directory path
#   $2 - batch_id: Batch ID from API
#   $3 - status: Processing status
#   $4 - request_count: Number of requests in batch
# Side effects:
#   Creates batch-state.json in workflow directory
save_batch_state() {
    local workflow_dir="$1"
    local batch_id="$2"
    local status="$3"
    local request_count="$4"

    local state_file="$workflow_dir/batch-state.json"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Build input files array from BATCH_INPUT_MAP
    local input_map_json="${BATCH_INPUT_MAP:-[]}"

    jq -n \
        --arg batch_id "$batch_id" \
        --arg workflow "$WORKFLOW_NAME" \
        --arg created "$now" \
        --arg status "$status" \
        --argjson count "$request_count" \
        --argjson input_map "$input_map_json" \
        --arg checked "$now" \
        '{
            batch_id: $batch_id,
            workflow_name: $workflow,
            created_at: $created,
            status: $status,
            request_count: $count,
            completed_count: 0,
            failed_count: 0,
            input_map: $input_map,
            last_checked: $checked
        }' > "$state_file"
}

# Load batch state from workflow directory
# Arguments:
#   $1 - workflow_dir: Workflow directory path
# Returns:
#   0 - Success (sets BATCH_STATE_* variables)
#   1 - No state file found
# Side effects:
#   Sets BATCH_STATE_ID, BATCH_STATE_STATUS, BATCH_STATE_COUNT, etc.
load_batch_state() {
    local workflow_dir="$1"
    local state_file="$workflow_dir/batch-state.json"

    [[ ! -f "$state_file" ]] && return 1

    BATCH_STATE_ID=$(jq -r '.batch_id' "$state_file")
    BATCH_STATE_STATUS=$(jq -r '.status' "$state_file")
    BATCH_STATE_COUNT=$(jq -r '.request_count' "$state_file")
    BATCH_STATE_COMPLETED=$(jq -r '.completed_count' "$state_file")
    BATCH_STATE_FAILED=$(jq -r '.failed_count' "$state_file")
    BATCH_STATE_CREATED=$(jq -r '.created_at' "$state_file")
    BATCH_STATE_CHECKED=$(jq -r '.last_checked' "$state_file")

    return 0
}

# Update batch state with API response
# Arguments:
#   $1 - workflow_dir: Workflow directory path
#   $2 - batch_response: JSON response from API
# Side effects:
#   Updates batch-state.json with new status and counts
update_batch_state() {
    local workflow_dir="$1"
    local batch_response="$2"
    local state_file="$workflow_dir/batch-state.json"

    [[ ! -f "$state_file" ]] && return 1

    local status
    status=$(echo "$batch_response" | jq -r '.processing_status')

    local completed
    completed=$(echo "$batch_response" | jq -r '.request_counts.succeeded // 0')

    local failed
    failed=$(echo "$batch_response" | jq -r '.request_counts.errored // 0')

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Update state file
    jq \
        --arg status "$status" \
        --argjson completed "$completed" \
        --argjson failed "$failed" \
        --arg checked "$now" \
        '.status = $status | .completed_count = $completed | .failed_count = $failed | .last_checked = $checked' \
        "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
}

# Get batch display status for list command
# Arguments:
#   $1 - workflow_dir: Workflow directory path
# Returns:
#   Prints formatted status string or empty if no batch
get_batch_display_status() {
    local workflow_dir="$1"
    local state_file="$workflow_dir/batch-state.json"

    [[ ! -f "$state_file" ]] && return 0

    local status completed count ended_at
    status=$(jq -r '.status' "$state_file")
    completed=$(jq -r '.completed_count' "$state_file")
    count=$(jq -r '.request_count' "$state_file")

    case "$status" in
        in_progress|canceling)
            echo "[batch: $status $completed/$count]"
            ;;
        ended)
            # Show completion timestamp
            local checked
            checked=$(jq -r '.last_checked' "$state_file")
            # Format timestamp to local time (just date and time)
            local formatted
            formatted=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$checked" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$checked")
            echo "[batch: completed $formatted]"
            ;;
    esac
}

# =============================================================================
# Batch Request Building
# =============================================================================

# Build batch requests from input files
# Each input file becomes a separate request in the batch
# Arguments:
#   $1 - mode: "run" or "task"
#   $2 - project_root: Project root directory
#   $3 - workflow_dir: Workflow directory (for output)
# Requires:
#   SYSTEM_BLOCKS, CONTEXT_BLOCKS, CONTEXT_PDF_BLOCKS, etc. already populated
#   INPUT_FILES, INPUT_PATTERN, CLI_INPUT_FILES, CLI_INPUT_PATTERN
# Returns:
#   0 - Success
#   1 - Error (no input files)
# Side effects:
#   Creates batch-requests.json in workflow directory
#   Sets BATCH_INPUT_MAP as JSON array for state file
build_batch_requests() {
    local mode="$1"
    local project_root="$2"
    local workflow_dir="$3"

    echo "Building batch requests..."

    # Collect all input files into array
    local -a all_input_files=()

    # Run mode: Add from config
    if [[ "$mode" == "run" ]]; then
        for file in "${INPUT_FILES[@]}"; do
            [[ -n "$file" ]] && all_input_files+=("$project_root/$file")
        done

        if [[ -n "$INPUT_PATTERN" ]]; then
            local -a pattern_files
            pattern_files=($(cd "$project_root" && eval "echo $INPUT_PATTERN" 2>/dev/null))
            for file in "${pattern_files[@]}"; do
                [[ -f "$project_root/$file" ]] && all_input_files+=("$project_root/$file")
            done
        fi
    fi

    # Both modes: Add from CLI
    for file in "${CLI_INPUT_FILES[@]}"; do
        [[ -n "$file" && -f "$file" ]] && all_input_files+=("$file")
    done

    if [[ -n "$CLI_INPUT_PATTERN" ]]; then
        local -a pattern_files
        mapfile -t pattern_files < <(compgen -G "$CLI_INPUT_PATTERN" 2>/dev/null)
        for file in "${pattern_files[@]}"; do
            [[ -f "$file" ]] && all_input_files+=("$file")
        done
    fi

    # Validate we have input files
    if [[ ${#all_input_files[@]} -eq 0 ]]; then
        echo "Error: Batch mode requires at least one input file" >&2
        echo "Use --input-file or --input-pattern to specify input files" >&2
        return 1
    fi

    echo "  Found ${#all_input_files[@]} input file(s) for batch processing"

    # Resolve effective model
    local effective_model
    effective_model=$(resolve_model)

    # Build system blocks JSON (shared across all requests)
    local system_blocks_json
    system_blocks_json=$(printf '%s\n' "${SYSTEM_BLOCKS[@]}" | jq -s '.')

    # Build shared context blocks (everything except per-file input)
    local -a shared_user_blocks=()
    for block in "${CONTEXT_PDF_BLOCKS[@]}"; do
        shared_user_blocks+=("$block")
    done
    for block in "${CONTEXT_BLOCKS[@]}"; do
        shared_user_blocks+=("$block")
    done
    for block in "${DEPENDENCY_BLOCKS[@]}"; do
        shared_user_blocks+=("$block")
    done
    for block in "${IMAGE_BLOCKS[@]}"; do
        shared_user_blocks+=("$block")
    done

    # Add cache control breakpoint to last shared block (if any)
    if [[ ${#shared_user_blocks[@]} -gt 0 ]]; then
        local last_idx=$((${#shared_user_blocks[@]} - 1))
        shared_user_blocks[$last_idx]=$(echo "${shared_user_blocks[$last_idx]}" | jq '. + {cache_control: {type: "ephemeral"}}')
    fi

    local shared_blocks_json
    if [[ ${#shared_user_blocks[@]} -gt 0 ]]; then
        shared_blocks_json=$(printf '%s\n' "${shared_user_blocks[@]}" | jq -s '.')
    else
        shared_blocks_json="[]"
    fi

    # Initialize batch arrays
    local -a batch_requests=()
    local -a input_map=()

    # Build a request for each input file
    local request_idx=0
    for input_file in "${all_input_files[@]}"; do
        [[ ! -f "$input_file" ]] && continue

        # Generate custom_id from filename (sanitized)
        local basename_clean
        basename_clean=$(basename "$input_file" | sed 's/[^a-zA-Z0-9._-]/_/g')
        local custom_id="wfw-${basename_clean}-${request_idx}"

        echo "  [$((request_idx + 1))/${#all_input_files[@]}] Processing: $(basename "$input_file")"

        # Build input block for this file
        local input_block
        local file_content
        file_content=$(<"$input_file")

        # Wrap content with file metadata
        local tagged_content="<input-file name=\"$(basename "$input_file")\">"$'\n'"$file_content"$'\n'"</input-file>"

        input_block=$(jq -n \
            --arg type "text" \
            --arg text "$tagged_content" \
            '{type: $type, text: $text}')

        # Combine shared blocks + this input + task
        local user_blocks_json
        user_blocks_json=$(jq -n \
            --argjson shared "$shared_blocks_json" \
            --argjson input "[$input_block]" \
            --argjson task "[$TASK_BLOCK]" \
            '$shared + $input + $task')

        # Build request object
        local request
        request=$(jq -n \
            --arg custom_id "$custom_id" \
            --arg model "$effective_model" \
            --argjson max_tokens "$MAX_TOKENS" \
            --argjson temperature "$TEMPERATURE" \
            --argjson system "$system_blocks_json" \
            --argjson user_content "$user_blocks_json" \
            '{
                custom_id: $custom_id,
                params: {
                    model: $model,
                    max_tokens: $max_tokens,
                    temperature: $temperature,
                    system: $system,
                    messages: [{role: "user", content: $user_content}]
                }
            }')

        batch_requests+=("$request")

        # Track input file mapping
        input_map+=("$(jq -n --arg id "$custom_id" --arg path "$input_file" '{custom_id: $id, path: $path}')")

        request_idx=$((request_idx + 1))
    done

    echo "Built ${#batch_requests[@]} batch request(s)"

    # Save requests to file
    local requests_file="$workflow_dir/batch-requests.json"
    printf '%s\n' "${batch_requests[@]}" | jq -s '.' > "$requests_file"

    # Set input map for state file
    BATCH_INPUT_MAP=$(printf '%s\n' "${input_map[@]}" | jq -s '.')
    BATCH_REQUEST_COUNT=${#batch_requests[@]}

    return 0
}

# =============================================================================
# Batch Execution
# =============================================================================

# Execute batch mode - build requests and submit to API
# Arguments:
#   $1 - mode: "run" or "task"
#   $2 - project_root: Project root directory
#   $3 - workflow_dir: Workflow directory
# Returns:
#   0 - Success (batch submitted)
#   1 - Error
execute_batch_mode() {
    local mode="$1"
    local project_root="$2"
    local workflow_dir="$3"

    # Build batch requests
    if ! build_batch_requests "$mode" "$project_root" "$workflow_dir"; then
        return 1
    fi

    # Validate API key
    anthropic_validate "$ANTHROPIC_API_KEY" || return 1

    # Submit batch to API
    echo ""
    echo "Submitting batch to Anthropic API..."

    local requests_file="$workflow_dir/batch-requests.json"
    local batch_response
    batch_response=$(anthropic_create_batch \
        api_key="$ANTHROPIC_API_KEY" \
        requests_file="$requests_file")

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to submit batch" >&2
        return 1
    fi

    # Extract batch ID and status
    local batch_id status
    batch_id=$(echo "$batch_response" | jq -r '.id')
    status=$(echo "$batch_response" | jq -r '.processing_status')

    # Save batch state
    save_batch_state "$workflow_dir" "$batch_id" "$status" "$BATCH_REQUEST_COUNT"

    # Display success message
    echo ""
    echo "Batch submitted successfully!"
    echo "  Batch ID: $batch_id"
    echo "  Requests: $BATCH_REQUEST_COUNT"
    echo "  Status: $status"
    echo ""
    echo "Check status with:"
    echo "  $SCRIPT_NAME status ${WORKFLOW_NAME:-}"
    echo ""
    echo "Retrieve results when complete:"
    echo "  $SCRIPT_NAME results ${WORKFLOW_NAME:-}"

    return 0
}

# =============================================================================
# Batch Results Processing
# =============================================================================

# Process batch results and write output files
# Arguments:
#   $1 - workflow_dir: Workflow directory
#   $2 - output_dir: Output directory for result files
# Returns:
#   0 - Success
#   1 - Error
process_batch_results() {
    local workflow_dir="$1"
    local output_dir="$2"

    local state_file="$workflow_dir/batch-state.json"
    local results_file="$workflow_dir/batch-results.jsonl"

    [[ ! -f "$state_file" ]] && {
        echo "Error: No batch state found" >&2
        return 1
    }

    local batch_id
    batch_id=$(jq -r '.batch_id' "$state_file")

    echo "Retrieving results for batch: $batch_id"

    # Validate API key
    anthropic_validate "$ANTHROPIC_API_KEY" || return 1

    # Download results
    anthropic_get_batch_results \
        api_key="$ANTHROPIC_API_KEY" \
        batch_id="$batch_id" \
        output_file="$results_file"

    if [[ $? -ne 0 || ! -f "$results_file" ]]; then
        echo "Error: Failed to retrieve batch results" >&2
        return 1
    fi

    # Create output directory
    mkdir -p "$output_dir"

    # Process each result line
    local success_count=0
    local error_count=0
    local errors_log="$workflow_dir/batch-errors.log"
    > "$errors_log"  # Clear errors log

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local custom_id result_type
        custom_id=$(echo "$line" | jq -r '.custom_id')
        result_type=$(echo "$line" | jq -r '.result.type')

        # Get original input file path from state
        local input_path
        input_path=$(jq -r --arg id "$custom_id" '.input_map[] | select(.custom_id == $id) | .path' "$state_file")

        # Determine output filename (mirror input structure)
        local output_basename
        output_basename=$(basename "$input_path" | sed 's/\.[^.]*$//')

        if [[ "$result_type" == "succeeded" ]]; then
            # Extract response text
            local response_text
            response_text=$(echo "$line" | jq -r '.result.message.content[] | select(.type == "text") | .text')

            # Write to output file
            local output_file="$output_dir/${output_basename}.${OUTPUT_FORMAT}"
            echo "$response_text" > "$output_file"

            echo "  [OK] ${output_basename} -> $(basename "$output_file")"
            ((success_count++))
        else
            # Log error
            local error_msg
            error_msg=$(echo "$line" | jq -r '.result.error.message // "Unknown error"')
            echo "  [ERROR] ${output_basename}: $error_msg" >&2
            echo "${output_basename}: $error_msg" >> "$errors_log"
            ((error_count++))
        fi
    done < "$results_file"

    echo ""
    echo "Batch results: $success_count succeeded, $error_count failed"
    echo "Output directory: $(display_absolute_path "$output_dir")"

    if [[ $error_count -gt 0 ]]; then
        echo "See errors: $(display_absolute_path "$errors_log")"
    fi

    return 0
}

# =============================================================================
# Batch Command Handlers
# =============================================================================

# Show batch status for all workflows or specific workflow
# Arguments:
#   $@ - Optional workflow name
cmd_batch_status() {
    local workflow_name="${1:-}"

    # Try to find project root
    local project_root
    project_root=$(find_project_root 2>/dev/null) || true

    # If no project context, show global batches from API
    if [[ -z "$project_root" ]]; then
        echo "Checking Anthropic API for recent batches..."

        anthropic_validate "$ANTHROPIC_API_KEY" || return 1

        local batches
        batches=$(anthropic_list_batches api_key="$ANTHROPIC_API_KEY" limit=10)

        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to list batches" >&2
            return 1
        fi

        echo ""
        echo "Recent Batches (last 10):"
        echo "$batches" | jq -r '.data[] | "  \(.id)  \(.processing_status)  \(.created_at | split("T")[0])  \(.request_counts.succeeded)/\(.request_counts.processing + .request_counts.succeeded + .request_counts.errored + .request_counts.canceled + .request_counts.expired) completed"'
        return 0
    fi

    # Project context available
    local wireflow_dir="$project_root/.workflow"
    local run_dir="$wireflow_dir/run"

    if [[ -n "$workflow_name" ]]; then
        # Show status for specific workflow
        local workflow_dir="$run_dir/$workflow_name"

        if [[ ! -d "$workflow_dir" ]]; then
            echo "Error: Workflow not found: $workflow_name" >&2
            return 1
        fi

        local state_file="$workflow_dir/batch-state.json"
        if [[ ! -f "$state_file" ]]; then
            echo "No batch found for workflow: $workflow_name"
            return 0
        fi

        echo "Batch Status for '$workflow_name':"
        echo ""

        local batch_id
        batch_id=$(jq -r '.batch_id' "$state_file")

        # Get latest status from API
        anthropic_validate "$ANTHROPIC_API_KEY" || {
            # Show cached status if API unavailable
            echo "  (showing cached status - API unavailable)"
            jq -r '"  Batch ID: \(.batch_id)\n  Status: \(.status)\n  Progress: \(.completed_count)/\(.request_count)\n  Last checked: \(.last_checked)"' "$state_file"
            return 0
        }

        local batch_response
        batch_response=$(anthropic_get_batch api_key="$ANTHROPIC_API_KEY" batch_id="$batch_id")

        if [[ $? -ne 0 ]]; then
            echo "  (showing cached status - API error)"
            jq -r '"  Batch ID: \(.batch_id)\n  Status: \(.status)\n  Progress: \(.completed_count)/\(.request_count)\n  Last checked: \(.last_checked)"' "$state_file"
            return 0
        fi

        # Update local state
        update_batch_state "$workflow_dir" "$batch_response"

        # Display status
        echo "$batch_response" | jq -r '"  Batch ID: \(.id)
  Status: \(.processing_status)
  Created: \(.created_at)
  Requests: \(.request_counts.processing + .request_counts.succeeded + .request_counts.errored + .request_counts.canceled + .request_counts.expired)
  Succeeded: \(.request_counts.succeeded)
  Errored: \(.request_counts.errored)
  Processing: \(.request_counts.processing)"'

        # If ended, offer to retrieve results
        local status
        status=$(echo "$batch_response" | jq -r '.processing_status')

        if [[ "$status" == "ended" ]]; then
            echo ""
            echo "Batch completed. Retrieve results with:"
            echo "  $SCRIPT_NAME results $workflow_name"
        fi
    else
        # Show status for all workflows with batches
        echo "Batch Status for Project: $(display_absolute_path "$project_root")"
        echo ""

        local found_any=false

        for workflow_dir in "$run_dir"/*/; do
            [[ ! -d "$workflow_dir" ]] && continue

            local state_file="$workflow_dir/batch-state.json"
            [[ ! -f "$state_file" ]] && continue

            found_any=true

            local name batch_id status completed total
            name=$(basename "$workflow_dir")
            batch_id=$(jq -r '.batch_id' "$state_file")
            status=$(jq -r '.status' "$state_file")
            completed=$(jq -r '.completed_count' "$state_file")
            total=$(jq -r '.request_count' "$state_file")

            printf "  %-20s %-15s %s/%s  %s\n" "$name" "$status" "$completed" "$total" "$batch_id"
        done

        if [[ "$found_any" == false ]]; then
            echo "  No active batches found"
        fi
    fi

    return 0
}

# Cancel a pending batch
# Arguments:
#   $1 - workflow_name: Workflow name
cmd_batch_cancel() {
    local workflow_name="$1"

    # Find project root
    local project_root
    project_root=$(find_project_root) || {
        echo "Error: No project found" >&2
        return 1
    }

    local workflow_dir="$project_root/.workflow/run/$workflow_name"
    local state_file="$workflow_dir/batch-state.json"

    if [[ ! -f "$state_file" ]]; then
        echo "Error: No batch found for workflow: $workflow_name" >&2
        return 1
    fi

    local batch_id status
    batch_id=$(jq -r '.batch_id' "$state_file")
    status=$(jq -r '.status' "$state_file")

    if [[ "$status" == "ended" ]]; then
        echo "Batch already completed. Nothing to cancel."
        return 0
    fi

    echo "Canceling batch: $batch_id"

    # Validate API key
    anthropic_validate "$ANTHROPIC_API_KEY" || return 1

    # Cancel batch
    local response
    response=$(anthropic_cancel_batch api_key="$ANTHROPIC_API_KEY" batch_id="$batch_id")

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to cancel batch" >&2
        return 1
    fi

    # Update local state
    update_batch_state "$workflow_dir" "$response"

    echo "Batch cancellation initiated."
    echo "Status: $(echo "$response" | jq -r '.processing_status')"

    return 0
}

# Retrieve batch results
# Arguments:
#   $1 - workflow_name: Workflow name
cmd_batch_results() {
    local workflow_name="$1"

    # Find project root
    local project_root
    project_root=$(find_project_root) || {
        echo "Error: No project found" >&2
        return 1
    }

    local workflow_dir="$project_root/.workflow/run/$workflow_name"
    local state_file="$workflow_dir/batch-state.json"

    if [[ ! -f "$state_file" ]]; then
        echo "Error: No batch found for workflow: $workflow_name" >&2
        return 1
    fi

    # Check if batch is complete
    local batch_id
    batch_id=$(jq -r '.batch_id' "$state_file")

    # Get latest status from API
    anthropic_validate "$ANTHROPIC_API_KEY" || return 1

    local batch_response
    batch_response=$(anthropic_get_batch api_key="$ANTHROPIC_API_KEY" batch_id="$batch_id")

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to get batch status" >&2
        return 1
    fi

    local status
    status=$(echo "$batch_response" | jq -r '.processing_status')

    if [[ "$status" != "ended" ]]; then
        echo "Batch is still processing (status: $status)"
        echo "Check status with: $SCRIPT_NAME status $workflow_name"
        return 1
    fi

    # Update local state
    update_batch_state "$workflow_dir" "$batch_response"

    # Output directory mirrors input structure
    local output_dir="$project_root/.workflow/output/$workflow_name"

    # Process results
    process_batch_results "$workflow_dir" "$output_dir"

    return $?
}
