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
COUNT_TOKENS=false
SYSTEM_PROMPTS_OVERRIDE=""

# Separate storage for CLI-provided paths (relative to PWD)
CLI_INPUT_FILES=()
CLI_INPUT_PATTERN=""
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
        --count-tokens)
            COUNT_TOKENS=true
            shift
            ;;
        --input-file)
            CLI_INPUT_FILES+=("$2")
            shift 2
            ;;
        --input-pattern)
            CLI_INPUT_PATTERN="$2"
            shift 2
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
        --enable-citations)
            ENABLE_CITATIONS=true
            shift
            ;;
        --disable-citations)
            ENABLE_CITATIONS=false
            shift
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
                ENABLE_CITATIONS) [[ -n "$value" ]] && ENABLE_CITATIONS="$value" ;;
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
build_system_prompt "$SYSTEM_PROMPT_FILE" || exit 1

# =============================================================================
# Task Mode - Context Aggregation
# =============================================================================

# Use temporary files for JSON block files (for API)
SYSTEM_BLOCKS_FILE=$(mktemp)
USER_BLOCKS_FILE=$(mktemp)
REQUEST_JSON_FILE=$(mktemp)
DOCUMENT_MAP_FILE=$(mktemp)

# Clean up all temp files on exit
trap "rm -f $SYSTEM_BLOCKS_FILE $USER_BLOCKS_FILE $REQUEST_JSON_FILE $DOCUMENT_MAP_FILE" EXIT

# Content blocks arrays for JSON building
declare -a SYSTEM_BLOCKS
declare -a CONTEXT_BLOCKS
declare -a DEPENDENCY_BLOCKS
declare -a INPUT_BLOCKS
declare -a DOCUMENT_INDEX_MAP

aggregate_context "task" "$PROJECT_ROOT"

# =============================================================================
# Task Mode - API Request Setup - Build Final Prompts
# =============================================================================

build_prompts "$SYSTEM_PROMPT_FILE" "$PROJECT_ROOT" "$TASK_PROMPT"

# =============================================================================
# Token Estimation (if requested)
# =============================================================================

estimate_tokens

# =============================================================================
# Dry-Run Mode - Save Prompts and Inspect
# =============================================================================

handle_dry_run_mode "task" ""

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

# Execute API request
execute_api_request "task" "$OUTPUT_FILE" "$OUTPUT_FILE_PATH"

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
