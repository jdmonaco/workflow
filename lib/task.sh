#!/usr/bin/env bash

# =============================================================================
# Task Mode - Lightweight One-Off Task Execution
# =============================================================================
# Execute tasks without creating workflow directories.
# Supports named tasks from files or inline task specifications.
# This file is sourced by workflow.sh when task mode is active.
# =============================================================================

# =============================================================================
# Parse Task Mode Arguments
# =============================================================================

TASK_NAME=""
INLINE_TASK=""
OUTPUT_FILE_PATH=""
STREAM_MODE=true  # Default to streaming in task mode
DRY_RUN=false
SYSTEM_PROMPTS_OVERRIDE=""

# Separate storage for CLI-provided context paths (relative to PWD)
CLI_CONTEXT_FILES=()
CLI_CONTEXT_PATTERN=""

# Parse task-specific and shared arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --inline|-i)
            INLINE_TASK="$2"
            shift 2
            ;;
        --output-file)
            OUTPUT_FILE_PATH="$2"
            shift 2
            ;;
        --stream)
            STREAM_MODE=true
            shift
            ;;
        --no-stream)
            STREAM_MODE=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --context-file)
            CLI_CONTEXT_FILES+=("$2")
            shift 2
            ;;
        --context-pattern)
            CLI_CONTEXT_PATTERN="$2"
            shift 2
            ;;
        --model)
            MODEL="$2"
            shift 2
            ;;
        --temperature)
            TEMPERATURE="$2"
            shift 2
            ;;
        --max-tokens)
            MAX_TOKENS="$2"
            shift 2
            ;;
        --system-prompts)
            SYSTEM_PROMPTS_OVERRIDE="$2"
            shift 2
            ;;
        --output-format|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -*)
            echo "Error: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            # First non-flag argument is task name
            if [[ -z "$TASK_NAME" && -z "$INLINE_TASK" ]]; then
                TASK_NAME="$1"
            else
                echo "Error: Unexpected argument: $1"
                echo "Use --help for usage information"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate task specification
if [[ -z "$TASK_NAME" && -z "$INLINE_TASK" ]]; then
    echo "Error: Must specify either task NAME or --inline TEXT"
    echo "Usage: workflow task NAME [options]"
    echo "   or: workflow task --inline TEXT [options]"
    exit 1
fi

if [[ -n "$TASK_NAME" && -n "$INLINE_TASK" ]]; then
    echo "Error: Cannot specify both task NAME and --inline TEXT"
    echo "Use one or the other"
    exit 1
fi

# =============================================================================
# Task Mode - Optional Project Discovery and Configuration
# =============================================================================

# Try to find project root (non-fatal)
PROJECT_ROOT=$(find_project_root 2>/dev/null) || true

# Tier 1: Global config (with hard-coded fallbacks)
load_global_config

# Tier 2: Project config (if we're in a project)
if [[ -n "$PROJECT_ROOT" ]]; then
    echo "Using project context from: $PROJECT_ROOT"

    if [[ -f "$PROJECT_ROOT/.workflow/config" ]]; then
        while IFS='=' read -r key value; do
            case "$key" in
                MODEL) [[ -n "$value" ]] && MODEL="$value" ;;
                TEMPERATURE) [[ -n "$value" ]] && TEMPERATURE="$value" ;;
                MAX_TOKENS) [[ -n "$value" ]] && MAX_TOKENS="$value" ;;
                OUTPUT_FORMAT) [[ -n "$value" ]] && OUTPUT_FORMAT="$value" ;;
                SYSTEM_PROMPTS) [[ -n "$value" ]] && SYSTEM_PROMPTS=($value) ;;
            esac
        done < <(extract_config "$PROJECT_ROOT/.workflow/config")
    fi
else
    echo "Running in standalone mode (no project context)"
fi

# Tier 3: CLI overrides (highest priority)
if [[ -n "$SYSTEM_PROMPTS_OVERRIDE" ]]; then
    IFS=',' read -ra SYSTEM_PROMPTS <<< "$SYSTEM_PROMPTS_OVERRIDE"
fi

# =============================================================================
# Task Mode - Task Source Resolution
# =============================================================================

if [[ -n "$TASK_NAME" ]]; then
    # Load task from file
    if [[ -z "$WORKFLOW_TASK_PREFIX" ]]; then
        echo "Error: WORKFLOW_TASK_PREFIX environment variable is not set"
        echo "Set WORKFLOW_TASK_PREFIX to the directory containing your task .txt files"
        echo "Or use --inline to specify task directly"
        exit 1
    fi

    TASK_FILE="$WORKFLOW_TASK_PREFIX/${TASK_NAME}.txt"
    if [[ ! -f "$TASK_FILE" ]]; then
        echo "Error: Task file not found: $TASK_FILE"
        exit 1
    fi

    TASK_PROMPT=$(<"$TASK_FILE")
    echo "Loaded task: $TASK_NAME"
else
    # Use inline task
    TASK_PROMPT="$INLINE_TASK"
    echo "Using inline task"
fi

# =============================================================================
# Task Mode - System Prompt Building
# =============================================================================

# Determine system prompt cache location
if [[ -n "$PROJECT_ROOT" ]]; then
    SYSTEM_PROMPT_FILE="$PROJECT_ROOT/.workflow/prompts/system.txt"
    mkdir -p "$(dirname "$SYSTEM_PROMPT_FILE")"
else
    SYSTEM_PROMPT_FILE=$(mktemp)
    trap "rm -f $SYSTEM_PROMPT_FILE" EXIT
fi

# Build system prompt from current configuration
if [[ -z "$WORKFLOW_PROMPT_PREFIX" ]]; then
    echo "Error: WORKFLOW_PROMPT_PREFIX environment variable is not set"
    echo "Set WORKFLOW_PROMPT_PREFIX to the directory containing your *.txt prompt files"
    exit 1
fi

if [[ ! -d "$WORKFLOW_PROMPT_PREFIX" ]]; then
    echo "Error: System prompt directory not found: $WORKFLOW_PROMPT_PREFIX"
    exit 1
fi

echo "Building system prompt from: ${SYSTEM_PROMPTS[*]}"

# Try to build system prompt to temp file
TEMP_SYSTEM_PROMPT=$(mktemp)
BUILD_SUCCESS=true

for prompt_name in "${SYSTEM_PROMPTS[@]}"; do
    prompt_file="$WORKFLOW_PROMPT_PREFIX/${prompt_name}.txt"
    if [[ ! -f "$prompt_file" ]]; then
        echo "Error: System prompt file not found: $prompt_file"
        BUILD_SUCCESS=false
        break
    fi
    cat "$prompt_file" >> "$TEMP_SYSTEM_PROMPT"
done

if [[ "$BUILD_SUCCESS" == true ]]; then
    # Build succeeded - update cache
    mv "$TEMP_SYSTEM_PROMPT" "$SYSTEM_PROMPT_FILE"
    echo "System prompt built successfully"
else
    # Build failed - try fallback to cached version
    rm -f "$TEMP_SYSTEM_PROMPT"

    if [[ -f "$SYSTEM_PROMPT_FILE" ]]; then
        echo "Warning: Using cached system prompt (rebuild failed)"
    else
        echo "Error: Cannot build system prompt and no cached version available"
        exit 1
    fi
fi

# =============================================================================
# Task Mode - Context Aggregation
# =============================================================================

echo "Building context..."

# Use temporary context file
CONTEXT_PROMPT_FILE=$(mktemp)
trap "rm -f $CONTEXT_PROMPT_FILE" EXIT

# Add files from CLI --context-pattern (relative to PWD)
if [[ -n "$CLI_CONTEXT_PATTERN" ]]; then
    echo "  Adding files from CLI pattern: $CLI_CONTEXT_PATTERN"
    eval "filecat $CLI_CONTEXT_PATTERN" >> "$CONTEXT_PROMPT_FILE"
fi

# Add explicit files from CLI --context-file (relative to PWD)
if [[ ${#CLI_CONTEXT_FILES[@]} -gt 0 ]]; then
    echo "  Adding explicit files from CLI..."
    validated_files=()
    for file in "${CLI_CONTEXT_FILES[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "Error: Context file not found: $file"
            exit 1
        fi
        validated_files+=("$file")
    done
    filecat "${validated_files[@]}" >> "$CONTEXT_PROMPT_FILE"
fi

# Check if any context was provided
if [[ ! -s "$CONTEXT_PROMPT_FILE" ]]; then
    echo "Warning: No context provided. Task will run without context."
    echo "  Use --context-file or --context-pattern to add context"
fi

# =============================================================================
# Task Mode - Token Estimation
# =============================================================================

SYSWC=$(wc -w < "$SYSTEM_PROMPT_FILE")
SYSTC=$((SYSWC * 13 / 10 + 4096))
echo "Estimated system tokens: $SYSTC"

TASKWC=$(echo "$TASK_PROMPT" | wc -w)
TASKTC=$((TASKWC * 13 / 10 + 4096))
echo "Estimated task tokens: $TASKTC"

if [[ -s "$CONTEXT_PROMPT_FILE" ]]; then
    CONTEXTWC=$(wc -w < "$CONTEXT_PROMPT_FILE")
    CONTEXTTC=$((CONTEXTWC * 13 / 10 + 4096))
    echo "Estimated context tokens: $CONTEXTTC"
else
    CONTEXTTC=0
fi

TOTAL_INPUT_TOKENS=$((SYSTC + TASKTC + CONTEXTTC))
echo "Estimated total input tokens: $TOTAL_INPUT_TOKENS"
echo ""

# Exit if dry-run
if [[ "$DRY_RUN" == true ]]; then
    echo "Dry-run mode: Stopping before API call"
    exit 0
fi

# =============================================================================
# Task Mode - Output File Setup
# =============================================================================

if [[ -n "$OUTPUT_FILE_PATH" ]]; then
    # User specified explicit output file
    OUTPUT_FILE="$OUTPUT_FILE_PATH"

    # Backup if file exists
    if [[ -f "$OUTPUT_FILE" ]]; then
        echo "Backing up previous output file..."
        OUTPUT_BAK="${OUTPUT_FILE%.*}-$(date +"%Y%m%d%H%M%S").${OUTPUT_FILE##*.}"
        mv -v "$OUTPUT_FILE" "$OUTPUT_BAK"
        echo ""
    fi
else
    # No output file - use temp file for API function
    OUTPUT_FILE=$(mktemp)
    trap "rm -f $OUTPUT_FILE" EXIT
fi

# =============================================================================
# Task Mode - API Request Setup
# =============================================================================

# Read system prompt
SYSTEM_PROMPT=$(<"$SYSTEM_PROMPT_FILE")

# Append project description if exists and non-empty
if [[ -n "$PROJECT_ROOT" ]]; then
    PROJECT_DESC_FILE="$PROJECT_ROOT/.workflow/project.txt"
    if [[ -f "$PROJECT_DESC_FILE" && -s "$PROJECT_DESC_FILE" ]]; then
        # Use filecat to add with XML tags
        PROJECT_DESC=$(filecat "$PROJECT_DESC_FILE")
        SYSTEM_PROMPT="${SYSTEM_PROMPT}"$'\n'"${PROJECT_DESC}"
    fi
fi

# Combine context and task for user prompt
if [[ -s "$CONTEXT_PROMPT_FILE" ]]; then
    USER_PROMPT="$(cat "$CONTEXT_PROMPT_FILE")"$'\n'"$TASK_PROMPT"
else
    USER_PROMPT="$TASK_PROMPT"
fi

# Add output format hint for non-markdown formats
if [[ "$OUTPUT_FORMAT" != "md" ]]; then
    USER_PROMPT="${USER_PROMPT}"$'\n'"<output-format>${OUTPUT_FORMAT}</output-format>"
fi

# JSON-escape prompts
SYSTEM_JSON=$(escape_json "$SYSTEM_PROMPT")
USER_JSON=$(escape_json "$USER_PROMPT")

# =============================================================================
# Task Mode - API Request Execution
# =============================================================================

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
        output_file="$OUTPUT_FILE" || exit 1
else
    anthropic_execute_single \
        api_key="$ANTHROPIC_API_KEY" \
        model="$MODEL" \
        max_tokens="$MAX_TOKENS" \
        temperature="$TEMPERATURE" \
        system_prompt="$SYSTEM_JSON" \
        user_prompt="$USER_JSON" \
        output_file="$OUTPUT_FILE" || exit 1

    # In non-stream mode, display output if no explicit output file
    if [[ -z "$OUTPUT_FILE_PATH" ]]; then
        cat "$OUTPUT_FILE"
    fi
fi

# =============================================================================
# Task Mode - Post-Processing
# =============================================================================

# Only post-process if output file was explicitly specified
if [[ -n "$OUTPUT_FILE_PATH" && -f "$OUTPUT_FILE" ]]; then
    echo ""
    echo "Response saved to: $OUTPUT_FILE"

    # Format-specific post-processing
    case "$OUTPUT_FORMAT" in
        md|markdown)
            if command -v mdformat &>/dev/null; then
                echo "Formatting output with mdformat..."
                mdformat --no-validate "$OUTPUT_FILE"
            fi
            ;;
        json)
            if command -v jq &>/dev/null; then
                echo "Formatting output with jq..."
                jq . "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
            fi
            ;;
        # txt, html, etc. - no formatting needed
    esac

    echo ""
    echo "Task completed successfully!"
fi
