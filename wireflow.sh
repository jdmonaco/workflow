#!/usr/bin/env bash
set -e

# =============================================================================
# WireFlow: Build Reproducible AI Workflows Anywhere in the Terminal
# =============================================================================
#
# WireFlow is a command-line interface for building reproducible AI workflows 
# for research, development, and analysis, featuring flexible configuration 
# cascades, comprehensive document processing (PDFs, Office files, images), 
# workflow dependencies and chaining, and intelligent context management.
#
# =============================================================================
WIREFLOW_VERSION="0.4.0"
# =============================================================================

# Script name -- as called by the user
SCRIPT_NAME="$(basename ${0})"

# Source function libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/lib/api.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/execute.sh"
source "$SCRIPT_DIR/lib/help.sh"
source "$SCRIPT_DIR/lib/run.sh"
source "$SCRIPT_DIR/lib/task.sh"
source "$SCRIPT_DIR/lib/utils.sh"

# =============================================================================
# Test/Environment Mode Flags (must be set before subcommand handlers)
# =============================================================================
DRY_RUN="${WIREFLOW_DRY_RUN:-false}"

# =============================================================================
# Global Configuration Setup -- Builtin Defaults
# =============================================================================

# Config cascade: Set builtin values for config parameters

# Model profile system: PROFILE selects tier, MODEL_* defines each tier's model
# MODEL (if non-empty) overrides the profile system entirely
BUILTIN_PROFILE="balanced"
BUILTIN_MODEL_FAST="claude-haiku-4-5"
BUILTIN_MODEL_BALANCED="claude-sonnet-4-5"
BUILTIN_MODEL_DEEP="claude-opus-4-5"
BUILTIN_MODEL=""  # Empty = use profile system; non-empty = explicit override

# Extended thinking parameters
BUILTIN_ENABLE_THINKING="false"
BUILTIN_THINKING_BUDGET=10000

# Effort parameter (Opus 4.5 only; high = API default)
BUILTIN_EFFORT="high"

# Other API parameters
BUILTIN_TEMPERATURE=1.0
BUILTIN_MAX_TOKENS=16000
BUILTIN_ENABLE_CITATIONS="false"
BUILTIN_OUTPUT_FORMAT="md"
BUILTIN_SYSTEM_PROMPTS=(base)

# Initialize config source tracking:
#   builtin → global → ancestor → project → workflow → CLI
declare -A CONFIG_SOURCE_MAP
CONFIG_KEYS=(
    "PROFILE" "MODEL_FAST" "MODEL_BALANCED" "MODEL_DEEP" "MODEL"
    "ENABLE_THINKING" "THINKING_BUDGET" "EFFORT"
    "TEMPERATURE" "MAX_TOKENS" "ENABLE_CITATIONS"
    "SYSTEM_PROMPTS" "OUTPUT_FORMAT"
)  
for key in "${CONFIG_KEYS[@]}"; do  
    builtin_key="BUILTIN_$key"
    
    # Check if builtin is an array
    if declare -p "$builtin_key" 2>/dev/null | grep -q '^declare -a'; then
        # Copy array from builtin
        declare -n builtin_arr="$builtin_key"
        declare -n target_arr="$key"
        target_arr=("${builtin_arr[@]}")
        unset -n builtin_arr target_arr
    else
        # Copy scalar from builtin
        printf -v "$key" '%s' "${!builtin_key}"
    fi
    
    CONFIG_SOURCE_MAP[$key]="builtin"  
done  

# Global config directory and file paths (respect pre-set values for testing)
GLOBAL_CONFIG_DIR="${GLOBAL_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/wireflow}"
GLOBAL_CONFIG_FILE="${GLOBAL_CONFIG_FILE:-$GLOBAL_CONFIG_DIR/config}"

# =============================================================================
# User-Environment Variables Setup
# =============================================================================

# Set builtin values for user-env variables
BUILTIN_WIREFLOW_PROMPT_PREFIX="$GLOBAL_CONFIG_DIR/prompts/system"
BUILTIN_WIREFLOW_TASK_PREFIX="$GLOBAL_CONFIG_DIR/prompts/tasks"
BUILTIN_ANTHROPIC_API_KEY=""

# Initialize user-env source tracking
declare -A USER_ENV_SOURCE_MAP  
USER_ENV_KEYS=(  
    "WIREFLOW_PROMPT_PREFIX" "WIREFLOW_TASK_PREFIX" "ANTHROPIC_API_KEY"  
)  
for key in "${USER_ENV_KEYS[@]}"; do  
    if [[ -z "${!key}" ]]; then  
        builtin_key="BUILTIN_$key"
        
        # Check if builtin is an array
        if declare -p "$builtin_key" 2>/dev/null | grep -q '^declare -a'; then
            # Copy array from builtin
            declare -n builtin_arr="$builtin_key"
            declare -n target_arr="$key"
            target_arr=("${builtin_arr[@]}")
            unset -n builtin_arr target_arr
        else
            # Copy scalar from builtin
            printf -v "$key" '%s' "${!builtin_key}"
        fi
        
        USER_ENV_SOURCE_MAP[$key]="builtin"  
    else  
        # Value is already set in the shell environment  
        USER_ENV_SOURCE_MAP[$key]="env"  
    fi  
done

# =============================================================================
# Initiate Config Cascade - Create/Load Global Config
# =============================================================================
ensure_global_config || true
load_global_config

# =============================================================================  
# Project-Level Configuration Setup  
# =============================================================================  

# Initialize project-level variables
declare -a CONTEXT_FILES=()
declare -a CONTEXT_FILES_CLI=()
declare CONTEXT_PATTERN=""
declare CONTEXT_PATTERN_CLI=""

# Initialize project-level source tracking:  
#   project → workflow → CLI  
declare -A PROJECT_SOURCE_MAP  
PROJECT_KEYS=(  
    "CONTEXT_PATTERN"
    "CONTEXT_PATTERN_CLI"
    "CONTEXT_FILES"
    "CONTEXT_FILES_CLI"
)  
for key in "${PROJECT_KEYS[@]}"; do  
    PROJECT_SOURCE_MAP[$key]="unset"  
done  

# =============================================================================  
# Workflow-Specific Configuration Setup  
# =============================================================================  

# Initialize workflow-specific variables
declare -a DEPENDS_ON=()
declare -a DEPENDS_ON_CLI=()
declare -a INPUT_FILES=()
declare -a INPUT_FILES_CLI=()
declare INPUT_PATTERN=""
declare INPUT_PATTERN_CLI=""
declare EXPORT_FILE=""

# Initialize workflow-specific source tracking:  
#   workflow → CLI  
declare -A WORKFLOW_SOURCE_MAP  
WORKFLOW_KEYS=(  
    "DEPENDS_ON"
    "DEPENDS_ON_CLI"
    "INPUT_PATTERN"
    "INPUT_PATTERN_CLI"
    "INPUT_FILES"
    "INPUT_FILES_CLI"
    "EXPORT_FILE"
)  
for key in "${WORKFLOW_KEYS[@]}"; do
    WORKFLOW_SOURCE_MAP[$key]="unset"
done

# =============================================================================
# Content Block Arrays for API Request Building
# =============================================================================
# These arrays accumulate JSON content blocks during context aggregation
# and are used by execute.sh to build the final API request.

declare -a SYSTEM_BLOCKS=()
declare -a CONTEXT_BLOCKS=()
declare -a DEPENDENCY_BLOCKS=()
declare -a INPUT_BLOCKS=()
declare -a IMAGE_BLOCKS=()
declare -a DOCUMENT_INDEX_MAP=()

# =============================================================================
# Subcommand Dispatcher
# =============================================================================

# Require subcommand
if [[ $# -eq 0 ]]; then
    echo "Error: missing subcommand name" >&2
    show_help
    exit 1
fi

# Handle all quick help calls (-h|--help)
if [[ $# -eq 2 ]] && [[ "$2" == "-h" || "$2" == "--help" ]]; then
    if type -t "show_quick_help_$1" &>/dev/null; then
        show_quick_help_$1
        exit 0
    fi
    echo "Error: unknown subcommand: $1" >&2
    show_help
    exit 1
fi

# Parse subcommand
cmd="$1"
shift
case "$cmd" in
    init)
        init_project "$1"
        exit 0
        ;;
    new|edit|config|run|cat|open|list)
        # These are all the commands which require a verified project root
        PROJECT_ROOT="$(find_project_root)" || {
            echo "Error: No project found" >&2
            echo "" >&2
            echo "Run '$SCRIPT_NAME init' to initialize a project." >&2
            echo "Run '$SCRIPT_NAME help init' for details." >&2
            exit 1
        }

        # Project-level paths
        WIREFLOW_DIR="$PROJECT_ROOT/.workflow"
        PROJECT_CONFIG="$WIREFLOW_DIR/config"
        PROJECT_FILE="$WIREFLOW_DIR/project.txt"
        OUTPUT_DIR="$WIREFLOW_DIR/output"
        RUN_DIR="$WIREFLOW_DIR/run"

        # Config cascade: Propagate through ancestors and current project
        load_ancestor_configs || true
        load_project_config || true

        case "$cmd" in
            new)
                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        --from-task)
                            if [[ -z "$2" ]]; then
                                echo "Error: Task template name required"
                                show_quick_help_new
                                exit 1
                            fi
                            NEW_FROM_TASK="$2"
                            shift
                            shift
                            ;;
                        *)
                            # First non-flag argument is workflow name
                            if [[ -n "${WORKFLOW_NAME:-}" ]]; then
                                echo "Error: Too many arguments"
                                show_quick_help_new
                                exit 1
                            fi
                            WORKFLOW_NAME="$1"
                            shift
                    esac
                done
                if [[ -z "${WORKFLOW_NAME:-}" ]]; then
                    echo "Error: Workflow name required" >&2
                    show_quick_help_new
                    exit 1
                fi
                WORKFLOW_DIR="$RUN_DIR/$WORKFLOW_NAME"
                new_workflow "$WORKFLOW_NAME" "$WORKFLOW_DIR" "$NEW_FROM_TASK"
                exit 0
                ;;
            edit)
                WORKFLOW_NAME="${1:-}"
                if [[ -n "$WORKFLOW_NAME" ]]; then
                    check_workflow_dir
                    edit_workflow
                    exit 0
                fi
                edit_project
                exit 0
                ;;
            config)
                WORKFLOW_NAME="${1:-}"
                if [[ -n "$WORKFLOW_NAME" ]]; then
                    config_workflow
                    exit 0
                fi
                config_project
                exit 0
                ;;
            list)
                cmd_list
                exit 0
                ;;
            run)  
                if [[ $# -eq 0 ]]; then  
                    echo "Error: Workflow name required" >&2  
                    echo "Usage: $SCRIPT_NAME run <name> [options]" >&2
                    exit 1  
                fi
                
                # Delegate to run mode handler
                cmd_run "$@"
                exit $?
                ;;
            cat)
                if [[ -z "$1" ]]; then
                    echo "Error: Workflow name required" >&2
                    echo "Usage: $SCRIPT_NAME cat NAME"
                    exit 1
                fi
                cat_workflow "$1"
                exit 0
                ;;
            open)
                if [[ -z "$1" ]]; then
                    echo "Error: Workflow name required" >&2
                    echo "Usage: $SCRIPT_NAME open NAME"
                    exit 1
                fi
                open_workflow "$1"
                exit 0
                ;;
        esac
        ;;
    task)
        # Execute named task template
        if [[ $# -eq 0 ]]; then  
            echo "Error: Task name required" >&2  
            show_quick_help_task  
            exit 1  
        fi
        
        # Delegate to task execution handler
        cmd_task "$@"
        exit $?
        ;;
    tasks)
        # Manage task templates
        if [[ $# -eq 0 ]]; then
            # No subcommand - default to list
            list_tasks
        else
            subcmd="$1"
            shift
            
            case "$subcmd" in  
                list)
                    list_tasks
                    ;;
                show)
                    if [[ $# -eq 0 ]]; then  
                        echo "Error: Task name required" >&2  
                        echo "Usage: $SCRIPT_NAME tasks show <name>" >&2
                        exit 1  
                    fi
                    show_task "$1"
                    ;;
                edit)
                    if [[ $# -eq 0 ]]; then  
                        echo "Error: Task name required" >&2  
                        echo "Usage: $SCRIPT_NAME tasks edit <name>" >&2
                        exit 1  
                    fi
                    edit_task "$1"
                    ;;
                *)  
                    echo "Error: Unknown tasks subcommand: '$subcmd'" >&2  
                    show_quick_help_tasks  
                    exit 1  
                    ;;  
            esac
        fi
        exit 0
        ;;
    find-project-root)
        find_project_root
        exit $?
        ;;
    help)
        if [[ -z "$1" ]]; then
            show_help
            exit 0
        fi
        # Dispatch subcommand help functions
        case "$1" in
            init) show_help_init ;;
            new) show_help_new ;;
            edit) show_help_edit ;;
            config) show_help_config ;;
            run) show_help_run ;;
            task) show_help_task ;;
            tasks) show_help_tasks ;;
            cat) show_help_cat ;;
            open) show_help_open ;;
            list) show_help_list ;;
            help) show_help ;;
            *)
                echo "Error: Unknown subcommand: $1"
                show_help
                exit 1
                ;;
        esac
        exit 0
        ;;
    --help|-h)
        show_help
        exit 0
        ;;
    --version|-v)
        echo "wireflow version $WIREFLOW_VERSION"
        exit 0
        ;;
    *)
        echo "Error: Unknown subcommand: $cmd"
        show_help
        exit 1
        ;;
esac
