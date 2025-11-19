#!/usr/bin/env bash
set -e

# Version
WORKFLOW_VERSION="0.1.0"

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
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/help.sh"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/execute.sh"
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
    --version|-v)
        echo "workflow version $WORKFLOW_VERSION"
        exit 0
        ;;
    --help|-h)
        show_help
        exit 0
        ;;
    init)
        if [[ "$2" == "-h" || "$2" == "--help" ]]; then
            show_quick_help_init
            exit 0
        fi
        init_project "$2"
        exit 0
        ;;
    new)
        if [[ "$2" == "-h" || "$2" == "--help" ]]; then
            show_quick_help_new
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
            show_quick_help_edit
            exit 0
        fi
        edit_workflow "$2"
        exit 0
        ;;
    cat)
        if [[ "$2" == "-h" || "$2" == "--help" ]]; then
            show_quick_help_cat
            exit 0
        fi
        if [[ -z "$2" ]]; then
            echo "Error: Workflow name required"
            echo "Usage: workflow cat NAME"
            exit 1
        fi
        cat_workflow "$2"
        exit 0
        ;;
    open)
        if [[ "$2" == "-h" || "$2" == "--help" ]]; then
            show_quick_help_open
            exit 0
        fi
        if [[ -z "$2" ]]; then
            echo "Error: Workflow name required"
            echo "Usage: workflow open NAME"
            exit 1
        fi
        open_workflow "$2"
        exit 0
        ;;
    list|ls)
        if [[ "$2" == "-h" || "$2" == "--help" ]]; then
            show_quick_help_list
            exit 0
        fi
        list_workflows_cmd
        exit 0
        ;;
    config)
        shift  # Remove 'config' from args

        # Parse flags
        EDIT_MODE=false
        WORKFLOW_NAME=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                -h|--help)
                    show_quick_help_config
                    exit 0
                    ;;
                --edit)
                    EDIT_MODE=true
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
            config_project "$EDIT_MODE"
        else
            config_workflow "$WORKFLOW_NAME" "$EDIT_MODE"
        fi
        exit 0
        ;;
    run)
        shift  # Remove 'run' from args
        if [[ "$1" == "-h" || "$1" == "--help" ]]; then
            show_quick_help_run
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
            show_quick_help_task
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
                cat) show_help_cat ;;
                open) show_help_open ;;
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

# Tier 2: Ancestor project cascade (grandparent → parent, oldest to newest)
load_ancestor_configs "$PROJECT_ROOT"

# Tier 3: Current project config (only apply non-empty values)
if [[ -f "$PROJECT_ROOT/.workflow/config" ]]; then
    while IFS='=' read -r key value; do
        case "$key" in
            MODEL) [[ -n "$value" ]] && MODEL="$value" && CONFIG_SOURCE_MAP[MODEL]="$PROJECT_ROOT" ;;
            TEMPERATURE) [[ -n "$value" ]] && TEMPERATURE="$value" && CONFIG_SOURCE_MAP[TEMPERATURE]="$PROJECT_ROOT" ;;
            MAX_TOKENS) [[ -n "$value" ]] && MAX_TOKENS="$value" && CONFIG_SOURCE_MAP[MAX_TOKENS]="$PROJECT_ROOT" ;;
            OUTPUT_FORMAT) [[ -n "$value" ]] && OUTPUT_FORMAT="$value" && CONFIG_SOURCE_MAP[OUTPUT_FORMAT]="$PROJECT_ROOT" ;;
            SYSTEM_PROMPTS) [[ -n "$value" ]] && SYSTEM_PROMPTS=($value) && CONFIG_SOURCE_MAP[SYSTEM_PROMPTS]="$PROJECT_ROOT" ;;
        esac
    done < <(extract_config "$PROJECT_ROOT/.workflow/config")
fi

# Tier 4: Workflow-level config (only apply non-empty values)
if [[ -f "$WORKFLOW_DIR/config" ]]; then
    while IFS='=' read -r key value; do
        case "$key" in
            MODEL) [[ -n "$value" ]] && MODEL="$value" && CONFIG_SOURCE_MAP[MODEL]="workflow" ;;
            TEMPERATURE) [[ -n "$value" ]] && TEMPERATURE="$value" && CONFIG_SOURCE_MAP[TEMPERATURE]="workflow" ;;
            MAX_TOKENS) [[ -n "$value" ]] && MAX_TOKENS="$value" && CONFIG_SOURCE_MAP[MAX_TOKENS]="workflow" ;;
            OUTPUT_FORMAT) [[ -n "$value" ]] && OUTPUT_FORMAT="$value" && CONFIG_SOURCE_MAP[OUTPUT_FORMAT]="workflow" ;;
            SYSTEM_PROMPTS) [[ -n "$value" ]] && SYSTEM_PROMPTS=($value) && CONFIG_SOURCE_MAP[SYSTEM_PROMPTS]="workflow" ;;
            INPUT_PATTERN) [[ -n "$value" ]] && INPUT_PATTERN="$value" ;;
            INPUT_FILES) [[ -n "$value" ]] && INPUT_FILES=($value) ;;
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
COUNT_TOKENS=false
SYSTEM_PROMPTS_OVERRIDE=""

# Separate storage for CLI-provided paths (relative to PWD)
CLI_INPUT_FILES=()
CLI_INPUT_PATTERN=""
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
        --count-tokens)
            COUNT_TOKENS=true
            shift
            ;;
        --input-file)
            CLI_INPUT_FILES+=("$2")  # Store CLI paths separately
            shift 2
            ;;
        --input-pattern)
            CLI_INPUT_PATTERN="$2"  # Store CLI pattern separately
            shift 2
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

# File paths - XML text files for debugging (relative to PROJECT_ROOT/.workflow/)
TASK_PROMPT_FILE="$WORKFLOW_DIR/task.txt"
INPUT_PROMPT_FILE="$WORKFLOW_DIR/input.txt"
CONTEXT_PROMPT_FILE="$WORKFLOW_DIR/context.txt"

# File paths - JSON block files for API (relative to PROJECT_ROOT/.workflow/)
JSON_BLOCKS_FILE="$WORKFLOW_DIR/content_blocks.json"
JSON_REQUEST_FILE="$WORKFLOW_DIR/request.json"

# File paths - Output and system
OUTPUT_FILE="$WORKFLOW_DIR/output.${OUTPUT_FORMAT}"
OUTPUT_LINK="$PROJECT_ROOT/.workflow/output/${WORKFLOW_NAME}.${OUTPUT_FORMAT}"
SYSTEM_PROMPT_FILE="$PROJECT_ROOT/.workflow/prompts/system.txt"

# Content blocks arrays for JSON building
declare -a SYSTEM_BLOCKS
declare -a CONTEXT_BLOCKS
declare -a DEPENDENCY_BLOCKS
declare -a INPUT_BLOCKS

# Validate task file exists
if [[ ! -f "$TASK_PROMPT_FILE" ]]; then
    echo "Error: Task file not found: $TASK_PROMPT_FILE"
    echo "Workflow may be incomplete. Re-create with: workflow new $WORKFLOW_NAME"
    exit 1
fi

# Build system prompt from current configuration
build_system_prompt "$SYSTEM_PROMPT_FILE" || exit 1

# =============================================================================
# Context Aggregation
# =============================================================================

aggregate_context "run" "$INPUT_PROMPT_FILE" "$CONTEXT_PROMPT_FILE" "$PROJECT_ROOT"

# =============================================================================
# API Request Setup - Build Final Prompts
# =============================================================================

build_prompts "$SYSTEM_PROMPT_FILE" "$PROJECT_ROOT" "$INPUT_PROMPT_FILE" "$CONTEXT_PROMPT_FILE" "$TASK_PROMPT_FILE"

# =============================================================================
# Token Estimation (if requested)
# =============================================================================

estimate_tokens "$SYSTEM_PROMPT_FILE" "$TASK_PROMPT_FILE" "$INPUT_PROMPT_FILE" "$CONTEXT_PROMPT_FILE"

# =============================================================================
# Dry-Run Mode - Save Prompts and Inspect
# =============================================================================

handle_dry_run_mode "run" "$WORKFLOW_DIR"

# Execute API request
execute_api_request "run" "$OUTPUT_FILE" ""

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
