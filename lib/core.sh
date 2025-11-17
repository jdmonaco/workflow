# =============================================================================
# Workflow Core Functions
# =============================================================================
# Core workflow subcommand implementations for the workflow CLI tool.
# This file is sourced by workflow.sh.
# Dependencies: lib/utils.sh, lib/config.sh, lib/edit.sh
# =============================================================================

# Source utility and config functions if not already loaded
SCRIPT_LIB_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
if ! declare -f sanitize > /dev/null; then
    source "$SCRIPT_LIB_DIR/utils.sh"
fi
if ! declare -f load_global_config > /dev/null; then
    source "$SCRIPT_LIB_DIR/config.sh"
fi
if ! declare -f edit_files > /dev/null; then
    source "$SCRIPT_LIB_DIR/edit.sh"
fi

# =============================================================================
# Init Subcommand - Initialize Project
# =============================================================================
init_project() {
    local target_dir="${1:-.}"

    # Check if already initialized
    if [[ -d "$target_dir/.workflow" ]]; then
        echo "Error: Project already initialized at $target_dir"
        echo "Found existing .workflow/ directory"
        exit 1
    fi

    # Initialize config values from global config
    load_global_config
    INHERITED_MODEL="$MODEL"
    INHERITED_TEMPERATURE="$TEMPERATURE"
    INHERITED_MAX_TOKENS="$MAX_TOKENS"
    INHERITED_OUTPUT_FORMAT="$OUTPUT_FORMAT"
    INHERITED_SYSTEM_PROMPTS="${SYSTEM_PROMPTS[*]}"
    INHERITED_SOURCE="global config"

    # Check for parent project (overrides global if nested)
    PARENT_ROOT=$(cd "$target_dir" && find_project_root 2>/dev/null) || true
    if [[ -n "$PARENT_ROOT" ]]; then
        echo "Initializing nested project inside existing project at:"
        echo "  $PARENT_ROOT"
        echo ""
        echo "This will:"
        echo "  - Create a separate workflow namespace"
        echo "  - Inherit configuration defaults from parent"
        read -p "Continue? [y/N] " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

        echo ""
        echo "Inheriting configuration from parent..."
        INHERITED_SOURCE="parent project"

        # Extract config from parent (overrides global)
        while IFS='=' read -r key value; do
            case "$key" in
                MODEL)
                    # Only override if parent has explicit non-empty value
                    [[ -n "$value" ]] && INHERITED_MODEL="$value"
                    ;;
                TEMPERATURE)
                    [[ -n "$value" ]] && INHERITED_TEMPERATURE="$value"
                    ;;
                MAX_TOKENS)
                    [[ -n "$value" ]] && INHERITED_MAX_TOKENS="$value"
                    ;;
                OUTPUT_FORMAT)
                    [[ -n "$value" ]] && INHERITED_OUTPUT_FORMAT="$value"
                    ;;
                SYSTEM_PROMPTS)
                    [[ -n "$value" ]] && INHERITED_SYSTEM_PROMPTS="$value"
                    ;;
            esac
        done < <(extract_config "$PARENT_ROOT/.workflow/config")
    fi

    # Display inherited configuration
    echo "Configuration inherited from $INHERITED_SOURCE:"
    echo "  MODEL: $INHERITED_MODEL"
    echo "  TEMPERATURE: $INHERITED_TEMPERATURE"
    echo "  MAX_TOKENS: $INHERITED_MAX_TOKENS"
    echo "  SYSTEM_PROMPTS: $INHERITED_SYSTEM_PROMPTS"
    echo "  OUTPUT_FORMAT: $INHERITED_OUTPUT_FORMAT"
    echo ""

    # Create .workflow structure
    mkdir -p "$target_dir/.workflow/prompts"
    mkdir -p "$target_dir/.workflow/output"

    # Create config file with transparent pass-through
    # Note: Both top-level and nested projects use empty values for pass-through
    # The INHERITED_* values show what the parent had, but we pass through for transparency
    local parent_note=""
    [[ -n "$PARENT_ROOT" ]] && parent_note="# Nested under parent project: $PARENT_ROOT"$'\n'

    cat > "$target_dir/.workflow/config" <<CONFIG_EOF
# Project-level workflow configuration
${parent_note}
# API Configuration
# Leave values empty to use global defaults, or set explicit values to override.
#
# Current inherited defaults:
#   MODEL: $INHERITED_MODEL
#   TEMPERATURE: $INHERITED_TEMPERATURE
#   MAX_TOKENS: $INHERITED_MAX_TOKENS
#   SYSTEM_PROMPTS: $INHERITED_SYSTEM_PROMPTS
#   OUTPUT_FORMAT: $INHERITED_OUTPUT_FORMAT
#
# To use inherited defaults (recommended):
MODEL=
TEMPERATURE=
MAX_TOKENS=
SYSTEM_PROMPTS=()
OUTPUT_FORMAT=
CONFIG_EOF

    # Create empty project description file
    touch "$target_dir/.workflow/project.txt"

    echo "Initialized workflow project: $target_dir/.workflow/"
    echo "Created:"
    echo "  $target_dir/.workflow/config"
    echo "  $target_dir/.workflow/project.txt"
    echo "  $target_dir/.workflow/prompts/"
    echo "  $target_dir/.workflow/output/"
    echo ""
    echo "Opening project description and config in editor..."

    # Open both files for interactive editing
    edit_files "$target_dir/.workflow/project.txt" "$target_dir/.workflow/config"

    target_dir_abs=$(cd "$target_dir" && pwd)

    echo ""
    echo "Next steps:"
    echo "  1. cd $target_dir_abs"
    echo "  2. workflow new WORKFLOW_NAME"
}

# =============================================================================
# New Subcommand - Create Workflow
# =============================================================================
new_workflow() {
    local workflow_name="$1"

    if [[ -z "$workflow_name" ]]; then
        echo "Error: Workflow name required"
        echo "Usage: workflow new NAME"
        exit 1
    fi

    # Find project root
    PROJECT_ROOT=$(find_project_root) || {
        echo "Error: Not in workflow project (no .workflow/ directory found)"
        echo "Run 'workflow init' to initialize a project first"
        exit 1
    }

    WORKFLOW_DIR="$PROJECT_ROOT/.workflow/$workflow_name"

    # Check if workflow already exists
    if [[ -d "$WORKFLOW_DIR" ]]; then
        echo "Error: Workflow '$workflow_name' already exists"
        exit 1
    fi

    # Create workflow directory
    mkdir -p "$WORKFLOW_DIR"

    # Create empty task file
    touch "$WORKFLOW_DIR/task.txt"

    # Create workflow config file
    cat > "$WORKFLOW_DIR/config" <<WORKFLOW_CONFIG_EOF
# Workflow-specific configuration
# These values override project defaults from .workflow/config

# Context aggregation methods (uncomment and configure as needed):
# Note: Paths in CONTEXT_PATTERN and CONTEXT_FILES are relative to project root

# Method 1: Glob pattern (single pattern, supports brace expansion)
# CONTEXT_PATTERN="References/*.md"
# CONTEXT_PATTERN="References/{Topic1,Topic2}/*.md"

# Method 2: Explicit file list
# CONTEXT_FILES=(
#     "References/doc1.md"
#     "References/doc2.md"
# )

# Method 3: Workflow dependencies
# DEPENDS_ON=(
#     "00-workshop-context"
#     "01-outline-draft"
# )

# API overrides (leave empty to inherit from project/global defaults)
# Leave empty to inherit (recommended):
MODEL=
TEMPERATURE=
MAX_TOKENS=
SYSTEM_PROMPTS=()
OUTPUT_FORMAT=
WORKFLOW_CONFIG_EOF

    echo "Created workflow: $workflow_name"
    echo "  $WORKFLOW_DIR/task.txt"
    echo "  $WORKFLOW_DIR/config"
    echo ""
    echo "Opening task and config files in editor..."

    # Open both files for interactive editing
    edit_files "$WORKFLOW_DIR/task.txt" "$WORKFLOW_DIR/config"
}

# =============================================================================
# Edit Subcommand - Edit Existing Workflow
# =============================================================================
edit_workflow() {
    local workflow_name="$1"

    # Find project root
    PROJECT_ROOT=$(find_project_root) || {
        echo "Error: Not in workflow project (no .workflow/ directory found)"
        echo "Run 'workflow init' to initialize a project first"
        exit 1
    }

    # If no workflow name provided, edit project files
    if [[ -z "$workflow_name" ]]; then
        echo "Editing project configuration..."
        edit_files "$PROJECT_ROOT/.workflow/project.txt" "$PROJECT_ROOT/.workflow/config"
        return 0
    fi

    # Otherwise, edit workflow files
    WORKFLOW_DIR="$PROJECT_ROOT/.workflow/$workflow_name"

    # Check if workflow exists
    if [[ ! -d "$WORKFLOW_DIR" ]]; then
        echo "Error: Workflow '$workflow_name' not found"
        echo "Available workflows:"
        if list_workflows; then
            list_workflows | sed 's/^/  /'
        else
            echo "  (none)"
        fi
        echo ""
        echo "Create new workflow with: workflow new $workflow_name"
        exit 1
    fi

    echo "Editing workflow: $workflow_name"

    # Check for output file and include it first if it exists
    local files_to_edit=()
    local output_file
    # Output file is at .workflow/output/<workflow_name>.*
    output_file=$(find "$PROJECT_ROOT/.workflow/output" -maxdepth 1 -type f -name "${workflow_name}.*" 2>/dev/null | head -1)
    if [[ -n "$output_file" ]]; then
        files_to_edit+=("$output_file")
    fi

    # Add task and config
    files_to_edit+=("$WORKFLOW_DIR/task.txt" "$WORKFLOW_DIR/config")

    edit_files "${files_to_edit[@]}"
}

# =============================================================================
# List Subcommand - List All Workflows
# =============================================================================
list_workflows_cmd() {
    # Find project root
    PROJECT_ROOT=$(find_project_root) || {
        echo "Error: Not in workflow project (no .workflow/ directory found)"
        echo "Run 'workflow init' to initialize a project first"
        exit 1
    }

    echo "Workflows in $PROJECT_ROOT:"
    echo ""

    # Capture workflow list to avoid calling list_workflows twice
    local workflow_list
    workflow_list=$(list_workflows) || true

    if [[ -n "$workflow_list" ]]; then
        echo "$workflow_list" | while read -r workflow; do
            # Check if workflow has required files
            local status=""
            if [[ ! -f "$PROJECT_ROOT/.workflow/$workflow/task.txt" ]]; then
                status=" [incomplete - missing task.txt]"
            elif [[ ! -f "$PROJECT_ROOT/.workflow/$workflow/config" ]]; then
                status=" [incomplete - missing config]"
            else
                # Check for output file
                local output_file=$(ls "$PROJECT_ROOT/.workflow/output/$workflow".* 2>/dev/null | head -1)
                if [[ -n "$output_file" ]]; then
                    # Get modification time (cross-platform)
                    local output_time
                    if [[ "$(uname)" == "Darwin" ]]; then
                        output_time=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$output_file" 2>/dev/null)
                    else
                        output_time=$(stat -c "%y" "$output_file" 2>/dev/null | cut -d'.' -f1)
                    fi
                    [[ -n "$output_time" ]] && status=" [last run: $output_time]"
                fi
            fi
            echo "  $workflow$status"
        done
    else
        echo "  (no workflows found)"
        echo ""
        echo "Create a new workflow with: workflow new NAME"
    fi

    echo ""
}

# =============================================================================
# Cat Subcommand - Display Workflow Output
# =============================================================================

cat_workflow() {
    local workflow_name="$1"

    # Find project root
    PROJECT_ROOT=$(find_project_root) || {
        echo "Error: Not in workflow project (no .workflow/ directory found)" >&2
        echo "Run 'workflow init' to initialize a project" >&2
        exit 1
    }

    # Find output file in .workflow/output/
    local output_file
    output_file=$(find "$PROJECT_ROOT/.workflow/output" -maxdepth 1 -type f -name "${workflow_name}.*" 2>/dev/null | head -1)

    if [[ -z "$output_file" ]]; then
        echo "Error: No output found for workflow: $workflow_name" >&2
        echo "Available workflows:" >&2
        if list_workflows; then
            list_workflows | sed 's/^/  /' >&2
        else
            echo "  (none)" >&2
        fi
        echo "" >&2
        echo "Run the workflow first: workflow run $workflow_name" >&2
        exit 1
    fi

    # Output to stdout
    cat "$output_file"
}

# =============================================================================
# Open Subcommand - Open Workflow Output in Default Application
# =============================================================================

open_workflow() {
    local workflow_name="$1"

    # Find project root
    PROJECT_ROOT=$(find_project_root) || {
        echo "Error: Not in workflow project (no .workflow/ directory found)" >&2
        echo "Run 'workflow init' to initialize a project" >&2
        exit 1
    }

    # Find output file in .workflow/output/
    local output_file
    output_file=$(find "$PROJECT_ROOT/.workflow/output" -maxdepth 1 -type f -name "${workflow_name}.*" 2>/dev/null | head -1)

    if [[ -z "$output_file" ]]; then
        echo "Error: No output found for workflow: $workflow_name" >&2
        echo "Available workflows:" >&2
        if list_workflows; then
            list_workflows | sed 's/^/  /' >&2
        else
            echo "  (none)" >&2
        fi
        echo "" >&2
        echo "Run the workflow first: workflow run $workflow_name" >&2
        exit 1
    fi

    # Check if open command exists (macOS)
    if ! command -v open >/dev/null 2>&1; then
        echo "Error: 'open' command not found (macOS only)" >&2
        echo "Use 'workflow cat $workflow_name' to view output instead" >&2
        exit 1
    fi

    # Open with system default application
    echo "Opening: $output_file"
    open "$output_file"
}

# =============================================================================
# Config Subcommand - Display and Edit Configuration
# =============================================================================

# Display project-level configuration with option to edit
config_project() {
    local no_edit="${1:-false}"

    # Find project root
    PROJECT_ROOT=$(find_project_root) || {
        echo "Error: Not in workflow project (no .workflow/ directory found)"
        echo "Run 'workflow init' to initialize a project first"
        exit 1
    }

    echo "Project Configuration"
    echo "  Location: $PROJECT_ROOT/.workflow"
    echo ""

    # Load config values with source tracking
    declare -A CONFIG_VALUE
    declare -A CONFIG_SOURCE

    # Tier 1: Load global config
    load_global_config
    CONFIG_VALUE[MODEL]="$MODEL"
    CONFIG_VALUE[TEMPERATURE]="$TEMPERATURE"
    CONFIG_VALUE[MAX_TOKENS]="$MAX_TOKENS"
    CONFIG_VALUE[OUTPUT_FORMAT]="$OUTPUT_FORMAT"
    CONFIG_VALUE[SYSTEM_PROMPTS]="${SYSTEM_PROMPTS[*]}"
    CONFIG_SOURCE[MODEL]="global"
    CONFIG_SOURCE[TEMPERATURE]="global"
    CONFIG_SOURCE[MAX_TOKENS]="global"
    CONFIG_SOURCE[OUTPUT_FORMAT]="global"
    CONFIG_SOURCE[SYSTEM_PROMPTS]="global"

    # Tier 2: Override with project config if exists and values are non-empty
    if [[ -f "$PROJECT_ROOT/.workflow/config" ]]; then
        while IFS='=' read -r key value; do
            case "$key" in
                MODEL|TEMPERATURE|MAX_TOKENS|OUTPUT_FORMAT|SYSTEM_PROMPTS)
                    if [[ -n "$value" ]]; then
                        CONFIG_VALUE[$key]="$value"
                        CONFIG_SOURCE[$key]="project"
                    fi
                    ;;
            esac
        done < <(extract_config "$PROJECT_ROOT/.workflow/config")
    fi

    # Display configuration cascade
    echo "Configuration Cascade:"
    echo "  Global:  $GLOBAL_CONFIG_FILE"
    echo "  Project: .workflow/config"
    echo ""
    echo "Effective Configuration:"
    echo "  MODEL: ${CONFIG_VALUE[MODEL]} (${CONFIG_SOURCE[MODEL]})"
    echo "  TEMPERATURE: ${CONFIG_VALUE[TEMPERATURE]} (${CONFIG_SOURCE[TEMPERATURE]})"
    echo "  MAX_TOKENS: ${CONFIG_VALUE[MAX_TOKENS]} (${CONFIG_SOURCE[MAX_TOKENS]})"
    echo "  SYSTEM_PROMPTS: ${CONFIG_VALUE[SYSTEM_PROMPTS]} (${CONFIG_SOURCE[SYSTEM_PROMPTS]})"
    echo "  OUTPUT_FORMAT: ${CONFIG_VALUE[OUTPUT_FORMAT]} (${CONFIG_SOURCE[OUTPUT_FORMAT]})"
    echo ""

    # Show workflows
    echo "Workflows:"
    local workflow_list
    workflow_list=$(list_workflows) || true

    if [[ -n "$workflow_list" ]]; then
        echo "$workflow_list" | while read -r workflow; do
            # Check for output file to show status
            local output_file=$(ls "$PROJECT_ROOT/.workflow/output/$workflow".* 2>/dev/null | head -1)
            if [[ -n "$output_file" ]]; then
                local output_time
                if [[ "$(uname)" == "Darwin" ]]; then
                    output_time=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$output_file" 2>/dev/null)
                else
                    output_time=$(stat -c "%y" "$output_file" 2>/dev/null | cut -d'.' -f1)
                fi
                [[ -n "$output_time" ]] && echo "  $workflow [last run: $output_time]" || echo "  $workflow"
            else
                echo "  $workflow"
            fi
        done
    else
        echo "  (no workflows found)"
    fi
    echo ""

    # Interactive prompt to edit (unless --no-edit flag was used)
    if [[ "$no_edit" != "true" ]]; then
        read -p "Edit project configuration? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            edit_workflow  # No arguments = edit project
        fi
    fi
}

# Display workflow-specific configuration with cascade and option to edit
config_workflow() {
    local workflow_name="$1"
    local no_edit="${2:-false}"

    # Find project root
    PROJECT_ROOT=$(find_project_root) || {
        echo "Error: Not in workflow project (no .workflow/ directory found)"
        echo "Run 'workflow init' to initialize a project first"
        exit 1
    }

    WORKFLOW_DIR="$PROJECT_ROOT/.workflow/$workflow_name"

    # Check if workflow exists
    if [[ ! -d "$WORKFLOW_DIR" ]]; then
        echo "Error: Workflow '$workflow_name' not found"
        echo "Available workflows:"
        if list_workflows; then
            list_workflows | sed 's/^/  /'
        else
            echo "  (none)"
        fi
        echo ""
        echo "Create new workflow with: workflow new $workflow_name"
        exit 1
    fi

    echo "Workflow Configuration: $workflow_name"
    echo "  Location: $WORKFLOW_DIR"
    echo ""

    # Track config sources with associative arrays
    declare -A CONFIG_SOURCE
    declare -A CONFIG_VALUE

    # Tier 1: Load global config
    load_global_config
    CONFIG_VALUE[MODEL]="$MODEL"
    CONFIG_VALUE[TEMPERATURE]="$TEMPERATURE"
    CONFIG_VALUE[MAX_TOKENS]="$MAX_TOKENS"
    CONFIG_VALUE[OUTPUT_FORMAT]="$OUTPUT_FORMAT"
    CONFIG_VALUE[SYSTEM_PROMPTS]="${SYSTEM_PROMPTS[*]}"
    CONFIG_SOURCE[MODEL]="global"
    CONFIG_SOURCE[TEMPERATURE]="global"
    CONFIG_SOURCE[MAX_TOKENS]="global"
    CONFIG_SOURCE[OUTPUT_FORMAT]="global"
    CONFIG_SOURCE[SYSTEM_PROMPTS]="global"

    # Tier 2: Project config
    if [[ -f "$PROJECT_ROOT/.workflow/config" ]]; then
        while IFS='=' read -r key value; do
            if [[ -n "$value" ]]; then
                case "$key" in
                    MODEL|TEMPERATURE|MAX_TOKENS|OUTPUT_FORMAT|SYSTEM_PROMPTS)
                        CONFIG_VALUE[$key]="$value"
                        CONFIG_SOURCE[$key]="project"
                        ;;
                esac
            fi
        done < <(extract_config "$PROJECT_ROOT/.workflow/config")
    fi

    # Tier 3: Workflow config
    CONTEXT_PATTERN=""
    CONTEXT_FILES_STR=""
    DEPENDS_ON_STR=""

    if [[ -f "$WORKFLOW_DIR/config" ]]; then
        while IFS='=' read -r key value; do
            if [[ -n "$value" ]]; then
                case "$key" in
                    MODEL|TEMPERATURE|MAX_TOKENS|OUTPUT_FORMAT|SYSTEM_PROMPTS)
                        CONFIG_VALUE[$key]="$value"
                        CONFIG_SOURCE[$key]="workflow"
                        ;;
                    CONTEXT_PATTERN)
                        CONTEXT_PATTERN="$value"
                        ;;
                    CONTEXT_FILES)
                        CONTEXT_FILES_STR="$value"
                        ;;
                    DEPENDS_ON)
                        DEPENDS_ON_STR="$value"
                        ;;
                esac
            fi
        done < <(extract_config "$WORKFLOW_DIR/config")
    fi

    # Display configuration cascade
    echo "Configuration Cascade:"
    echo "  Global:   $GLOBAL_CONFIG_FILE"
    echo "  Project:  .workflow/config"
    echo "  Workflow: .workflow/$workflow_name/config"
    echo ""
    echo "Effective Configuration:"
    echo "  MODEL: ${CONFIG_VALUE[MODEL]} (${CONFIG_SOURCE[MODEL]})"
    echo "  TEMPERATURE: ${CONFIG_VALUE[TEMPERATURE]} (${CONFIG_SOURCE[TEMPERATURE]})"
    echo "  MAX_TOKENS: ${CONFIG_VALUE[MAX_TOKENS]} (${CONFIG_SOURCE[MAX_TOKENS]})"
    echo "  SYSTEM_PROMPTS: ${CONFIG_VALUE[SYSTEM_PROMPTS]} (${CONFIG_SOURCE[SYSTEM_PROMPTS]})"
    echo "  OUTPUT_FORMAT: ${CONFIG_VALUE[OUTPUT_FORMAT]} (${CONFIG_SOURCE[OUTPUT_FORMAT]})"
    echo ""

    # Display context sources if any are configured
    if [[ -n "$CONTEXT_PATTERN" || -n "$CONTEXT_FILES_STR" || -n "$DEPENDS_ON_STR" ]]; then
        echo "Context Sources:"
        [[ -n "$CONTEXT_PATTERN" ]] && echo "  CONTEXT_PATTERN: $CONTEXT_PATTERN"
        [[ -n "$CONTEXT_FILES_STR" ]] && echo "  CONTEXT_FILES: $CONTEXT_FILES_STR"
        [[ -n "$DEPENDS_ON_STR" ]] && echo "  DEPENDS_ON: $DEPENDS_ON_STR"
        echo ""
    fi

    # Interactive prompt to edit (unless --no-edit flag was used)
    if [[ "$no_edit" != "true" ]]; then
        read -p "Edit workflow '$workflow_name'? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            edit_workflow "$workflow_name"
        fi
    fi
}
