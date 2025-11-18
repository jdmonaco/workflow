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

    # Check for parent project
    PARENT_ROOT=$(cd "$target_dir" && find_project_root 2>/dev/null) || true
    if [[ -n "$PARENT_ROOT" ]]; then
        echo "Initializing nested project inside existing project at:"
        echo "  $PARENT_ROOT"
        echo ""
        echo "This will:"
        echo "  - Create a separate workflow namespace"
        echo "  - Inherit configuration from full ancestor cascade"
        echo "  - Use 'workflow config' to see effective configuration"
        read -p "Continue? [y/N] " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
        echo ""
    fi

    # Create .workflow structure
    mkdir -p "$target_dir/.workflow/prompts"
    mkdir -p "$target_dir/.workflow/output"

    # Create config file with transparent pass-through
    local parent_note=""
    [[ -n "$PARENT_ROOT" ]] && parent_note="# Nested under parent project: $PARENT_ROOT"$'\n'

    cat > "$target_dir/.workflow/config" <<CONFIG_EOF
# Project-level workflow configuration
${parent_note}
# Configuration cascade: global → ancestor projects → this project → workflow
# Leave values empty to inherit from cascade, or set explicit values to override.
#
# Run 'workflow config' to see current effective configuration.
#
# API Configuration (leave empty to inherit, recommended):
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
# Configuration cascade: global → ancestor projects → project → this workflow
#
# Run 'workflow config <name>' to see current effective configuration.

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

# API overrides (leave empty to inherit from cascade, recommended):
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

# Format config source for display (converts path to relative from HOME, or shows label)
# Args: $1 = source (can be "global", "workflow", or a path)
format_config_source() {
    local source="$1"

    if [[ "$source" == "global" || "$source" == "workflow" ]]; then
        echo "$source"
    elif [[ "$source" =~ ^/ ]]; then
        # It's a path - make it relative to HOME
        local rel_path="${source#$HOME/}"
        if [[ "$rel_path" == "$source" ]]; then
            # Not under HOME, use basename
            echo "ancestor:$(basename "$source")"
        else
            echo "ancestor:$rel_path"
        fi
    else
        echo "$source"
    fi
}

# Display project-level configuration with option to edit
config_project() {
    local edit_mode="${1:-false}"

    # Find project root
    PROJECT_ROOT=$(find_project_root) || {
        echo "Error: Not in workflow project (no .workflow/ directory found)"
        echo "Run 'workflow init' to initialize a project first"
        exit 1
    }

    # Format and display header
    local project_display
    project_display=$(format_path_with_tilde "$PROJECT_ROOT")

    echo "Current Project:"
    echo "  Location: $project_display"
    echo ""

    # Load configuration cascade (Tiers 1-3: global → ancestors → project)
    load_project_config_tiers "$PROJECT_ROOT"

    # Display configuration cascade hierarchy
    local global_display
    global_display=$(format_path_with_tilde "$GLOBAL_CONFIG_FILE")
    display_config_cascade_hierarchy "$global_display" "$PROJECT_ROOT"

    # Display effective configuration values with sources
    display_effective_config_values

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

    # Interactive prompt to edit (only if --edit flag was used)
    if [[ "$edit_mode" == "true" ]]; then
        read -p "Press Enter to edit project configuration (or Ctrl+C to cancel): " -r
        echo ""
        edit_workflow  # No arguments = edit project
    fi
}

# Display workflow-specific configuration with cascade and option to edit
config_workflow() {
    local workflow_name="$1"
    local edit_mode="${2:-false}"

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

    # Format and display header
    local workflow_display
    workflow_display=$(format_path_with_tilde "$WORKFLOW_DIR")

    echo "Current Workflow:"
    echo "  Name: $workflow_name"
    echo "  Location: $workflow_display"
    echo ""

    # Load configuration cascade (Tiers 1-3: global → ancestors → project)
    load_project_config_tiers "$PROJECT_ROOT"

    # Tier 4: Workflow config
    CONTEXT_PATTERN=""
    CONTEXT_FILES_STR=""
    DEPENDS_ON_STR=""

    if [[ -f "$WORKFLOW_DIR/config" ]]; then
        while IFS='=' read -r key value; do
            [[ -z "$value" ]] && continue
            case "$key" in
                MODEL|TEMPERATURE|MAX_TOKENS|OUTPUT_FORMAT)
                    eval "$key=\"$value\""
                    CONFIG_SOURCE_MAP[$key]="workflow"
                    ;;
                SYSTEM_PROMPTS)
                    SYSTEM_PROMPTS=($value)
                    CONFIG_SOURCE_MAP[SYSTEM_PROMPTS]="workflow"
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
        done < <(extract_config "$WORKFLOW_DIR/config")
    fi

    # Update final values after workflow config
    CONFIG_VALUE[MODEL]="$MODEL"
    CONFIG_VALUE[TEMPERATURE]="$TEMPERATURE"
    CONFIG_VALUE[MAX_TOKENS]="$MAX_TOKENS"
    CONFIG_VALUE[OUTPUT_FORMAT]="$OUTPUT_FORMAT"
    CONFIG_VALUE[SYSTEM_PROMPTS]="${SYSTEM_PROMPTS[*]}"

    # Display configuration cascade hierarchy (with workflow tier)
    local global_display
    global_display=$(format_path_with_tilde "$GLOBAL_CONFIG_FILE")
    display_config_cascade_hierarchy "$global_display" "$PROJECT_ROOT" "$WORKFLOW_DIR"

    # Display effective configuration values with sources
    display_effective_config_values

    # Display context sources if any are configured
    if [[ -n "$CONTEXT_PATTERN" || -n "$CONTEXT_FILES_STR" || -n "$DEPENDS_ON_STR" ]]; then
        echo "Context Sources:"
        [[ -n "$CONTEXT_PATTERN" ]] && echo "  CONTEXT_PATTERN: $CONTEXT_PATTERN"
        [[ -n "$CONTEXT_FILES_STR" ]] && echo "  CONTEXT_FILES: $CONTEXT_FILES_STR"
        [[ -n "$DEPENDS_ON_STR" ]] && echo "  DEPENDS_ON: $DEPENDS_ON_STR"
        echo ""
    fi

    # Interactive prompt to edit (only if --edit flag was used)
    if [[ "$edit_mode" == "true" ]]; then
        read -p "Press Enter to edit workflow (or Ctrl+C to cancel): " -r
        echo ""
        edit_workflow "$workflow_name"
    fi
}
