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

# Estimate token counts from JSON content blocks and optionally call Anthropic API for exact counts
# Uses simple heuristic: ~4 chars per token (reasonable for English)
#
# Requires:
#   SYSTEM_BLOCKS: Array of system content blocks
#   CONTEXT_BLOCKS: Array of context content blocks
#   DEPENDENCY_BLOCKS: Array of dependency content blocks
#   INPUT_BLOCKS: Array of input document content blocks
#   TASK_BLOCK: Task content block
#   COUNT_TOKENS: Boolean flag
#   DRY_RUN: Boolean flag
# Returns:
#   0 normally, or exits if COUNT_TOKENS && !DRY_RUN
estimate_tokens() {
    # Skip if not requested
    [[ "$COUNT_TOKENS" != true ]] && return 0

    echo "Estimating tokens from JSON content blocks..."
    echo ""

    # System tokens (from SYSTEM_BLOCKS array)
    local system_json
    system_json=$(printf '%s\n' "${SYSTEM_BLOCKS[@]}" | jq -s '.')
    local system_chars
    system_chars=$(echo "$system_json" | wc -c)
    local systc=$((system_chars / 4))
    echo "Estimated system tokens: $systc"

    # Task tokens (from TASK_BLOCK)
    local task_chars
    task_chars=$(echo "$TASK_BLOCK" | wc -c)
    local tasktc=$((task_chars / 4))
    echo "Estimated task tokens: $tasktc"

    # Context tokens (from CONTEXT_BLOCKS and DEPENDENCY_BLOCKS)
    local context_chars=0
    for block in "${CONTEXT_BLOCKS[@]}"; do
        context_chars=$((context_chars + $(echo "$block" | wc -c)))
    done
    for block in "${DEPENDENCY_BLOCKS[@]}"; do
        context_chars=$((context_chars + $(echo "$block" | wc -c)))
    done
    local contexttc=$((context_chars / 4))
    if [[ $contexttc -gt 0 ]]; then
        echo "Estimated context tokens: $contexttc"
    fi

    # Input tokens (from INPUT_BLOCKS)
    local input_chars=0
    for block in "${INPUT_BLOCKS[@]}"; do
        input_chars=$((input_chars + $(echo "$block" | wc -c)))
    done
    local inputtc=$((input_chars / 4))
    if [[ $inputtc -gt 0 ]]; then
        echo "Estimated input documents tokens: $inputtc"
    fi

    # Image tokens (from IMAGE_BLOCKS)
    # Formula: tokens = (width × height) / 750
    local imagetc=0
    local image_count=${#IMAGE_BLOCKS[@]}
    if [[ $image_count -gt 0 ]]; then
        echo "Processing $image_count image(s) for token estimation..."
        for block in "${IMAGE_BLOCKS[@]}"; do
            # Extract base64 data and decode to get file info
            # For estimation, we'll use a conservative estimate of 1600 tokens per image
            # (assumes ~1.15 megapixels per the API docs recommendation)
            imagetc=$((imagetc + 1600))
        done
        echo "Estimated image tokens: $imagetc (~1600 tokens per image)"
    fi

    # Total (heuristic)
    local total_tokens=$((systc + tasktc + inputtc + contexttc + imagetc))
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
            for block in "${IMAGE_BLOCKS[@]}"; do
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

# Handle dry-run mode: save JSON blocks and API request to files and open in editor
# Only activates if DRY_RUN flag is set
#
# Args:
#   $1 - mode: "run" or "task"
#   $2 - workflow_dir: Workflow directory (for run mode) or empty (for task mode)
# Requires:
#   DRY_RUN: Boolean flag
#   COUNT_TOKENS: Boolean flag
#   SYSTEM_BLOCKS: Array of system content blocks
#   CONTEXT_BLOCKS: Array of context content blocks
#   DEPENDENCY_BLOCKS: Array of dependency content blocks
#   INPUT_BLOCKS: Array of input document content blocks
#   TASK_BLOCK: Task content block
# Returns:
#   Exits script (does not return)
handle_dry_run_mode() {
    local mode="$1"
    local workflow_dir="$2"

    # Skip if not in dry-run mode
    [[ "$DRY_RUN" != true ]] && return 0

    local dry_run_json_request
    local dry_run_json_blocks

    if [[ "$mode" == "run" ]]; then
        # Run mode: Save to workflow directory
        dry_run_json_request="$workflow_dir/dry-run-request.json"
        dry_run_json_blocks="$workflow_dir/dry-run-blocks.json"
    else
        # Task mode: Save to temp files with cleanup trap
        dry_run_json_request=$(mktemp -t dry-run-request.XXXXXX.json)
        dry_run_json_blocks=$(mktemp -t dry-run-blocks.XXXXXX.json)
        trap "rm -f '$dry_run_json_request' '$dry_run_json_blocks'" EXIT
    fi

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
    for block in "${IMAGE_BLOCKS[@]}"; do
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

    echo "Dry-run mode: JSON payload saved for inspection"
    echo "  API request (JSON):    $dry_run_json_request"
    echo "  Content blocks (JSON): $dry_run_json_blocks"
    echo ""

    # If count-tokens was also requested, prompt before opening
    if [[ "$COUNT_TOKENS" == true ]]; then
        read -p "Press Enter to inspect in editor (or Ctrl+C to cancel): " -r
        echo ""
    fi

    # Open in editor
    edit_files "$dry_run_json_request" "$dry_run_json_blocks"
    exit 0
}

# =============================================================================
# Prompt Building
# =============================================================================

# Build final prompts for API request
# Assembles JSON content blocks only (no XML strings)
#
# Args:
#   $1 - system_prompt_file: Path to system prompt file (for system-prompts block building)
#   $2 - project_root: Project root directory (or empty if no project)
#   $3 - task_source: Path to task file OR task string content
# Side effects:
#   Builds SYSTEM_BLOCKS array (system-prompts, project-description, current-date)
#   Builds TASK_BLOCK
build_prompts() {
    local system_file="$1"
    local project_root="$2"
    local task_source="$3"

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
    # Build User Message Blocks (for JSON API)
    # =============================================================================

    # Get task content
    local task_content
    if [[ -f "$task_source" ]]; then
        # Task is a file
        task_content=$(<"$task_source")
    else
        # Task is inline string
        task_content="$task_source"
    fi

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

# Helper: Build content block and track document index
# Arguments:
#   $1 - file: File path
#   $2 - category: "context" or "input"
#   $3 - enable_citations: "true" or "false"
#   $4 - doc_index_var: Name of variable holding current doc_index
#   $5 - meta_key (optional): Additional metadata key
#   $6 - meta_value (optional): Additional metadata value
#   $7 - project_root: Project root directory (for image caching)
#   $8 - workflow_dir: Workflow directory (for image caching)
# Side effects:
#   Appends block to CONTEXT_BLOCKS, INPUT_BLOCKS, or IMAGE_BLOCKS
#   Appends to DOCUMENT_INDEX_MAP (text files only, not images)
#   Increments doc_index variable (text files only)
build_and_track_document_block() {
    local file="$1"
    local category="$2"
    local enable_citations="$3"
    local doc_index_var="$4"
    local meta_key="${5:-}"
    local meta_value="${6:-}"
    local project_root="${7:-}"
    local workflow_dir="${8:-}"

    # Detect file type
    local file_type
    file_type=$(detect_file_type "$file")

    # Handle image files separately
    if [[ "$file_type" == "image" ]]; then
        echo "    Processing image: $(basename "$file")" >&2

        # Build image content block (Vision API)
        local block
        if ! block=$(build_image_content_block "$file" "$project_root" "$workflow_dir" 2>&1); then
            echo "    Warning: Failed to process image: $file" >&2
            return 1
        fi

        # Add to IMAGE_BLOCKS array (images are separate, not in context/input)
        IMAGE_BLOCKS+=("$block")

        # Images are NOT citable, so don't track in DOCUMENT_INDEX_MAP
        # Don't increment doc_index for images
        return 0
    fi

    # Handle text/document files (existing logic)
    local block
    if [[ -n "$meta_key" && -n "$meta_value" ]]; then
        block=$(build_content_block "$file" "$category" "$enable_citations" "$meta_key" "$meta_value")
    else
        block=$(build_content_block "$file" "$category" "$enable_citations")
    fi

    # Add to appropriate array
    if [[ "$category" == "context" ]]; then
        CONTEXT_BLOCKS+=("$block")
    elif [[ "$category" == "input" ]]; then
        INPUT_BLOCKS+=("$block")
    fi

    # Track document index (get current value via indirect reference)
    local current_index="${!doc_index_var}"
    local title
    title=$(extract_title_from_file "$file")

    DOCUMENT_INDEX_MAP+=("{\"index\": $current_index, \"source\": \"$file\", \"title\": \"$title\"}")

    # Increment index (use eval to modify the variable by name)
    eval "$doc_index_var=\$(( $current_index + 1 ))"
}

# Aggregate input and context files from various sources based on mode
# Builds JSON content blocks for API
# Aggregation order (stable → volatile): context → dependencies → input → images
# Within each category: FILES → PATTERN → CLI
# Run mode: config patterns/files + CLI patterns/files
# Task mode: CLI patterns/files only
#
# Args:
#   $1 - mode: "run" or "task"
#   $2 - project_root: Project root (for run mode, empty for task standalone)
#   $3 - workflow_dir: Workflow directory (for cache), or temp dir for task mode
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
#   Populates CONTEXT_BLOCKS, DEPENDENCY_BLOCKS, INPUT_BLOCKS, IMAGE_BLOCKS arrays
#   Populates DOCUMENT_INDEX_MAP array (for citations, text files only)
aggregate_context() {
    local mode="$1"
    local project_root="$2"
    local workflow_dir="$3"

    echo "Building input documents and context..."

    # Initialize document index tracking (for citations)
    # Only document blocks (context and input) get indices
    DOCUMENT_INDEX_MAP=()
    local doc_index=0

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

            # Build and track document block
            build_and_track_document_block "$resolved_file" "context" "$ENABLE_CITATIONS" "doc_index" "" "" "$project_root" "$workflow_dir"
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
                # Build and track document block
                build_and_track_document_block "$abs_file" "context" "$ENABLE_CITATIONS" "doc_index" "" "" "$project_root" "$workflow_dir"
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

            # Build and track document block
            build_and_track_document_block "$file" "context" "$ENABLE_CITATIONS" "doc_index" "" "" "$project_root" "$workflow_dir"
        done
    fi

    # Both modes: Add files from CLI --context-pattern (PWD-relative, most volatile)
    if [[ -n "$CLI_CONTEXT_PATTERN" ]]; then
        echo "  Adding context from CLI pattern: $CLI_CONTEXT_PATTERN"
        local pattern_files
        pattern_files=($(eval "echo $CLI_CONTEXT_PATTERN"))

        for file in "${pattern_files[@]}"; do
            if [[ -f "$file" ]]; then
                # Build and track document block
                build_and_track_document_block "$file" "context" "$ENABLE_CITATIONS" "doc_index" "" "" "$project_root" "$workflow_dir"
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

            # Build JSON content block (text type, no citations for dependencies)
            local block
            block=$(build_content_block "$dep_file" "dependency" "false" "workflow" "$dep")
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

            # Build and track document block
            build_and_track_document_block "$resolved_file" "input" "$ENABLE_CITATIONS" "doc_index" "" "" "$project_root" "$workflow_dir"
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
                # Build and track document block
                build_and_track_document_block "$abs_file" "input" "$ENABLE_CITATIONS" "doc_index" "" "" "$project_root" "$workflow_dir"
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

            # Build and track document block
            build_and_track_document_block "$file" "input" "$ENABLE_CITATIONS" "doc_index" "" "" "$project_root" "$workflow_dir"
        done
    fi

    # Both modes: Add files from CLI --input-pattern (PWD-relative, most volatile)
    if [[ -n "$CLI_INPUT_PATTERN" ]]; then
        echo "  Adding input documents from CLI pattern: $CLI_INPUT_PATTERN"
        local pattern_files
        pattern_files=($(eval "echo $CLI_INPUT_PATTERN"))

        for file in "${pattern_files[@]}"; do
            if [[ -f "$file" ]]; then
                # Build and track document block
                build_and_track_document_block "$file" "input" "$ENABLE_CITATIONS" "doc_index" "" "" "$project_root" "$workflow_dir"
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
    [[ ${#INPUT_BLOCKS[@]} -gt 0 || ${#IMAGE_BLOCKS[@]} -gt 0 ]] && has_input=true
    [[ ${#CONTEXT_BLOCKS[@]} -gt 0 || ${#DEPENDENCY_BLOCKS[@]} -gt 0 ]] && has_context=true

    if [[ "$has_input" == false && "$has_context" == false ]]; then
        echo "Warning: No input documents or context provided. Task will run without supporting materials."
        if [[ "$mode" == "run" ]]; then
            echo "  Use --input-file, --input-pattern, --context-file, --context-pattern, or --depends-on"
        else
            echo "  Use --input-file, --input-pattern, --context-file, or --context-pattern"
        fi
    fi

    # Report image count if any
    if [[ ${#IMAGE_BLOCKS[@]} -gt 0 ]]; then
        echo "Included ${#IMAGE_BLOCKS[@]} image(s) in request"
    fi

    # Save document index map for citations processing
    # This maps API document indices to source file paths and titles
    if [[ ${#DOCUMENT_INDEX_MAP[@]} -gt 0 ]]; then
        printf '%s\n' "${DOCUMENT_INDEX_MAP[@]}" | jq -s '.' > "$DOCUMENT_MAP_FILE" 2>/dev/null || true
    fi
}

# =============================================================================
# API Request Execution
# =============================================================================

# Execute API request with mode-specific output handling
# Validates API key and executes streaming or single-shot request
#
# Args:
#   $1 - mode: "run" or "task"
#   $2 - output_file: Path to output file
#   $3 - output_file_path: Explicit output file path (task mode, optional)
# Requires:
#   SYSTEM_BLOCKS: Array of system content blocks
#   CONTEXT_BLOCKS: Array of context content blocks
#   DEPENDENCY_BLOCKS: Array of dependency content blocks
#   INPUT_BLOCKS: Array of input document content blocks
#   IMAGE_BLOCKS: Array of image content blocks (Vision API)
#   TASK_BLOCK: Task content block
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

    # Add image blocks (if any)
    for block in "${IMAGE_BLOCKS[@]}"; do
        all_user_blocks+=("$block")
    done

    # Add task block (always present)
    all_user_blocks+=("$TASK_BLOCK")

    # Convert to JSON array
    user_blocks_json=$(printf '%s\n' "${all_user_blocks[@]}" | jq -s '.')

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
            output_file="$output_file" \
            enable_citations="$ENABLE_CITATIONS" \
            output_format="$OUTPUT_FORMAT" \
            doc_map_file="$DOCUMENT_MAP_FILE" || exit 1
    else
        anthropic_execute_single \
            api_key="$ANTHROPIC_API_KEY" \
            model="$MODEL" \
            max_tokens="$MAX_TOKENS" \
            temperature="$TEMPERATURE" \
            system_blocks_file="$temp_system" \
            user_blocks_file="$temp_user" \
            output_file="$output_file" \
            enable_citations="$ENABLE_CITATIONS" \
            output_format="$OUTPUT_FORMAT" \
            doc_map_file="$DOCUMENT_MAP_FILE" || exit 1

        # Task mode: Display output to stdout if no explicit output file
        if [[ "$mode" == "task" && -z "$output_file_path" ]]; then
            cat "$output_file"
        fi
    fi

    # =============================================================================
    # Save JSON Files for Reference (run mode only)
    # =============================================================================

    if [[ "$mode" == "run" ]]; then
        # Save system blocks
        echo "$system_blocks_json" | jq '.' > "$SYSTEM_BLOCKS_FILE" 2>/dev/null || true

        # Save user blocks
        echo "$user_blocks_json" | jq '.' > "$USER_BLOCKS_FILE" 2>/dev/null || true

        # Save complete request payload
        jq -n \
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
                messages: [{role: "user", content: $user_content}]
            }' > "$REQUEST_JSON_FILE" 2>/dev/null || true
    fi

    # Cleanup temp files
    rm -f "$temp_system" "$temp_user"
}
