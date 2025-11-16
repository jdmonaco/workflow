#!/usr/bin/env bash
set -e

# =============================================================================
# Workflow - AI-Assisted Research and Project Development Tool
# =============================================================================
# A portable CLI tool for managing AI workflows using the Anthropic Messages
# API. Features git-like project structure, flexible configuration cascading,
# context aggregation, and workflow chaining.
#
# Subcommands:
#   init [dir]       Initialize workflow project structure
#   new NAME         Create new workflow with task and config files
#   edit [NAME]      Edit workflow or project files (NAME optional)
#   run NAME [opts]  Execute workflow with context aggregation
#
# Usage:
#   workflow init .
#   workflow new 01-analysis
#   workflow edit 01-analysis
#   workflow run 01-analysis --stream
#
# See --help for complete documentation
# =============================================================================

# Source function libraries
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/help.sh"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/api.sh"

# =============================================================================
# Default Configuration
# =============================================================================
DEFAULT_MODEL="claude-sonnet-4-5"
DEFAULT_TEMPERATURE=1.0
DEFAULT_MAX_TOKENS=4096
DEFAULT_OUTPUT_FORMAT="md"

# =============================================================================
# Global Configuration Setup
# =============================================================================

# Ensure global config exists (creates on first use)
ensure_global_config || true  # Don't fail if can't create (will use fallbacks)

# =============================================================================
# Parse Subcommand
# =============================================================================

# Require subcommand
if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

# Parse subcommand
case "$1" in
    init)
        if [[ "$2" == "-h" || "$2" == "--help" ]]; then
            show_help_init
            exit 0
        fi
        init_project "$2"
        exit 0
        ;;
    new)
        if [[ "$2" == "-h" || "$2" == "--help" ]]; then
            show_help_new
            exit 0
        fi
        if [[ -z "$2" ]]; then
            echo "Error: Workflow name required"
            echo "Usage: workflow new NAME"
            exit 1
        fi
        new_workflow "$2"
        exit 0
        ;;
    edit)
        if [[ "$2" == "-h" || "$2" == "--help" ]]; then
            show_help_edit
            exit 0
        fi
        if [[ -z "$2" ]]; then
            echo "Error: Workflow name required"
            echo "Usage: workflow edit NAME"
            exit 1
        fi
        edit_workflow "$2"
        exit 0
        ;;
    list|ls)
        if [[ "$2" == "-h" || "$2" == "--help" ]]; then
            show_help_list
            exit 0
        fi
        list_workflows_cmd
        exit 0
        ;;
    config)
        shift  # Remove 'config' from args

        # Parse flags
        NO_EDIT=false
        WORKFLOW_NAME=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                -h|--help)
                    show_help_config
                    exit 0
                    ;;
                --no-edit)
                    NO_EDIT=true
                    shift
                    ;;
                *)
                    # First non-flag argument is workflow name
                    if [[ -z "$WORKFLOW_NAME" ]]; then
                        WORKFLOW_NAME="$1"
                    fi
                    shift
                    ;;
            esac
        done

        # Call appropriate config function
        if [[ -z "$WORKFLOW_NAME" ]]; then
            config_project "$NO_EDIT"
        else
            config_workflow "$WORKFLOW_NAME" "$NO_EDIT"
        fi
        exit 0
        ;;
    run)
        shift  # Remove 'run' from args
        if [[ "$1" == "-h" || "$1" == "--help" ]]; then
            show_help_run
            exit 0
        fi
        if [[ -z "$1" ]]; then
            echo "Error: Workflow name required"
            echo "Usage: workflow run NAME [options]"
            exit 1
        fi
        WORKFLOW_NAME="$1"
        shift  # Remove workflow name from args
        # Continue to run mode with remaining args
        ;;
    task)
        shift  # Remove 'task' from args
        if [[ "$1" == "-h" || "$1" == "--help" ]]; then
            show_help_task
            exit 0
        fi
        # Parse task name or --inline flag
        # Continue to task mode with remaining args
        TASK_MODE=true
        ;;
    help)
        shift  # Remove 'help' from args
        if [[ -n "$1" ]]; then
            # Subcommand-specific help
            case "$1" in
                init) show_help_init ;;
                new) show_help_new ;;
                edit) show_help_edit ;;
                list|ls) show_help_list ;;
                config) show_help_config ;;
                run) show_help_run ;;
                task) show_help_task ;;
                *)
                    echo "Error: Unknown subcommand: $1"
                    echo "Use 'workflow help' to see all available subcommands"
                    echo ""
                    show_help
                    exit 1
                    ;;
            esac
        else
            # Main help
            show_help
        fi
        exit 0
        ;;
    --help|-h)
        show_help
        exit 0
        ;;
    *)
        echo "Error: Unknown subcommand: $1"
        echo "Valid subcommands: init, new, edit, list, config, run"
        echo ""
        show_help
        exit 1
        ;;
esac

# =============================================================================
# Task Mode vs Run Mode Dispatch
# =============================================================================

if [[ "${TASK_MODE:-false}" == "true" ]]; then
    # Jump to task mode implementation
    source "$SCRIPT_DIR/lib/task.sh"
    exit 0
fi

# =============================================================================
# Run Mode - Find Project and Load Configuration
# =============================================================================

# Find project root
PROJECT_ROOT=$(find_project_root) || {
    echo "Error: Not in workflow project (no .workflow/ directory found)"
    echo "Run 'workflow init' to initialize a project"
    exit 1
}

WORKFLOW_DIR="$PROJECT_ROOT/.workflow/$WORKFLOW_NAME"

# Check workflow exists
if [[ ! -d "$WORKFLOW_DIR" ]]; then
    echo "Error: Workflow '$WORKFLOW_NAME' not found"
    echo "Available workflows:"
    if list_workflows; then
        list_workflows | sed 's/^/  /'
    else
        echo "  (none)"
    fi
    echo ""
    echo "Create new workflow with: workflow new $WORKFLOW_NAME"
    exit 1
fi

# Tier 1: Global config (with hard-coded fallbacks)
load_global_config

# Initialize workflow-specific variables
CONTEXT_FILES=()
CONTEXT_PATTERN=""
DEPENDS_ON=()

# Tier 2: Project-level config (only apply non-empty values)
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

# Tier 3: Workflow-level config (only apply non-empty values)
if [[ -f "$WORKFLOW_DIR/config" ]]; then
    while IFS='=' read -r key value; do
        case "$key" in
            MODEL) [[ -n "$value" ]] && MODEL="$value" ;;
            TEMPERATURE) [[ -n "$value" ]] && TEMPERATURE="$value" ;;
            MAX_TOKENS) [[ -n "$value" ]] && MAX_TOKENS="$value" ;;
            OUTPUT_FORMAT) [[ -n "$value" ]] && OUTPUT_FORMAT="$value" ;;
            SYSTEM_PROMPTS) [[ -n "$value" ]] && SYSTEM_PROMPTS=($value) ;;
            CONTEXT_PATTERN) [[ -n "$value" ]] && CONTEXT_PATTERN="$value" ;;
            CONTEXT_FILES) [[ -n "$value" ]] && CONTEXT_FILES=($value) ;;
            DEPENDS_ON) [[ -n "$value" ]] && DEPENDS_ON=($value) ;;
        esac
    done < <(extract_config "$WORKFLOW_DIR/config")
fi

# =============================================================================
# Run Mode - Parse Command-Line Overrides
# =============================================================================
STREAM_MODE=false
DRY_RUN=false
SYSTEM_PROMPTS_OVERRIDE=""

# Separate storage for CLI-provided paths (relative to PWD)
CLI_CONTEXT_FILES=()
CLI_CONTEXT_PATTERN=""

# Parse arguments (command-line overrides)
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --stream)
            STREAM_MODE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --context-file)
            CLI_CONTEXT_FILES+=("$2")  # Store CLI paths separately
            shift 2
            ;;
        --context-pattern)
            CLI_CONTEXT_PATTERN="$2"  # Store CLI pattern separately
            shift 2
            ;;
        --depends-on)
            DEPENDS_ON+=("$2")  # Add to config
            shift 2
            ;;
        --model)
            MODEL="$2"  # Override config
            shift 2
            ;;
        --temperature)
            TEMPERATURE="$2"  # Override config
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
        *)
            echo "Error: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Handle --system-prompts override (comma-separated list)
if [[ -n "$SYSTEM_PROMPTS_OVERRIDE" ]]; then
    IFS=',' read -ra SYSTEM_PROMPTS <<< "$SYSTEM_PROMPTS_OVERRIDE"
fi

# =============================================================================
# Run Mode - Setup Paths
# =============================================================================

# File paths (all relative to PROJECT_ROOT/.workflow/)
TASK_PROMPT_FILE="$WORKFLOW_DIR/task.txt"
CONTEXT_PROMPT_FILE="$WORKFLOW_DIR/context.txt"
OUTPUT_FILE="$WORKFLOW_DIR/output.${OUTPUT_FORMAT}"
OUTPUT_LINK="$PROJECT_ROOT/.workflow/output/${WORKFLOW_NAME}.${OUTPUT_FORMAT}"
SYSTEM_PROMPT_FILE="$PROJECT_ROOT/.workflow/prompts/system.txt"

# Validate task file exists
if [[ ! -f "$TASK_PROMPT_FILE" ]]; then
    echo "Error: Task file not found: $TASK_PROMPT_FILE"
    echo "Workflow may be incomplete. Re-create with: workflow new $WORKFLOW_NAME"
    exit 1
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

# Ensure prompts directory exists
mkdir -p "$(dirname "$SYSTEM_PROMPT_FILE")"

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
# Context Aggregation
# =============================================================================

echo "Building context..."

# Start with empty context
> "$CONTEXT_PROMPT_FILE"

# Add files from --depends-on (from output/ directory)
if [[ ${#DEPENDS_ON[@]} -gt 0 ]]; then
    echo "  Adding dependencies..."
    dep_files=()
    for dep in "${DEPENDS_ON[@]}"; do
        # Find dependency output with any extension using glob
        dep_file=$(ls "$PROJECT_ROOT/.workflow/output/${dep}".* 2>/dev/null | head -1)
        if [[ -z "$dep_file" ]]; then
            echo "Error: Dependency output not found for workflow: $dep"
            echo "Expected file matching: $PROJECT_ROOT/.workflow/output/${dep}.*"
            echo "Ensure workflow '$dep' has been executed successfully"
            exit 1
        fi
        echo "    - $dep_file"
        dep_files+=("$dep_file")
    done
    filecat "${dep_files[@]}" >> "$CONTEXT_PROMPT_FILE"
fi

# Add files from config CONTEXT_PATTERN (relative to PROJECT_ROOT)
if [[ -n "$CONTEXT_PATTERN" ]]; then
    echo "  Adding files from config pattern: $CONTEXT_PATTERN"
    (cd "$PROJECT_ROOT" && eval "filecat $CONTEXT_PATTERN") >> "$CONTEXT_PROMPT_FILE"
fi

# Add files from CLI --context-pattern (relative to PWD)
if [[ -n "$CLI_CONTEXT_PATTERN" ]]; then
    echo "  Adding files from CLI pattern: $CLI_CONTEXT_PATTERN"
    eval "filecat $CLI_CONTEXT_PATTERN" >> "$CONTEXT_PROMPT_FILE"
fi

# Add explicit files from config CONTEXT_FILES (relative to PROJECT_ROOT)
if [[ ${#CONTEXT_FILES[@]} -gt 0 ]]; then
    echo "  Adding explicit files from config..."
    resolved_files=()
    for file in "${CONTEXT_FILES[@]}"; do
        resolved_file="$PROJECT_ROOT/$file"
        if [[ ! -f "$resolved_file" ]]; then
            echo "Error: Context file not found: $file (resolved: $resolved_file)"
            exit 1
        fi
        resolved_files+=("$resolved_file")
    done
    filecat "${resolved_files[@]}" >> "$CONTEXT_PROMPT_FILE"
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
    echo "  Use --context-file, --context-pattern, or --depends-on to add context"
fi

# =============================================================================
# Token Estimation
# =============================================================================

SYSWC=$(wc -w < "$SYSTEM_PROMPT_FILE")
SYSTC=$((SYSWC * 13 / 10 + 4096))
echo "Estimated system tokens: $SYSTC"

TASKWC=$(wc -w < "$TASK_PROMPT_FILE")
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
# API Request Setup
# =============================================================================

# Read prompt files
SYSTEM_PROMPT=$(<"$SYSTEM_PROMPT_FILE")

# Append project description if exists and non-empty
PROJECT_DESC_FILE="$PROJECT_ROOT/.workflow/project.txt"
if [[ -f "$PROJECT_DESC_FILE" && -s "$PROJECT_DESC_FILE" ]]; then
    # Use filecat to add with XML tags
    PROJECT_DESC=$(filecat "$PROJECT_DESC_FILE")
    SYSTEM_PROMPT="${SYSTEM_PROMPT}"$'\n'"${PROJECT_DESC}"
fi

# Combine context and task for user prompt
if [[ -s "$CONTEXT_PROMPT_FILE" ]]; then
    USER_PROMPT="$(filecat "$CONTEXT_PROMPT_FILE" "$TASK_PROMPT_FILE")"
else
    USER_PROMPT=$(<"$TASK_PROMPT_FILE")
fi

# Add output format hint for non-markdown formats
if [[ "$OUTPUT_FORMAT" != "md" ]]; then
    USER_PROMPT="${USER_PROMPT}"$'\n'"<output-format>${OUTPUT_FORMAT}</output-format>"
fi

# JSON-escape prompts
SYSTEM_JSON=$(escape_json "$SYSTEM_PROMPT")
USER_JSON=$(escape_json "$USER_PROMPT")

# Backup any previous output files
if [[ -f "$OUTPUT_FILE" ]]; then
    echo "Backing up previous output file..."
    OUTPUT_BAK="${OUTPUT_FILE%.*}-$(date +"%Y%m%d%H%M%S").${OUTPUT_FILE##*.}"
    mv -v "$OUTPUT_FILE" "$OUTPUT_BAK"
    echo ""
fi

# =============================================================================
# API Request Execution
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
fi

# =============================================================================
# Post-Processing
# =============================================================================

echo "Response saved to: $OUTPUT_FILE"

# Create/update hardlink in output directory
mkdir -p "$PROJECT_ROOT/.workflow/output"
if [[ -f "$OUTPUT_LINK" ]]; then
    rm "$OUTPUT_LINK"
fi
ln "$OUTPUT_FILE" "$OUTPUT_LINK"
echo "Hardlink created: $OUTPUT_LINK"

# Format-specific post-processing
if [[ -f "$OUTPUT_FILE" ]]; then
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
fi

echo ""
echo "Workflow '$WORKFLOW_NAME' completed successfully!"
