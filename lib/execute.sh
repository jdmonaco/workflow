# =============================================================================
# Workflow Execution Functions
# =============================================================================
# Shared execution logic for run and task modes.
# Houses common functions for system prompt building, context aggregation,
# token estimation, dry-run handling, and API request execution.
# This file is sourced by wireflow.sh and lib/task.sh.
# =============================================================================

# =============================================================================
# Shared Option Parsing
# =============================================================================

# Parse common execution options shared between run and task modes
# Arguments:
#   $1 - option: The option flag being parsed
#   $2+ - remaining arguments
# Returns:
#   Sets PARSE_CONSUMED to number of args consumed (0 = unknown option)
#   Sets global config variables (MODEL, TEMPERATURE, etc.)
# Usage:
#   parse_common_option "$1" "${@:2}"
#   if [[ $PARSE_CONSUMED -gt 0 ]]; then
#       shift $PARSE_CONSUMED
#   fi
PARSE_CONSUMED=0

parse_common_option() {
    local opt="$1"
    shift
    PARSE_CONSUMED=0

    case "$opt" in
        --profile)
            [[ $# -eq 0 ]] && { echo "Error: --profile requires argument" >&2; return 1; }
            PROFILE="$1"
            CONFIG_SOURCE_MAP[PROFILE]="cli"
            PARSE_CONSUMED=2
            ;;
        --model|-m)
            [[ $# -eq 0 ]] && { echo "Error: --model requires argument" >&2; return 1; }
            MODEL="$1"
            CONFIG_SOURCE_MAP[MODEL]="cli"
            PARSE_CONSUMED=2
            ;;
        --enable-thinking)
            ENABLE_THINKING=true
            CONFIG_SOURCE_MAP[ENABLE_THINKING]="cli"
            PARSE_CONSUMED=1
            ;;
        --disable-thinking)
            ENABLE_THINKING=false
            CONFIG_SOURCE_MAP[ENABLE_THINKING]="cli"
            PARSE_CONSUMED=1
            ;;
        --thinking-budget)
            [[ $# -eq 0 ]] && { echo "Error: --thinking-budget requires argument" >&2; return 1; }
            THINKING_BUDGET="$1"
            CONFIG_SOURCE_MAP[THINKING_BUDGET]="cli"
            PARSE_CONSUMED=2
            ;;
        --effort)
            [[ $# -eq 0 ]] && { echo "Error: --effort requires argument" >&2; return 1; }
            EFFORT="$1"
            CONFIG_SOURCE_MAP[EFFORT]="cli"
            PARSE_CONSUMED=2
            ;;
        --temperature|-t)
            [[ $# -eq 0 ]] && { echo "Error: --temperature requires argument" >&2; return 1; }
            TEMPERATURE="$1"
            CONFIG_SOURCE_MAP[TEMPERATURE]="cli"
            PARSE_CONSUMED=2
            ;;
        --max-tokens)
            [[ $# -eq 0 ]] && { echo "Error: --max-tokens requires argument" >&2; return 1; }
            MAX_TOKENS="$1"
            CONFIG_SOURCE_MAP[MAX_TOKENS]="cli"
            PARSE_CONSUMED=2
            ;;
        --system|-p)
            [[ $# -eq 0 ]] && { echo "Error: --system requires argument" >&2; return 1; }
            IFS=',' read -ra SYSTEM_PROMPTS <<< "$1"
            CONFIG_SOURCE_MAP[SYSTEM_PROMPTS]="cli"
            PARSE_CONSUMED=2
            ;;
        --format|-f)
            [[ $# -eq 0 ]] && { echo "Error: --format requires argument" >&2; return 1; }
            OUTPUT_FORMAT="$1"
            CONFIG_SOURCE_MAP[OUTPUT_FORMAT]="cli"
            PARSE_CONSUMED=2
            ;;
        --enable-citations)
            ENABLE_CITATIONS=true
            CONFIG_SOURCE_MAP[ENABLE_CITATIONS]="cli"
            PARSE_CONSUMED=1
            ;;
        --disable-citations)
            ENABLE_CITATIONS=false
            CONFIG_SOURCE_MAP[ENABLE_CITATIONS]="cli"
            PARSE_CONSUMED=1
            ;;
        *)
            # Unknown option - caller handles
            PARSE_CONSUMED=0
            ;;
    esac
    return 0
}

# =============================================================================
# System Prompt Building
# =============================================================================

# Track loaded dependencies to prevent duplicates
declare -A LOADED_SYSTEM_DEPS
declare -A LOADED_TASK_DEPS

# Find component file with fallback to builtin
# Args:
#   $1 - component_path: Path relative to PREFIX (e.g., "core/user")
#   $2 - prefix_var: Variable name for user prefix (e.g., "WIREFLOW_PROMPT_PREFIX")
#   $3 - builtin_var: Variable name for builtin prefix
# Returns:
#   0 on success (prints path), 1 on not found
find_component_file() {
    local component_path="$1"
    local prefix_var="$2"
    local builtin_var="$3"

    local user_prefix="${!prefix_var}"
    local builtin_prefix="${!builtin_var}"
    local file_path="${user_prefix}/${component_path}.txt"

    # Try user/project location first
    if [[ -f "$file_path" ]]; then
        echo "$file_path"
        return 0
    fi

    # Try builtin fallback if different
    if [[ "$user_prefix" != "$builtin_prefix" ]]; then
        file_path="${builtin_prefix}/${component_path}.txt"
        if [[ -f "$file_path" ]]; then
            echo "$file_path"
            return 0
        fi
    fi

    return 1
}

# Extract dependencies from component file metadata
# Args:
#   $1 - file: Path to component file
# Returns:
#   Prints dependency paths (one per line)
extract_dependencies() {
    local file="$1"

    # Extract content between <dependencies> tags
    # Look for lines like: <dependency>path/to/component</dependency>
    awk '
        /<dependencies>/,/<\/dependencies>/ {
            if ($0 ~ /<dependency>.*<\/dependency>/) {
                gsub(/<dependency>/, "", $0)
                gsub(/<\/dependency>/, "", $0)
                gsub(/^[[:space:]]+/, "", $0)
                gsub(/[[:space:]]+$/, "", $0)
                if ($0 != "") print $0
            }
        }
    ' "$file"
}

# Resolve system component dependencies recursively
# Args:
#   $1 - component_path: Path to component (e.g., "domains/neuro-ai")
# Returns:
#   Prints ordered list of dependencies (excluding already loaded)
# Side effect:
#   Updates LOADED_SYSTEM_DEPS
resolve_system_dependencies() {
    local component_path="$1"
    local -a dep_chain=()

    # Ensure LOADED_SYSTEM_DEPS is an associative array (needed for test contexts)
    if ! declare -p LOADED_SYSTEM_DEPS 2>/dev/null | grep -q '^declare -A'; then
        declare -gA LOADED_SYSTEM_DEPS=()
    fi

    # Skip if already loaded (or currently being processed - prevents circular deps)
    if [[ -n "${LOADED_SYSTEM_DEPS[$component_path]}" ]]; then
        return 0
    fi

    # Mark as being processed BEFORE recursing to prevent circular dependency loops
    LOADED_SYSTEM_DEPS[$component_path]=1

    # Find the component file
    local file=$(find_component_file "$component_path" \
                                     "WIREFLOW_PROMPT_PREFIX" \
                                     "BUILTIN_WIREFLOW_PROMPT_PREFIX")

    if [[ -z "$file" ]]; then
        echo "Warning: Component not found: $component_path" >&2
        return 1
    fi

    # Extract its dependencies
    local -a deps
    mapfile -t deps < <(extract_dependencies "$file")

    # Recursively resolve each dependency
    for dep in "${deps[@]}"; do
        if [[ -n "$dep" ]]; then
            # Check if already loaded before recursive call
            if [[ -z "${LOADED_SYSTEM_DEPS[$dep]}" ]]; then
                # Get transitive dependencies first
                local -a transitive_deps
                mapfile -t transitive_deps < <(resolve_system_dependencies "$dep")

                # Add transitive dependencies to chain
                for trans_dep in "${transitive_deps[@]}"; do
                    if [[ -n "$trans_dep" ]]; then
                        dep_chain+=("$trans_dep")
                    fi
                done

                # Add the direct dependency itself
                dep_chain+=("$dep")
            fi
        fi
    done

    # Output the dependency chain
    printf '%s\n' "${dep_chain[@]}"
}

# Resolve task component dependencies recursively
# Args:
#   $1 - task_path: Path to task (e.g., "summaries/meeting")
# Returns:
#   Prints ordered list of dependencies (excluding already loaded)
# Side effect:
#   Updates LOADED_TASK_DEPS
resolve_task_dependencies() {
    local task_path="$1"
    local -a dep_chain=()

    # Ensure LOADED_TASK_DEPS is an associative array (needed for test contexts)
    if ! declare -p LOADED_TASK_DEPS 2>/dev/null | grep -q '^declare -A'; then
        declare -gA LOADED_TASK_DEPS=()
    fi

    # Skip if already loaded (or currently being processed - prevents circular deps)
    if [[ -n "${LOADED_TASK_DEPS[$task_path]}" ]]; then
        return 0
    fi

    # Mark as being processed BEFORE recursing to prevent circular dependency loops
    LOADED_TASK_DEPS[$task_path]=1

    # Find the task file
    local file=$(find_component_file "$task_path" \
                                     "WIREFLOW_TASK_PREFIX" \
                                     "BUILTIN_WIREFLOW_TASK_PREFIX")

    if [[ -z "$file" ]]; then
        echo "Warning: Task not found: $task_path" >&2
        return 1
    fi

    # Extract its dependencies
    local -a deps
    mapfile -t deps < <(extract_dependencies "$file")

    # Recursively resolve each dependency
    for dep in "${deps[@]}"; do
        if [[ -n "$dep" ]]; then
            # Only process if not already loaded
            if [[ -z "${LOADED_TASK_DEPS[$dep]}" ]]; then
                resolve_task_dependencies "$dep"
                dep_chain+=("$dep")
            fi
        fi
    done

    # Output the dependency chain
    printf '%s\n' "${dep_chain[@]}"
}

# Build system prompt from SYSTEM_PROMPTS configuration array
# Now with dependency resolution support
#
# Requires:
#   WIREFLOW_PROMPT_PREFIX: Directory containing *.txt prompt files
#   SYSTEM_PROMPTS: Array of prompt names (without .txt extension)
# Returns:
#   0 on success, 1 on error
# Side effects:
#   Writes composed prompt to system_prompt_file
#   May use cached version if rebuild fails
build_system_prompt() {
    if [[ -z "$WIREFLOW_PROMPT_PREFIX" ]]; then
        echo "Error: WIREFLOW_PROMPT_PREFIX environment variable is not set" >&2
        echo "Set WIREFLOW_PROMPT_PREFIX to the directory containing your *.txt prompt files" >&2
        return 1
    fi

    if [[ ! -d "$WIREFLOW_PROMPT_PREFIX" ]]; then
        echo "Error: System prompt directory not found: $WIREFLOW_PROMPT_PREFIX" >&2
        return 1
    fi

    # Reset dependency tracker for this build
    LOADED_SYSTEM_DEPS=()

    # FIRST: Add meta prompt block (required, auto-included, not cached)
    local meta_file=$(find_component_file "meta" \
                                          "WIREFLOW_PROMPT_PREFIX" \
                                          "BUILTIN_WIREFLOW_PROMPT_PREFIX")

    if [[ -n "$meta_file" && -f "$meta_file" ]]; then
        local meta_text
        meta_text=$(cat "$meta_file")
        local meta_block
        meta_block=$(jq -n \
            --arg type "text" \
            --arg text "$meta_text" \
            '{
                type: $type,
                text: $text
            }')
        SYSTEM_BLOCKS+=("$meta_block")
    fi

    # THEN: Build user-specified prompts with dependency resolution and cache control
    local all_components=()

    # For each component in SYSTEM_PROMPTS, resolve dependencies
    for component in "${SYSTEM_PROMPTS[@]}"; do
        # Get dependencies (recursively resolved)
        local -a deps
        mapfile -t deps < <(resolve_system_dependencies "$component")

        # Add dependencies to list (already deduped by tracker)
        for dep in "${deps[@]}"; do
            if [[ -n "$dep" ]]; then
                all_components+=("$dep")
            fi
        done

        # Add the component itself
        all_components+=("$component")
    done

    echo "Building system prompt from: meta (auto) ${all_components[*]}"

    # Build blocks from all components
    local processed_any="false"
    for component_path in "${all_components[@]}"; do
        local file=$(find_component_file "$component_path" \
                                        "WIREFLOW_PROMPT_PREFIX" \
                                        "BUILTIN_WIREFLOW_PROMPT_PREFIX")

        if [[ -z "$file" || ! -f "$file" ]]; then
            echo "Error: System prompt component not found: ${component_path}" >&2
            continue
        fi

        # Load component content
        local component_text
        component_text=$(cat "$file")

        # Build JSON content block
        local component_block
        component_block=$(jq -n \
            --arg type "text" \
            --arg text "$component_text" \
            '{
                type: $type,
                text: $text
            }')

        # Add to SYSTEM_BLOCKS array
        SYSTEM_BLOCKS+=("$component_block")
        processed_any="true"
    done

    # If blocks were added, make the last block a cache_control breakpoint
    if [[ "$processed_any" == "true" ]]; then
        local last_idx=$((${#SYSTEM_BLOCKS[@]} - 1))
        SYSTEM_BLOCKS[$last_idx]=$(echo "${SYSTEM_BLOCKS[$last_idx]}" | jq '. + {cache_control: {type: "ephemeral"}}')
        return 0
    else
        return 1
    fi
}

# Build project description content blocks (with cache_control)
# Returns:
#   success status - if project description blocks were created
# Side effects:
#   Appends blocks to SYSTEM_BLOCKS array if successful
build_project_description_blocks() {
    local project_root="${1:-$PROJECT_ROOT}"

    # Find all project roots from current location
    local -a roots_array
    mapfile -t roots_array <<< "$(find_ancestor_projects)" || return 1 

    # Add nested project descriptions as JSON content blocks
    local processed_any=false
    for root in "${roots_array[@]}"; do
        local proj_file="$root/.workflow/project.txt"
        local project_desc
        local tag_name

        # Skip if project file doesn't exist or is empty
        [[ ! -f "$proj_file" || ! -s "$proj_file" ]] && continue

        # Load and tag project description file
        tag_name=$(sanitize "$(basename "$root")")
        project_desc="<$tag_name>"$'\n'"$(cat "$proj_file")"$'\n'"</$tag_name>"

        # Build JSON content block with cache_control
        local project_desc_block
        project_desc_block=$(jq -n \
            --arg type "text" \
            --arg text "$project_desc" \
            '{
                type: $type,
                text: $text,
            }')

        # Add to SYSTEM_BLOCKS array
        SYSTEM_BLOCKS+=("$project_desc_block")
        processed_any=true
    done

    # If blocks were added, make the last block a cache_control breakpoint
    if [[ "$processed_any" == "true" ]]; then
        local last_idx=$((${#SYSTEM_BLOCKS[@]} - 1))
        SYSTEM_BLOCKS[$last_idx]=$(echo "${SYSTEM_BLOCKS[$last_idx]}" | jq '. + {cache_control: {type: "ephemeral"}}')
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

    # PDF tokens (from CONTEXT_PDF_BLOCKS and INPUT_PDF_BLOCKS)
    # Conservative estimate: ~2000 tokens per page
    # Use pdfinfo if available to get actual page count, otherwise estimate from file size
    local pdftc=0
    local pdf_count=$((${#CONTEXT_PDF_BLOCKS[@]} + ${#INPUT_PDF_BLOCKS[@]}))
    if [[ $pdf_count -gt 0 ]]; then
        echo "Estimated PDF tokens: ~2000 tokens per page (conservative)"
        echo "  Note: Use pdfinfo (poppler-utils) for accurate page counts"
    fi

    # Context tokens (from CONTEXT_BLOCKS, DEPENDENCY_BLOCKS, and CONTEXT_PDF_BLOCKS)
    local context_chars=0
    for block in "${CONTEXT_BLOCKS[@]}"; do
        context_chars=$((context_chars + $(echo "$block" | wc -c)))
    done
    for block in "${DEPENDENCY_BLOCKS[@]}"; do
        context_chars=$((context_chars + $(echo "$block" | wc -c)))
    done
    # Add PDF blocks to context count
    for block in "${CONTEXT_PDF_BLOCKS[@]}"; do
        context_chars=$((context_chars + $(echo "$block" | wc -c)))
        pdftc=$((pdftc + 2000))  # Rough estimate, will be refined by API
    done
    local contexttc=$((context_chars / 4))
    if [[ $contexttc -gt 0 ]]; then
        echo "Estimated context tokens: $contexttc"
    fi

    # Input tokens (from INPUT_BLOCKS and INPUT_PDF_BLOCKS)
    local input_chars=0
    for block in "${INPUT_BLOCKS[@]}"; do
        input_chars=$((input_chars + $(echo "$block" | wc -c)))
    done
    # Add PDF blocks to input count
    for block in "${INPUT_PDF_BLOCKS[@]}"; do
        input_chars=$((input_chars + $(echo "$block" | wc -c)))
        pdftc=$((pdftc + 2000))  # Rough estimate, will be refined by API
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
    local total_tokens=$((systc + tasktc + inputtc + contexttc + pdftc + imagetc))
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
            # Optimized order: PDFs first, then text, then images, then task
            for block in "${CONTEXT_PDF_BLOCKS[@]}"; do
                all_user_blocks+=("$block")
            done
            for block in "${INPUT_PDF_BLOCKS[@]}"; do
                all_user_blocks+=("$block")
            done
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
            # Add task dependency blocks for token counting
            for block in "${TASK_BLOCKS[@]}"; do
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
    # Add task dependency blocks for dry run
    for block in "${TASK_BLOCKS[@]}"; do
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

    # Open in editor (skip in test mode)
    if [[ "${WIREFLOW_TEST_MODE:-}" != "true" ]]; then
        edit_files "$dry_run_json_request" "$dry_run_json_blocks"
    else
        echo "=== DRY RUN MODE ==="
    fi
    exit 0
}

# =============================================================================
# Prompt Building
# =============================================================================

# Build final prompts for API request
# Assembles JSON content blocks only (no XML strings)
#
# Args:
#   $1 - project_root: Project root directory (or empty if no project)
#   $2 - task_source: Path to task file OR task string content
# Side effects:
#   Builds SYSTEM_BLOCKS array (system-prompts, project-description, current-date)
#   Builds TASK_BLOCK
build_prompts() {
    local project_root="$1"
    local task_source="$2"

    # =============================================================================
    # Build System Message Blocks (for JSON API)
    # =============================================================================

    # Note: System prompts block already added to SYSTEM_BLOCKS by build_system_prompt()

    # Add project description block (if exists)
    if [[ -n "$project_root" ]]; then
        build_project_description_blocks "$project_root" || true
    fi

    # Add current date block (always)
    build_current_date_block

    # =============================================================================
    # Build User Message Blocks (for JSON API)
    # =============================================================================

    # Reset task dependency tracker
    LOADED_TASK_DEPS=()
    local -a TASK_BLOCKS=()

    # Process task with dependency resolution
    if [[ -f "$task_source" ]]; then
        # Task is a file - extract its name from metadata or path
        local task_name=""

        # Try to extract task name from metadata (use sed for portability)
        task_name=$(sed -n 's/.*<name>\([^<]*\)<\/name>.*/\1/p' "$task_source" 2>/dev/null | head -1) || true

        # If task has dependencies in its metadata, resolve them
        local -a task_deps
        mapfile -t task_deps < <(extract_dependencies "$task_source")

        # Resolve dependencies and build blocks for each
        for dep in "${task_deps[@]}"; do
            if [[ -n "$dep" ]]; then
                # Get transitive dependencies
                local -a transitive_deps
                mapfile -t transitive_deps < <(resolve_task_dependencies "$dep")

                # Add all transitive dependencies first
                for trans_dep in "${transitive_deps[@]}"; do
                    if [[ -n "$trans_dep" ]]; then
                        local dep_file=$(find_component_file "$trans_dep" \
                                                            "WIREFLOW_TASK_PREFIX" \
                                                            "BUILTIN_WIREFLOW_TASK_PREFIX")
                        if [[ -n "$dep_file" && -f "$dep_file" ]]; then
                            local dep_content=$(<"$dep_file")
                            local dep_block=$(jq -n \
                                --arg type "text" \
                                --arg text "$dep_content" \
                                '{
                                    type: $type,
                                    text: $text
                                }')
                            TASK_BLOCKS+=("$dep_block")
                        fi
                    fi
                done

                # Add the direct dependency
                local dep_file=$(find_component_file "$dep" \
                                                    "WIREFLOW_TASK_PREFIX" \
                                                    "BUILTIN_WIREFLOW_TASK_PREFIX")
                if [[ -n "$dep_file" && -f "$dep_file" ]]; then
                    local dep_content=$(<"$dep_file")
                    local dep_block=$(jq -n \
                        --arg type "text" \
                        --arg text "$dep_content" \
                        '{
                            type: $type,
                            text: $text
                        }')
                    TASK_BLOCKS+=("$dep_block")
                fi
            fi
        done

        # Get the main task content
        local task_content=$(<"$task_source")
    else
        # Task is inline string
        local task_content="$task_source"
    fi

    # Build main task block (most volatile, no cache_control)
    TASK_BLOCK=$(jq -n \
        --arg type "text" \
        --arg text "$task_content" \
        '{
            type: $type,
            text: $text
        }')

    # Note: Complete user message will be assembled in API request from:
    # CONTEXT_BLOCKS + DEPENDENCY_BLOCKS + INPUT_BLOCKS + TASK_BLOCKS + TASK_BLOCK
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
        block=$(build_image_content_block "$file")
        if [[ -z "$block" ]]; then
            echo "    Warning: Failed to process image: $file" >&2
            return 1
        fi

        # Add to IMAGE_BLOCKS array (images are separate, not in context/input)
        IMAGE_BLOCKS+=("$block")

        # Images are NOT citable, so don't track in DOCUMENT_INDEX_MAP
        # Don't increment doc_index for images
        return 0
    fi

    # Handle PDF document files separately (optimized ordering: PDFs before text)
    if [[ "$file_type" == "document" ]]; then
        echo "    Processing PDF document: $(basename "$file")" >&2

        # Build document content block (no cache control yet, will be added at section boundary)
        local block
        block=$(build_document_content_block "$file" "false")
        if [[ -z "$block" ]]; then
            echo "    Warning: Failed to process PDF: $file" >&2
            return 1
        fi

        # Add to appropriate PDF array (PDFs processed before text documents)
        if [[ "$category" == "context" ]]; then
            CONTEXT_PDF_BLOCKS+=("$block")
        elif [[ "$category" == "input" ]]; then
            INPUT_PDF_BLOCKS+=("$block")
        fi

        # PDFs are citable - track in document index
        local current_index="${!doc_index_var}"
        local title
        title=$(extract_title_from_file "$file")

        DOCUMENT_INDEX_MAP+=("{\"index\": $current_index, \"source\": \"$file\", \"title\": \"$title\"}")

        # Increment index
        eval "$doc_index_var=\$(( $current_index + 1 ))"

        return 0
    fi

    # Handle Microsoft Office files (convert to PDF then process as document)
    if [[ "$file_type" == "office" ]]; then
        echo "    Processing Office file: $(basename "$file")" >&2

        # Check if soffice is available
        if ! check_soffice_available; then
            echo "    Warning: LibreOffice (soffice) not available, skipping Office file: $file" >&2
            echo "    Install LibreOffice to enable Office file support (.docx, .pptx)" >&2
            return 0  # Graceful skip
        fi

        # Get absolute path for conversion
        local abs_file
        abs_file=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")

        # Convert to PDF (uses global CACHE_DIR for shared project cache)
        local cached_pdf
        cached_pdf=$(convert_office_to_pdf "$abs_file")
        if [[ $? -ne 0 || -z "$cached_pdf" ]]; then
            echo "    Warning: Failed to convert Office file to PDF: $file" >&2
            return 1
        fi

        # Build document content block from cached PDF
        local block
        block=$(build_document_content_block "$cached_pdf" "false")
        if [[ -z "$block" ]]; then
            echo "    Warning: Failed to process converted PDF: $cached_pdf" >&2
            return 1
        fi

        # Add to appropriate PDF array (Office files follow PDF ordering)
        if [[ "$category" == "context" ]]; then
            CONTEXT_PDF_BLOCKS+=("$block")
        elif [[ "$category" == "input" ]]; then
            INPUT_PDF_BLOCKS+=("$block")
        fi

        # Office files are citable - track with ORIGINAL filename (not cached PDF)
        local current_index="${!doc_index_var}"
        local title
        title=$(extract_title_from_file "$file")

        DOCUMENT_INDEX_MAP+=("{\"index\": $current_index, \"source\": \"$file\", \"title\": \"$title\"}")

        # Increment index
        eval "$doc_index_var=\$(( $current_index + 1 ))"

        return 0
    fi

    # Handle text files
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

    # Process any Obsidian embed files discovered during markdown preprocessing
    if [[ ${#OBSIDIAN_EMBED_FILES[@]} -gt 0 ]]; then
        for i in "${!OBSIDIAN_EMBED_FILES[@]}"; do
            local embed_file="${OBSIDIAN_EMBED_FILES[$i]}"
            local embed_role="${OBSIDIAN_EMBED_ROLES[$i]}"

            echo "    Processing embedded file: $(basename "$embed_file")" >&2

            # Recursively process embed file (handles images, PDFs, etc.)
            build_and_track_document_block "$embed_file" "$embed_role" "$enable_citations" "$doc_index_var" "" "" "$project_root" "$workflow_dir"
        done

        # Clear arrays after processing
        OBSIDIAN_EMBED_FILES=()
        OBSIDIAN_EMBED_ROLES=()
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
# Optimized ordering (per PDF API guidelines): PDFs before text for better processing
# Aggregation order (stable → volatile):
#   context PDFs → input PDFs → context text → dependencies → input text → images
# Within each category: FILES → PATTERN → CLI
# Run mode: config patterns/files + CLI patterns/files
# Task mode: CLI patterns/files only
#
# Args:
#   $1 - mode: "run" or "task"
#   $2 - project_root: Project root (for run mode, empty for task standalone)
#   $3 - workflow_dir: Workflow directory (for cache), or temp dir for task mode
# Requires (run mode):
#   INPUT: Array of input file paths (project-relative, already glob-expanded)
#   DEPENDS_ON: Array of workflow dependencies
#   CONTEXT: Array of context file paths (project-relative, already glob-expanded)
# Requires (both modes):
#   CLI_INPUT_PATHS: Array of CLI input paths (files or directories)
#   CLI_CONTEXT_PATHS: Array of CLI context paths (files or directories)
# Side effects:
#   Populates CONTEXT_PDF_BLOCKS, INPUT_PDF_BLOCKS (PDFs, citable)
#   Populates CONTEXT_BLOCKS, DEPENDENCY_BLOCKS, INPUT_BLOCKS (text, citable)
#   Populates IMAGE_BLOCKS (images, NOT citable)
#   Populates DOCUMENT_INDEX_MAP array (for citations, all context/input docs)
aggregate_context() {
    local mode="$1"
    local project_root="$2"
    local workflow_dir="$3"

    echo "Building input documents and context..."

    # Helper function: expand path (file or directory) to individual files
    # For directories, non-recursively includes supported (non-binary) files
    expand_path_to_files() {
        local path="$1"
        if [[ -f "$path" ]]; then
            echo "$path"
        elif [[ -d "$path" ]]; then
            for file in "$path"/*; do
                [[ -f "$file" ]] && is_supported_file "$file" && echo "$file"
            done
        else
            echo "Warning: Path not found: $path" >&2
        fi
    }

    # Associative arrays for deduplication (keys are absolute paths)
    declare -A seen_input_files=()
    declare -A seen_context_files=()

    # Initialize content block arrays
    CONTEXT_PDF_BLOCKS=()
    INPUT_PDF_BLOCKS=()
    CONTEXT_BLOCKS=()
    DEPENDENCY_BLOCKS=()
    INPUT_BLOCKS=()
    IMAGE_BLOCKS=()

    # Initialize document index tracking (for citations)
    # Only document blocks (context and input) get indices
    DOCUMENT_INDEX_MAP=()
    local doc_index=0

    # =============================================================================
    # CONTEXT FILES AGGREGATION (most stable)
    # Order: Config CONTEXT → CLI_CONTEXT_PATHS
    # =============================================================================

    # Run mode: Add files from config CONTEXT array (project-relative, already glob-expanded)
    if [[ "$mode" == "run" && ${#CONTEXT[@]} -gt 0 ]]; then
        echo "  Adding context files from config..."
        for file in "${CONTEXT[@]}"; do
            local resolved_file="$project_root/$file"
            if [[ ! -f "$resolved_file" ]]; then
                echo "Warning: Context file not found: $file (resolved: $resolved_file)" >&2
                continue
            fi

            # Build and track document block
            build_and_track_document_block "$resolved_file" "context" "$ENABLE_CITATIONS" "doc_index" "" "" "$project_root" "$workflow_dir"
        done
    fi

    # Both modes: Add files/directories from CLI --context (PWD-relative)
    # Note: Context processing happens AFTER input processing below to check for duplicates
    # We defer this to after INPUT processing due to input-takes-precedence rule

    # Cache control for context blocks will be added by adaptive strategy below

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

        # Cache control for dependency blocks will be added by adaptive strategy below
    fi

    # =============================================================================
    # INPUT DOCUMENTS AGGREGATION (most volatile)
    # Order: Config INPUT → CLI_INPUT_PATHS
    # Note: CLI_INPUT_PATHS processed first to establish precedence over context
    # =============================================================================

    # Run mode: Add files from config INPUT array (project-relative, already glob-expanded)
    if [[ "$mode" == "run" && ${#INPUT[@]} -gt 0 ]]; then
        echo "  Adding input files from config..."
        for file in "${INPUT[@]}"; do
            local resolved_file="$project_root/$file"
            if [[ ! -f "$resolved_file" ]]; then
                echo "Warning: Input file not found: $file (resolved: $resolved_file)" >&2
                continue
            fi

            # Build and track document block
            build_and_track_document_block "$resolved_file" "input" "$ENABLE_CITATIONS" "doc_index" "" "" "$project_root" "$workflow_dir"
        done
    fi

    # Both modes: Add files/directories from CLI --input (PWD-relative, with deduplication)
    if [[ ${#CLI_INPUT_PATHS[@]} -gt 0 ]]; then
        echo "  Adding input from CLI..."
        for path in "${CLI_INPUT_PATHS[@]}"; do
            while IFS= read -r file; do
                [[ -z "$file" ]] && continue
                local abs_path
                abs_path=$(realpath "$file" 2>/dev/null) || abs_path="$file"
                # Skip if already seen (deduplication)
                if [[ -z "${seen_input_files[$abs_path]:-}" ]]; then
                    seen_input_files[$abs_path]=1
                    # Build and track document block
                    build_and_track_document_block "$file" "input" "$ENABLE_CITATIONS" "doc_index" "" "" "$project_root" "$workflow_dir"
                fi
            done < <(expand_path_to_files "$path")
        done
    fi

    # =============================================================================
    # CLI CONTEXT PROCESSING (deferred to here for input precedence)
    # =============================================================================

    # Both modes: Add files/directories from CLI --context (PWD-relative)
    # Input takes precedence: skip files already in input
    if [[ ${#CLI_CONTEXT_PATHS[@]} -gt 0 ]]; then
        echo "  Adding context from CLI..."
        for path in "${CLI_CONTEXT_PATHS[@]}"; do
            while IFS= read -r file; do
                [[ -z "$file" ]] && continue
                local abs_path
                abs_path=$(realpath "$file" 2>/dev/null) || abs_path="$file"
                # Skip if already in context OR if present in input files (input takes precedence)
                if [[ -z "${seen_context_files[$abs_path]:-}" && -z "${seen_input_files[$abs_path]:-}" ]]; then
                    seen_context_files[$abs_path]=1
                    # Build and track document block
                    build_and_track_document_block "$file" "context" "$ENABLE_CITATIONS" "doc_index" "" "" "$project_root" "$workflow_dir"
                fi
            done < <(expand_path_to_files "$path")
        done
    fi

    # =============================================================================
    # ADAPTIVE CACHE CONTROL STRATEGY
    # =============================================================================
    # Maximum 2 user breakpoints using adaptive strategy based on content mix
    # Strategy adapts to: PDFs + text + images combinations
    # System already uses 2 breakpoints (after prompts, after date)
    # User content gets maximum 2 adaptive breakpoints for total of 4

    # Determine what content types exist
    local has_pdfs=false
    local has_text_docs=false
    local has_images=false

    [[ ${#CONTEXT_PDF_BLOCKS[@]} -gt 0 || ${#INPUT_PDF_BLOCKS[@]} -gt 0 ]] && has_pdfs=true
    [[ ${#CONTEXT_BLOCKS[@]} -gt 0 || ${#DEPENDENCY_BLOCKS[@]} -gt 0 || ${#INPUT_BLOCKS[@]} -gt 0 ]] && has_text_docs=true
    [[ ${#IMAGE_BLOCKS[@]} -gt 0 ]] && has_images=true

    # Adaptive breakpoint placement
    if [[ "$has_pdfs" == true ]]; then
        # Scenario: PDFs exist
        # Breakpoint #1: After last PDF (INPUT_PDF preferred, fallback to CONTEXT_PDF)
        if [[ ${#INPUT_PDF_BLOCKS[@]} -gt 0 ]]; then
            local last_idx=$((${#INPUT_PDF_BLOCKS[@]} - 1))
            INPUT_PDF_BLOCKS[$last_idx]=$(echo "${INPUT_PDF_BLOCKS[$last_idx]}" | jq '. + {cache_control: {type: "ephemeral"}}')
        elif [[ ${#CONTEXT_PDF_BLOCKS[@]} -gt 0 ]]; then
            local last_idx=$((${#CONTEXT_PDF_BLOCKS[@]} - 1))
            CONTEXT_PDF_BLOCKS[$last_idx]=$(echo "${CONTEXT_PDF_BLOCKS[$last_idx]}" | jq '. + {cache_control: {type: "ephemeral"}}')
        fi

        # Breakpoint #2: After last image (if exist) or last text doc (if no images)
        if [[ "$has_images" == true ]]; then
            # Add breakpoint after last image
            local last_idx=$((${#IMAGE_BLOCKS[@]} - 1))
            IMAGE_BLOCKS[$last_idx]=$(echo "${IMAGE_BLOCKS[$last_idx]}" | jq '. + {cache_control: {type: "ephemeral"}}')
        elif [[ "$has_text_docs" == true ]]; then
            # No images, add breakpoint after last text doc (INPUT preferred)
            if [[ ${#INPUT_BLOCKS[@]} -gt 0 ]]; then
                local last_idx=$((${#INPUT_BLOCKS[@]} - 1))
                INPUT_BLOCKS[$last_idx]=$(echo "${INPUT_BLOCKS[$last_idx]}" | jq '. + {cache_control: {type: "ephemeral"}}')
            elif [[ ${#DEPENDENCY_BLOCKS[@]} -gt 0 ]]; then
                local last_idx=$((${#DEPENDENCY_BLOCKS[@]} - 1))
                DEPENDENCY_BLOCKS[$last_idx]=$(echo "${DEPENDENCY_BLOCKS[$last_idx]}" | jq '. + {cache_control: {type: "ephemeral"}}')
            elif [[ ${#CONTEXT_BLOCKS[@]} -gt 0 ]]; then
                local last_idx=$((${#CONTEXT_BLOCKS[@]} - 1))
                CONTEXT_BLOCKS[$last_idx]=$(echo "${CONTEXT_BLOCKS[$last_idx]}" | jq '. + {cache_control: {type: "ephemeral"}}')
            fi
        fi
        # Note: If only PDFs and task (no text, no images), only 1 user breakpoint (correct)

    elif [[ "$has_text_docs" == true ]]; then
        # Scenario: No PDFs, have text docs
        # Breakpoint #1: After last text doc (INPUT preferred, before images if they exist)
        if [[ ${#INPUT_BLOCKS[@]} -gt 0 ]]; then
            local last_idx=$((${#INPUT_BLOCKS[@]} - 1))
            INPUT_BLOCKS[$last_idx]=$(echo "${INPUT_BLOCKS[$last_idx]}" | jq '. + {cache_control: {type: "ephemeral"}}')
        elif [[ ${#DEPENDENCY_BLOCKS[@]} -gt 0 ]]; then
            local last_idx=$((${#DEPENDENCY_BLOCKS[@]} - 1))
            DEPENDENCY_BLOCKS[$last_idx]=$(echo "${DEPENDENCY_BLOCKS[$last_idx]}" | jq '. + {cache_control: {type: "ephemeral"}}')
        elif [[ ${#CONTEXT_BLOCKS[@]} -gt 0 ]]; then
            local last_idx=$((${#CONTEXT_BLOCKS[@]} - 1))
            CONTEXT_BLOCKS[$last_idx]=$(echo "${CONTEXT_BLOCKS[$last_idx]}" | jq '. + {cache_control: {type: "ephemeral"}}')
        fi

        # Breakpoint #2: After last image (if images exist)
        if [[ "$has_images" == true ]]; then
            local last_idx=$((${#IMAGE_BLOCKS[@]} - 1))
            IMAGE_BLOCKS[$last_idx]=$(echo "${IMAGE_BLOCKS[$last_idx]}" | jq '. + {cache_control: {type: "ephemeral"}}')
        fi
        # Note: If only text docs and task (no images), only 1 user breakpoint (correct)

    elif [[ "$has_images" == true ]]; then
        # Scenario: Only images (no PDFs, no text docs)
        # Breakpoint #1: After last image
        local last_idx=$((${#IMAGE_BLOCKS[@]} - 1))
        IMAGE_BLOCKS[$last_idx]=$(echo "${IMAGE_BLOCKS[$last_idx]}" | jq '. + {cache_control: {type: "ephemeral"}}')
        # Note: If only images and task, only 1 user breakpoint (correct)
    fi

    # Note: If only task (no content at all), no user breakpoints added (correct behavior)

    # =============================================================================
    # Summary
    # =============================================================================

    # Check if any input or context was provided
    local has_input=false
    local has_context=false
    [[ ${#INPUT_BLOCKS[@]} -gt 0 || ${#INPUT_PDF_BLOCKS[@]} -gt 0 || ${#IMAGE_BLOCKS[@]} -gt 0 ]] && has_input=true
    [[ ${#CONTEXT_BLOCKS[@]} -gt 0 || ${#CONTEXT_PDF_BLOCKS[@]} -gt 0 || ${#DEPENDENCY_BLOCKS[@]} -gt 0 ]] && has_context=true

    if [[ "$has_input" == false && "$has_context" == false ]]; then
        echo "Warning: No input documents or context provided. Task will run without supporting materials."
        if [[ "$mode" == "run" ]]; then
            echo "  Use -in/--input, -cx/--context, or -d/--depends-on"
        else
            echo "  Use -in/--input or -cx/--context"
        fi
    fi

    # Report PDF count if any
    local total_pdfs=$((${#CONTEXT_PDF_BLOCKS[@]} + ${#INPUT_PDF_BLOCKS[@]}))
    if [[ $total_pdfs -gt 0 ]]; then
        echo "Included $total_pdfs PDF document(s) in request"
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

    # Assemble user content blocks array
    # Optimized order (per PDF API guidelines): PDFs → text → images → task
    # Order: context PDFs → input PDFs → context text → dependencies → input text → images → task
    local user_blocks_json
    local -a all_user_blocks=()

    # Add context PDF blocks first (if any) - optimized ordering
    for block in "${CONTEXT_PDF_BLOCKS[@]}"; do
        all_user_blocks+=("$block")
    done

    # Add input PDF blocks (if any) - optimized ordering
    for block in "${INPUT_PDF_BLOCKS[@]}"; do
        all_user_blocks+=("$block")
    done

    # Add context text blocks (if any)
    for block in "${CONTEXT_BLOCKS[@]}"; do
        all_user_blocks+=("$block")
    done

    # Add dependency blocks (if any)
    for block in "${DEPENDENCY_BLOCKS[@]}"; do
        all_user_blocks+=("$block")
    done

    # Add input text blocks (if any)
    for block in "${INPUT_BLOCKS[@]}"; do
        all_user_blocks+=("$block")
    done

    # Add image blocks (if any)
    for block in "${IMAGE_BLOCKS[@]}"; do
        all_user_blocks+=("$block")
    done

    # Add task dependency blocks (if any)
    if [[ ${#TASK_BLOCKS[@]} -gt 0 ]]; then
        # Add all but the last task dependency block
        local last_task_idx=$((${#TASK_BLOCKS[@]} - 1))
        for ((i = 0; i < last_task_idx; i++)); do
            all_user_blocks+=("${TASK_BLOCKS[$i]}")
        done

        # Add the last task dependency block with cache_control
        local last_task_block="${TASK_BLOCKS[$last_task_idx]}"
        last_task_block=$(echo "$last_task_block" | jq '. + {cache_control: {type: "ephemeral"}}')
        all_user_blocks+=("$last_task_block")
    fi

    # Add main task block (always present, never cached)
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

    # Resolve effective model from profile system
    local effective_model
    effective_model=$(resolve_model)

    # Validate API configuration for model compatibility
    validate_api_config "$effective_model" "$ENABLE_THINKING" "$EFFORT"

    # Pass JSON via temp files to avoid parameter parsing issues
    local temp_system=$(mktemp)
    local temp_user=$(mktemp)
    echo "$system_blocks_json" > "$temp_system"
    echo "$user_blocks_json" > "$temp_user"

    # Execute API request (stream or single mode)
    if [[ "$STREAM_MODE" == true ]]; then
        anthropic_execute_stream \
            api_key="$ANTHROPIC_API_KEY" \
            model="$effective_model" \
            max_tokens="$MAX_TOKENS" \
            temperature="$TEMPERATURE" \
            system_blocks_file="$temp_system" \
            user_blocks_file="$temp_user" \
            output_file="$output_file" \
            enable_citations="$ENABLE_CITATIONS" \
            output_format="$OUTPUT_FORMAT" \
            doc_map_file="$DOCUMENT_MAP_FILE" \
            enable_thinking="$ENABLE_THINKING" \
            thinking_budget="$THINKING_BUDGET" \
            effort="$EFFORT" || exit 1
    else
        anthropic_execute_single \
            api_key="$ANTHROPIC_API_KEY" \
            model="$effective_model" \
            max_tokens="$MAX_TOKENS" \
            temperature="$TEMPERATURE" \
            system_blocks_file="$temp_system" \
            user_blocks_file="$temp_user" \
            output_file="$output_file" \
            enable_citations="$ENABLE_CITATIONS" \
            output_format="$OUTPUT_FORMAT" \
            doc_map_file="$DOCUMENT_MAP_FILE" \
            enable_thinking="$ENABLE_THINKING" \
            thinking_budget="$THINKING_BUDGET" \
            effort="$EFFORT" || exit 1

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

        # Save complete request payload (includes resolved model and all params)
        local request_json
        request_json=$(jq -n \
            --arg model "$effective_model" \
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
            }')

        # Add thinking config if enabled
        if [[ "$ENABLE_THINKING" == "true" ]]; then
            request_json=$(echo "$request_json" | jq \
                --argjson budget "$THINKING_BUDGET" \
                '. + {thinking: {type: "enabled", budget_tokens: $budget}}')
        fi

        # Add effort config if not high (high = API default)
        if [[ "$EFFORT" != "high" ]]; then
            request_json=$(echo "$request_json" | jq \
                --arg effort "$EFFORT" \
                '. + {output_config: {effort: $effort}}')
        fi

        echo "$request_json" > "$REQUEST_JSON_FILE" 2>/dev/null || true

        # Write execution log for cache validation and dependency tracking
        write_execution_log \
            "$WORKFLOW_NAME" \
            "$workflow_dir" \
            "$output_file" \
            "$project_root"
    fi

    # Cleanup temp files
    rm -f "$temp_system" "$temp_user"
}
