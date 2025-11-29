# =============================================================================
# Workflow Core Functions
# =============================================================================
# Core workflow subcommand implementations for the workflow CLI tool.
# Dependencies: lib/utils.sh, lib/config.sh, lib/edit.sh
# =============================================================================

# Source utility functions if not already loaded
SCRIPT_LIB_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
if ! declare -f edit_files > /dev/null; then
    source "$SCRIPT_LIB_DIR/edit.sh"
fi

# =============================================================================
# Init Subcommand - Initialize Project
# =============================================================================
init_project() {
    local dir
    dir="$(absolute_path "${1:-$(pwd)}")"

    # Check if inside an existing wireflow directory
    if [[ "$dir" =~ /\.workflow(/|$) ]]; then
        echo "Error: Can't initialize inside a wireflow directory" >&2
        echo "Current project root: $(display_absolute_path "${dir%\/.workflow*}")" >&2
        exit 1
    fi

    # Check if project exists and obtain consent to reset config
    if [[ -d "$dir/.workflow" ]]; then
        echo "Warning: A project already exists at:"
        echo "  $(display_absolute_path "$dir")"
        echo ""
        echo "Continuing will:"
        echo "  - Preserve existing project description file"
        echo "  - Reset the project configuration by:"
        echo "      1. Backing up existing project config file"
        echo "      2. Creating a new default config file"
        echo ""
        prompt_to_continue_or_exit "Reset project config?"
    fi

    # Check for parent and obtain consent to create a nested project
    local parent_dir="$(dirname "$dir")"
    local parent_root=""
    if [[ -d "$parent_dir" ]]; then
        parent_root=$(cd "$parent_dir" && find_project_root 2>/dev/null) || true
    fi
    if [[ -n "$parent_root" ]]; then
        echo "Warning: Found a parent project located at:"
        echo "  $(display_absolute_path "$parent_root")"
        echo ""
        echo "Continuing will:"
        echo "  - Create a nested project with a separate workflow namespace"
        echo "  - Pass through config settings from the parent project"
        echo ""
        prompt_to_continue_or_exit "Use '$SCRIPT_NAME config' to see effective configuration."
    fi

    # Set directory paths
    local project_dir="$dir"
    local wireflow_dir="$project_dir/.workflow"

    # Create initial project config with cascade pass-through by default
    mkdir -p "$wireflow_dir"
    local project_config="$wireflow_dir/config"
    if [[ -e "$project_config" ]]; then
        mv "$project_config" "${project_config}.bak" &>/dev/null || {
            echo "Error: Failed to backup project config" >&2
            echo "Exiting..." >&2
            exit 1
        }
        echo "Backed up previous config:"
        echo "  $(display_normalized_path "${project_config}.bak")"
        echo ""
    fi

    # Write the project config header
    cat > "$project_config" <<CONFIG_EOF
# Project-level wireflow configuration
#
# Leave values empty to inherit from parent levels.
# Run 'wfw config' to view effective configuration.

# ============================================================================
# Configuration Parameters
# ============================================================================

CONFIG_EOF

    # Write default project settings (empty) to the config file
    cat_default_project_config >> "$project_config"

    # Write the project config footer, with explanatory usage details
    cat >> "$project_config" <<CONFIG_EOF

# ============================================================================
# Configuration Guide
# ============================================================================
#
# Configuration Cascade:
#   builtin defaults → global config → project config → workflow config → CLI
#
# Scalar Variables (most settings):
#   Leave EMPTY to inherit:        MODEL=
#   Set VALUE to override:         MODEL=claude-opus-4
#
# Array Variables (SYSTEM_PROMPTS, CONTEXT):
# ┌────────────────────────┬─────────────────────────────────────┐
# │ Syntax                 │ Behavior                            │
# ├────────────────────────┼─────────────────────────────────────┤
# │ CONTEXT=               │ Inherit from parent (pass-through)  │
# │ CONTEXT=()             │ Clear (reset to empty)              │
# │ CONTEXT=(file.pdf)     │ Replace (override parent)           │
# │ CONTEXT+=(add.pdf)     │ Append (add to project)             │
# └────────────────────────┴─────────────────────────────────────┘
#
# Glob patterns expand at config source time (from project root):
#   CONTEXT=(data/*.csv notes.md docs/**/*.pdf)
#
# Filenames with spaces require quotes:
#   CONTEXT=(
#       "references/first paper.pdf"
#       "data/experiment results.csv"
#   )
#
# Examples:
#   # Override model for this project
#   MODEL=claude-opus-4
#
#   # Set project-specific prompts
#   SYSTEM_PROMPTS=(base neuroai-research)
#
#   # Add project context files
#   CONTEXT=(
#       project-background.md
#       related-work.pdf
#       data/*.csv
#   )
CONFIG_EOF

    # Ensure project description file exists
    local project_file="$wireflow_dir/project.txt"
    touch "$project_file"

    # Create cache directory structure for file conversions
    local cache_dir="$wireflow_dir/cache"
    mkdir -p "$cache_dir/conversions/office"
    mkdir -p "$cache_dir/conversions/images"

    # Display summary report
    echo "Initialized project:"
    echo "  Project root:    $(display_absolute_path "$project_dir")"
    echo "  Wireflow folder: $(display_absolute_path "$wireflow_dir")"
    echo "  Config file:     $(display_absolute_path "$project_config")"
    echo "  Project file:    $(display_absolute_path "$project_file")"
    echo ""
    echo "Run '$SCRIPT_NAME edit' to setup the project."
}

# =============================================================================
# New Subcommand - Create Workflow
# =============================================================================
new_workflow() {
    local name="${1:-$WORKFLOW_NAME}"
    local workflow_dir="${2:-$WORKFLOW_DIR}"
    local from_task="${3:-$NEW_FROM_TASK}"
    local project_root="${4:-$PROJECT_ROOT}"

    # Check if workflow exists and obtain consent to reset config
    if [[ -d "$workflow_dir" ]]; then
        echo "Warning: Workflow already exists at:"
        echo "  $(display_absolute_path "$workflow_dir")"
        echo ""
        echo "Continuing will:"
        echo "  - Preserve existing workflow task file"
        echo "  - Reset the workflow configuration by:"
        echo "      1. Backing up existing workflow config file"
        echo "      2. Creating a new default config file"
        echo ""
        prompt_to_continue_or_exit "Reset workflow config?"
    fi

    # Create the workflow directory if needed
    mkdir -p "$workflow_dir"
    if [[ ! -d "$workflow_dir" ]]; then
        echo "Error: Failed to create workflow directory:" >&2
        echo "  $(display_absolute_path "$workflow_dir")" >&2
        exit 1
    fi

    # Set workflow files paths
    local config_file="$workflow_dir/config"
    local task_file="$workflow_dir/task.txt"

    # Create task file from specified task template
    if [[ -n "$from_task" ]]; then
        local template_task_file="$WIREFLOW_TASK_PREFIX/${from_task}.txt"
        local builtin_task_file="$BUILTIN_WIREFLOW_TASK_PREFIX/${from_task}.txt"
        local checked_builtin=false
        local resolved_task_file

        if [[ -f "$template_task_file" && -s "$template_task_file" ]]; then
            resolved_task_file="$template_task_file"
        elif [[ "$template_task_file" != "$builtin_task_file" ]] && \
             [[ -f "$builtin_task_file" && -s "$builtin_task_file" ]]; then
            resolved_task_file="$builtin_task_file"
            checked_builtin=true
        fi

        if [[ -z "$resolved_task_file" ]]; then
            echo "Error: Task template '$from_task' not found. Searched:" >&2
            echo "  $(display_absolute_path "$WIREFLOW_TASK_PREFIX")" >&2
            if [[ "$checked_builtin" == "true" ]]; then
                echo "  $(display_absolute_path "$BUILTIN_WIREFLOW_TASK_PREFIX") (builtin)" >&2
            fi
            echo "" >&2
            echo "Run '$SCRIPT_NAME tasks' to list available task templates." >&2
            echo "Run '$SCRIPT_NAME --version' to create the default templates." >&2
            exit 1
        fi

        # Copy template to workflow directory as initial task file
        cp "$resolved_task_file" "$task_file" 2>/dev/null || {
            echo "Error: Failed to copy template task file" >&2
            exit 1
        }
    fi

    # Create task file with default skeleton, if needed
    if [[ -f "$task_file" && -s "$task_file" ]]; then
        echo "Found task file:"
        echo "  $(display_normalized_path "$task_file")"
        echo ""
    else
        cat > "$task_file" <<TASK_SKELETON_EOF
<user-task>
  <metadata>
    <name>$name</name>
    <version>1.0</version>
  </metadata>
  <content>
    <description>
      Brief 1-2 sentence overview of this workflow's purpose
    </description>
    <guidance>
      High-level strategic guidance for approaching this task
    </guidance>
    <instructions>
      Detailed step-by-step instructions or requirements
    </instructions>
    <output-format>
      Specific formatting requirements or structure for the output
    </output-format>
  </content>
</user-task>
TASK_SKELETON_EOF
    fi

    # Backup existing workflow config if it exists
    if [[ -e "$config_file" ]]; then
        mv "$config_file" "${config_file}.bak" &>/dev/null || {
            echo "Error: Failed to backup workflow config" >&2
            echo "Exiting..." >&2
            exit 1
        }
        echo "Backed up previous config:"
        echo "  $(display_normalized_path "${config_file}.bak")"
        echo ""
    fi

    # Write default workflow config file header
    cat > "$config_file" <<WORKFLOW_CONFIG_EOF
# Workflow configuration for: $name
#
# Leave values empty to inherit from project.
# Run 'wfw config $name' to view effective configuration.

# ============================================================================
# Configuration Parameters
# ============================================================================

WORKFLOW_CONFIG_EOF

    # Write default workflow settings (empty) to the config file
    cat_default_workflow_config >> "$config_file"

    # Write default workflow config file footer, with explanatory details
    cat >> "$config_file" <<WORKFLOW_CONFIG_EOF

# ============================================================================
# Configuration Guide
# ============================================================================
#
# Configuration Cascade:
#   builtin → global → project → workflow → CLI (you are here: workflow)
#
# Scalar Variables (most settings):
#   Leave EMPTY to inherit:        TEMPERATURE=
#   Set VALUE to override:         TEMPERATURE=0.7
#
# Array Variables (SYSTEM_PROMPTS, CONTEXT, INPUT, DEPENDS_ON):
# ┌────────────────────────┬─────────────────────────────────────┐
# │ Syntax                 │ Behavior                            │
# ├────────────────────────┼─────────────────────────────────────┤
# │ CONTEXT=               │ Inherit from project (pass-through) │
# │ CONTEXT=()             │ Clear (reset to empty)              │
# │ CONTEXT=(file.pdf)     │ Replace (override project)          │
# │ CONTEXT+=(add.pdf)     │ Append (add to project)             │
# └────────────────────────┴─────────────────────────────────────┘
#
# Glob patterns expand at config source time (from project root):
#   INPUT=(reports/*.pdf data/*.csv)
#
# Filenames with spaces require quotes:
#   INPUT=(
#       "data/input file 1.txt"
#       "data/input file 2.txt"
#   )
#
# Common Patterns:
#   # Add workflow-specific prompt to project's prompts
#   SYSTEM_PROMPTS+=(grant-writing)
#
#   # Add workflow-specific context to project's files
#   CONTEXT+=("NSF requirements.pdf")
#
#   # Use completely different files for this workflow
#   CONTEXT=(workflow-specific.md)
#
#   # Clear inherited context, start fresh
#   CONTEXT=()
WORKFLOW_CONFIG_EOF

    # Show summary report
    if [[ -n "$from_task" ]]; then
        echo "New workflow ('$name' using '$from_task' template):"
    else
        echo "New workflow ('$name'):"
    fi
    echo "  Project root:  $(display_normalized_path "$project_root")"
    echo "  Config file:   $(display_normalized_path "$config_file")"
    echo "  Task file:     $(display_normalized_path "$task_file")"
    echo ""
    echo "Run '$SCRIPT_NAME edit $name' to setup the workflow."
}

# =============================================================================
# Edit Subcommand - Edit Project or Existing Workflow
# =============================================================================
edit_project() {
    local project_root="${1:-$PROJECT_ROOT}"
    local wireflow_dir="${2:-$WIREFLOW_DIR}"

    # Show user what files will be edited before proceeding
    prompt_to_continue_or_exit "Editing project: $(display_normalized_path "$project_root")"

    # Collect the files to be edited
    local files_to_edit=("config" "project.txt")

    # Bring up the interactive editor in the wireflow directory
    (
        cd "$wireflow_dir"
        edit_files "${files_to_edit[@]}"
    )
}

edit_workflow() {
    local name="${1:-$WORKFLOW_NAME}"
    local workflow_dir="${2:-$WORKFLOW_DIR}"
    local project_root="${3:-$PROJECT_ROOT}"
    local output_dir="${4:-$OUTPUT_DIR}"

    # Show user what files will be edited before proceeding
    prompt_to_continue_or_exit "Editing workflow: '$name' (project:$(display_normalized_path "$project_root"))"

    # Collect the files to be edited
    local files_to_edit=("config" "task.txt")
    local output_file
    output_file=$(ls -1 "$output_dir/${name}.*" 2>/dev/null | head -1)
    if [[ -n "$output_file" ]]; then
        local output_path
        output_path="$(relative_path "$output_file" "$workflow_dir")"
        files_to_edit+=("$output_path")
    fi

    # Bring up the interactive editor in the workflow directory
    (
        cd "$workflow_dir"
        edit_files "${files_to_edit[@]}"
    )
}

# =============================================================================
# Config Subcommand - Display and Edit Configuration
# =============================================================================
config_project() {
    # Show project
    show_project_location && echo ""

    # Show config cascade paths report
    show_config_paths && echo ""

    # Show effective config report, with source mapping
    show_effective_config
}

config_workflow() {
    # Ensure workflow directory exists and set paths
    check_workflow_dir

    # Load the workflow-specific config
    load_workflow_config

    # Format and display header
    show_workflow_location && echo ""

    # Show config cascade paths report
    show_config_paths && echo ""

    # Show effective config report, with source mapping
    show_effective_config
}

# =============================================================================
# Run Subcommand - Dispatch to Run-Mode Execution
# =============================================================================

# Execute workflow in run mode
# Arguments:
#   $1 - Workflow name
#   $@ - Execution options
cmd_run() {
    local workflow_name="$1"
    
    if [[ -z "$workflow_name" ]]; then
        echo "Error: Workflow name required" >&2
        show_quick_help_run
        return 1
    fi
    
    shift
    
    # Workflow-specific paths
    WORKFLOW_NAME="$workflow_name"
    WORKFLOW_DIR="$RUN_DIR/$WORKFLOW_NAME"
    WORKFLOW_CONFIG="$WORKFLOW_DIR/config"
    
    # Check workflow directory exists
    if ! check_workflow_dir; then
        echo "Error: Workflow not found: '$WORKFLOW_NAME'" >&2
        echo >&2
        echo "Run '$SCRIPT_NAME list' to see available workflows." >&2
        echo "Run '$SCRIPT_NAME new $WORKFLOW_NAME' to create it." >&2
        return 1
    fi
    
    # Load workflow configuration
    if load_workflow_config; then
        echo "Loaded '$WORKFLOW_NAME' config"
    fi
    
    # Show workflow location
    show_workflow_location
    
    # Execute workflow with remaining arguments
    execute_run_mode "$@"
}

# =============================================================================
# List Subcommand - List All Workflows
# =============================================================================
cmd_list() {
    local project_root="${1:-$PROJECT_ROOT}"
    local run_root="${2:-$RUN_DIR}"
    local output_dir="${3:-$OUTPUT_DIR}"
    local indent="${4:-  }"

    # Capture workflow list to avoid calling list_workflows twice
    local workflow_list
    workflow_list=$(list_workflows) || true

    # Show workflow status report
    show_project_location
    echo ""
    echo "Workflows:"
    if [[ -n "$workflow_list" ]]; then
        echo "$workflow_list" | while read -r workflow; do
            # Check if workflow has required files
            local workflow_dir="$run_root/$workflow"
            local status=""
            local timestamp=""

            if [[ ! -f "$workflow_dir/task.txt" ]]; then
                status="[incomplete - missing task.txt]"
            elif [[ ! -f "$workflow_dir/config" ]]; then
                status="[incomplete - missing config]"
            else
                # Check for batch status first
                local batch_status
                batch_status=$(get_batch_display_status "$workflow_dir")
                if [[ -n "$batch_status" ]]; then
                    status="$batch_status"
                else
                    # Get execution timestamp and status
                    timestamp=$(get_execution_timestamp "$workflow")
                    status=$(get_execution_status "$workflow")
                fi
            fi

            # Format output with timestamp and status
            if [[ -n "$timestamp" && "$timestamp" != "(not run)" && "$timestamp" != "(unknown)" ]]; then
                printf "$indent%-14s %-16s %s\n" "$workflow" "$timestamp" "$status"
            else
                printf "$indent%-14s %-16s %s\n" "$workflow" "$timestamp" "$status"
            fi
        done
    else
        echo "$indent(no workflows found)"
        echo ""
        echo "Run '$SCRIPT_NAME new NAME' to create a new workflow."
    fi
    echo ""
}

# =============================================================================
# Task Template Management Functions
# =============================================================================

# Resolve task file path with fallback to builtin
# Arguments:
#   $1 - Task name
# Returns:
#   stdout - Resolved task file path
#   exit code - 0 if found, 1 if not found
resolve_task_file() {
    local task_name="$1"
    local custom_file="$WIREFLOW_TASK_PREFIX/${task_name}.txt"
    local builtin_file="$BUILTIN_WIREFLOW_TASK_PREFIX/${task_name}.txt"

    # Check custom location first
    if [[ -f "$custom_file" && -s "$custom_file" ]]; then
        echo "$custom_file"
        return 0
    fi

    # Fallback to builtin
    if [[ -f "$builtin_file" && -s "$builtin_file" ]]; then
        echo "$builtin_file"
        return 0
    fi

    return 1
}

# Extract task description from file
# Arguments:
#   $1 - Task file path
# Returns:
#   stdout - Task description (truncated to 64 chars)
extract_task_description() {
    local task_file="$1"
    local description

    # Try to extract from <description> tags first
    description=$(awk '/<description>/,/<\/description>/ {
        if (!/description>/ && NF) {print; exit}
    }' "$task_file" | sed 's/^[[:space:]]*//')

    # Fallback to first non-empty line
    if [[ -z "$description" ]]; then
        description=$(grep -v '^[[:space:]]*$' "$task_file" | head -n1 |
                     sed 's/^#\s*//' | sed 's/^[[:space:]]*//')
    fi

    # Truncate to 64 characters
    if [[ ${#description} -gt 64 ]]; then
        description="${description:0:64}..."
    fi

    echo "$description"
}

# List tasks from a directory
# Arguments:
#   $1 - Directory path
#   $2 - Section title (optional)
# Returns:
#   exit code - 0 if tasks found, 1 if none found
list_tasks_from_dir() {
    local dir="$1"
    local title="$2"

    [[ ! -d "$dir" ]] && return 1

    local -a task_files=("$dir"/*.txt)
    [[ ! -e "${task_files[0]}" ]] && return 1

    # Adapt column width for task names (minimum 15)
    local namelen
    local maxlen=0
    local minwidth=12
    for file in "${task_files[@]}"; do
        base="$(basename "$file")"
        namelen="$(echo "${base%.txt}" | wc -m)"
        if [[ $namelen -gt $maxlen ]]; then
            maxlen=$namelen
        fi
    done
    namejust=$(test $maxlen -lt $minwidth && echo $minwidth || echo $maxlen)

    # Print section title if provided
    if [[ -n "$title" ]]; then
        echo "$title"
        echo
    fi

    # List each task with description
    for task_file in "${task_files[@]}"; do
        local task_name=$(basename "$task_file" .txt)
        local description=$(extract_task_description "$task_file")
        printf "  %-${namejust}s %s\n" "$task_name" "$description"
    done

    return 0
}

# List available task templates
list_tasks() {
    echo "Available tasks:"
    echo

    local has_custom=false
    local has_builtin=false

    # List custom tasks
    if [[ "$WIREFLOW_TASK_PREFIX" != "$BUILTIN_WIREFLOW_TASK_PREFIX" ]]; then
        if list_tasks_from_dir "$WIREFLOW_TASK_PREFIX"; then
            has_custom=true
        fi
    fi

    # List builtin tasks (separate section if custom tasks exist)
    if [[ -d "$BUILTIN_WIREFLOW_TASK_PREFIX" ]]; then
        if [[ $has_custom == true ]]; then
            echo
            if list_tasks_from_dir "$BUILTIN_WIREFLOW_TASK_PREFIX" "Built-in templates (fallback):"; then
                has_builtin=true
                echo
            fi
        else
            if list_tasks_from_dir "$BUILTIN_WIREFLOW_TASK_PREFIX"; then
                has_builtin=true
            fi
        fi
    fi

    # Show message if no tasks found
    if [[ $has_custom == false && $has_builtin == false ]]; then
        echo "  (no task templates found)"
    fi

    # Show locations
    echo
    [[ $has_custom == true ]] && echo "Custom:   $(display_absolute_path "$WIREFLOW_TASK_PREFIX")"
    [[ $has_builtin == true ]] && echo "Built-in: $(display_absolute_path "$BUILTIN_WIREFLOW_TASK_PREFIX")"

    # Show usage
    echo
    echo "Usage:"
    echo "  $SCRIPT_NAME tasks              # List task templates"
    echo "  $SCRIPT_NAME tasks show <name>  # Preview template"
    echo "  $SCRIPT_NAME tasks edit <name>  # Edit template"
    echo "  $SCRIPT_NAME task <name> [opts] # Execute template"
}

# Show task template in pager (or pipe to console)
show_task() {
    local task_name="$1"

    if [[ -z "$task_name" ]]; then
        echo "Error: Task name required" >&2
        echo "Usage: $SCRIPT_NAME tasks show <name>" >&2
        return 1
    fi

    # Resolve task file
    local task_file
    if ! task_file=$(resolve_task_file "$task_name"); then
        echo "Error: Task not found: '$task_name'" >&2
        echo >&2

        # Show helpful diagnostics
        if [[ ! -d "$WIREFLOW_TASK_PREFIX" ]]; then
            echo "Warning: Task directory not found:" >&2
            echo "  $(display_absolute_path "$WIREFLOW_TASK_PREFIX")" >&2
            echo >&2
        fi

        echo "Run '$SCRIPT_NAME tasks' to list available tasks." >&2
        return 1
    fi

    # Display in pager
    if command -v less &>/dev/null; then
        less "$task_file"
    else
        cat "$task_file"
    fi
}

# Edit task template in editor
edit_task() {
    local task_name="$1"

    if [[ -z "$task_name" ]]; then
        echo "Error: Task name required" >&2
        echo "Usage: $SCRIPT_NAME tasks edit <name>" >&2
        return 1
    fi

    # Resolve task file (prefer custom location for editing)
    local task_file
    if task_file=$(resolve_task_file "$task_name"); then
        # Task exists - edit it
        edit_files "$task_file"
        return
    fi

    # Task doesn't exist - create in custom location
    if [[ ! -d "$WIREFLOW_TASK_PREFIX" ]]; then
        echo "Creating task directory: $(display_absolute_path "$WIREFLOW_TASK_PREFIX")"
        mkdir -p "$WIREFLOW_TASK_PREFIX"
    fi

    task_file="$WIREFLOW_TASK_PREFIX/${task_name}.txt"

    echo "Creating new task template: $task_name"

    # Create template with basic structure
    cat > "$task_file" <<'EOF'
<description>
  Brief 1-2 sentence overview of this workflow's purpose
</description>

<guidance>
  High-level strategic guidance for approaching this task
</guidance>

<instructions>
  Detailed step-by-step instructions or requirements
</instructions>

<output-format>
  Specific formatting requirements or structure for the output
</output-format>
EOF

    # Open in editor
    edit_files "$task_file"
}

# =============================================================================
# Task Subcommand - Dispatch to Task-Mode Execution
# =============================================================================

# Execute named task template or inline task
# Arguments:
#   $@ - Task specification and execution options
cmd_task() {
    local task_content=""
    local task_source=""
    
    # Check for inline task
    if [[ "$1" == "-i" || "$1" == "--inline" ]]; then
        shift
        if [[ $# -eq 0 ]]; then
            echo "Error: --inline requires task text" >&2
            echo "Usage: $SCRIPT_NAME task --inline <text> [options]" >&2
            return 1
        fi
        
        task_content="$1"
        task_source="inline"
        shift
    else
        # Named task template
        local task_name="$1"
        
        if [[ -z "$task_name" ]]; then
            echo "Error: Task name or --inline text required" >&2
            show_quick_help_task
            return 1
        fi
        
        shift
        
        # Resolve task file
        local task_file
        if ! task_file=$(resolve_task_file "$task_name"); then
            echo "Error: Task not found: '$task_name'" >&2
            echo >&2
            echo "Run '$SCRIPT_NAME tasks' to list available tasks." >&2
            return 1
        fi
        
        # Read task content
        if ! task_content=$(cat "$task_file"); then
            echo "Error: Failed to read task file: $task_file" >&2
            return 1
        fi
        
        task_source="$task_name"
    fi
    
    # Execute task with remaining arguments
    execute_task_mode "$task_content" "$task_source" "$@"
}

# =============================================================================
# Cat Subcommand - Pipe Workflow Output to Console
# =============================================================================
# Parameters:
#   $1 - workflow name (required)
#   $2 - output directory (optional, defaults to $OUTPUT_DIR)
cat_workflow() {
    local workflow_name="$1"
    local output_dir="${2:-$OUTPUT_DIR}"

    # Validate workflow name
    if [[ -z "$workflow_name" ]]; then
        echo "Error: Workflow name required" >&2
        echo "Usage: $SCRIPT_NAME cat NAME" >&2
        return 1
    fi

    # Find output file in project output directory
    local output_file
    output_file=$(find "$output_dir" -maxdepth 1 -type f -name "${workflow_name}.*" 2>/dev/null | head -1)
    if [[ -z "$output_file" ]]; then
        echo "Error: No output found for '$workflow_name'" >&2
        echo "Run '$SCRIPT_NAME run $workflow_name' first." >&2
        return 1
    fi

    # Concatenate the workflow output file to stdout
    cat "$output_file"
}

# =============================================================================
# Open Subcommand - Open Workflow Output File in Default Application
# =============================================================================
open_workflow() {
    local workflow_name="$1"

    # Find project root
    PROJECT_ROOT=$(find_project_root) || {
        echo "Error: Not in workflow project (no .workflow/ directory found)" >&2
        echo "Run 'workflow init' to initialize a project" >&2
        return 1
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
        return 1
    fi

    # Check if open command exists (macOS)
    if ! command -v open >/dev/null 2>&1; then
        echo "Error: 'open' command not found (macOS only)" >&2
        echo "Use 'workflow cat $workflow_name' to view output instead" >&2
        return 1
    fi

    # Open with system default application
    echo "Opening: $output_file"
    open "$output_file"
}

# =============================================================================
# Shell Subcommand - Install shell integration
# =============================================================================

cmd_shell() {
    local action="${1:-}"

    case "$action" in
        install)
            shell_install
            ;;
        -h|--help)
            show_quick_help_shell
            ;;
        "")
            show_help_shell
            ;;
        *)
            echo "Error: Unknown shell action: $action" >&2
            show_quick_help_shell
            return 1
            ;;
    esac
}

shell_install() {
    # Determine wireflow root from this script's location
    local wireflow_root
    wireflow_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

    local bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
    local data_dir="${XDG_DATA_HOME:-$HOME/.local/share}"
    local completions_dir="$data_dir/bash-completion/completions"

    # Create directories
    mkdir -p "$bin_dir" "$completions_dir"

    # Install wfw symlink
    local wfw_source="$wireflow_root/wireflow.sh"
    local wfw_target="$bin_dir/wfw"

    if [[ -e "$wfw_target" && ! -L "$wfw_target" ]]; then
        echo "Warning: $wfw_target exists and is not a symlink, skipping"
    else
        ln -sf "$wfw_source" "$wfw_target"
        echo "Installed: $wfw_target -> $wfw_source"
    fi

    # Install completions
    local comp_source="$wireflow_root/share/bash-completion/completions/wireflow.sh"
    local comp_target="$completions_dir/wfw"

    if [[ -e "$comp_target" && ! -L "$comp_target" ]]; then
        echo "Warning: $comp_target exists and is not a symlink, skipping"
    else
        ln -sf "$comp_source" "$comp_target"
        echo "Installed: $comp_target -> $comp_source"
    fi

    # Hint about PATH
    if ! command -v wfw &>/dev/null; then
        echo ""
        echo "Note: Ensure $bin_dir is in your PATH:"
        echo "  export PATH=\"$bin_dir:\$PATH\""
    fi

    # Hint about completions
    echo ""
    echo "Completions will load automatically in new shells."
    echo "To enable now: source $comp_target"
}
