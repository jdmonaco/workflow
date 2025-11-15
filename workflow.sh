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

# =============================================================================
# File Processing Functions
# =============================================================================

# Filename sanitization for XML-like identifiers
sanitize() {
    local filename="$1"
    local sanitized

    # Strip any parent path elements first
    sanitized="$(basename "$filename")"

    # Strip file extension
    sanitized="${sanitized%.*}"

    # Convert to lowercase
    sanitized="${sanitized,,}"

    # Replace spaces and common punctuation with dashes
    sanitized="${sanitized//[[:space:]]/-}"

    # Remove or replace characters not valid in XML names
    # Keep only alphanumeric, dash, and period
    sanitized="${sanitized//[^a-z0-9.-]/}"

    # Ensure it doesn't start with a number, dash, or period
    # (XML names must start with a letter or underscore)
    if [[ "$sanitized" =~ ^[0-9.-] ]]; then
        sanitized="_${sanitized}"
    fi

    # Remove consecutive dashes
    sanitized="${sanitized//--/-}"

    # Trim leading/trailing dashes
    sanitized="${sanitized#-}"
    sanitized="${sanitized%-}"

    echo "$sanitized"
}

# File concatenation with XML-like tag encapsulation
filecat() {
    # Input files are required
    if [ $# -eq 0 ]; then
        echo "Usage: filecat file1 [file2 ...]" >&2
        return 1;
    fi

    local sanitized
    for file in "$@"; do
        if [[ -f "$file" ]]; then
            # Opening tag, with sanitized identifier based on the filename
            sanitized="$(sanitize "$file")"
            printf "<%s>\n" "$sanitized"

            # Add the file contents
            cat "$file"

            # Ensure newline before closing tag if file doesn't end with one
            [[ -n $(tail -c 1 "$file") ]] && printf "\n"

            # Closing tag
            printf "</%s>\n" "$sanitized"
        fi
    done
}

# =============================================================================
# Project Root Discovery
# =============================================================================
find_project_root() {
    local dir="$PWD"
    while [[ "$dir" != "$HOME" && "$dir" != "/" ]]; do
        if [[ -d "$dir/.workflow" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# List workflows in a project (excludes special files/directories)
list_workflows() {
    local project_root="${1:-$PROJECT_ROOT}"

    # Validate project root
    if [[ -z "$project_root" || ! -d "$project_root/.workflow" ]]; then
        echo "Error: Invalid project root or .workflow directory not found" >&2
        return 1
    fi

    # List entries, excluding special files/directories
    local workflows
    workflows=$(ls -1 "$project_root/.workflow" 2>/dev/null | \
                grep -v '^config$\|^prompts$\|^output$\|^project.txt$')

    # Return workflows if found, otherwise return 1
    if [[ -n "$workflows" ]]; then
        echo "$workflows"
        return 0
    else
        return 1
    fi
}

# Extract inheritable config values from parent project
extract_parent_config() {
    local parent_config="$1"

    # Source parent config in subshell and extract only inheritable values
    (
        # Suppress errors if config doesn't exist or has issues
        source "$parent_config" 2>/dev/null || true

        # Output key=value pairs for parsing
        echo "MODEL=${MODEL:-}"
        echo "TEMPERATURE=${TEMPERATURE:-}"
        echo "MAX_TOKENS=${MAX_TOKENS:-}"
        echo "OUTPUT_FORMAT=${OUTPUT_FORMAT:-}"
        # Handle array - output space-separated
        echo "SYSTEM_PROMPTS=${SYSTEM_PROMPTS[*]:-}"
    )
}

# Default configuration
DEFAULT_MODEL="claude-sonnet-4-5"
DEFAULT_TEMPERATURE=1.0
DEFAULT_MAX_TOKENS=4096
DEFAULT_OUTPUT_FORMAT="md"

# =============================================================================
# Help Text
# =============================================================================
show_help() {
    cat <<EOF
Usage: $(basename ${0}) SUBCOMMAND [OPTIONS]

SUBCOMMANDS:
    init [dir]              Initialize workflow project (default: current dir)
    new NAME                Create new workflow in current project
    edit [NAME]             Edit workflow or project (if NAME omitted)
    list                    List all workflows in current project
    run NAME [OPTIONS]      Execute workflow

RUN OPTIONS:
    --stream                Use streaming API mode (default: single-batch)
    --dry-run               Estimate tokens only, don't make API call
    --context-pattern GLOB  Glob pattern for context files
    --context-file FILE     Add specific file (repeatable)
    --depends-on WORKFLOW   Include output from another workflow
    --model MODEL           Override model from config
    --temperature TEMP      Override temperature
    --max-tokens NUM        Override max tokens
    --system-prompts LIST   Comma-separated prompt names (overrides config)
    --output-format EXT     Output format/extension (default: md)

OTHER:
    --help, -h, help        Show this help message

EXAMPLES:
    # Initialize project
    $(basename ${0}) init .

    # Create new workflow
    $(basename ${0}) new 01-outline-draft

    # Edit project configuration
    $(basename ${0}) edit

    # Edit existing workflow
    $(basename ${0}) edit 01-outline-draft

    # Execute workflow (uses .workflow/01-outline-draft/config)
    $(basename ${0}) run 01-outline-draft

    # Execute with streaming
    $(basename ${0}) run 01-outline-draft --stream

    # Execute with overrides
    $(basename ${0}) run 02-intro --depends-on 01-outline-draft --max-tokens 8192

EOF
}

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

    # Initialize config values with defaults
    INHERITED_MODEL="$DEFAULT_MODEL"
    INHERITED_TEMPERATURE="$DEFAULT_TEMPERATURE"
    INHERITED_MAX_TOKENS="$DEFAULT_MAX_TOKENS"
    INHERITED_OUTPUT_FORMAT="$DEFAULT_OUTPUT_FORMAT"
    INHERITED_SYSTEM_PROMPTS="Root"

    # Check for parent project (handles both nesting detection and inheritance)
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

        # Extract config from parent
        while IFS='=' read -r key value; do
            case "$key" in
                MODEL)
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
        done < <(extract_parent_config "$PARENT_ROOT/.workflow/config")

        # Display inherited values
        echo "  MODEL: $INHERITED_MODEL"
        echo "  TEMPERATURE: $INHERITED_TEMPERATURE"
        echo "  MAX_TOKENS: $INHERITED_MAX_TOKENS"
        echo "  SYSTEM_PROMPTS: $INHERITED_SYSTEM_PROMPTS"
        echo "  OUTPUT_FORMAT: $INHERITED_OUTPUT_FORMAT"
        echo ""
    fi

    # Create .workflow structure
    mkdir -p "$target_dir/.workflow/prompts"
    mkdir -p "$target_dir/.workflow/output"

    # Create default config with inherited values
    cat > "$target_dir/.workflow/config" <<CONFIG_EOF
# Project-level workflow configuration

# System prompts to concatenate (in order, space-separated)
# Names must map to \$WORKFLOW_PROMPT_PREFIX/System/{name}.txt
SYSTEM_PROMPTS=($INHERITED_SYSTEM_PROMPTS)

# API defaults
MODEL="$INHERITED_MODEL"
TEMPERATURE=$INHERITED_TEMPERATURE
MAX_TOKENS=$INHERITED_MAX_TOKENS

# Output format (extension without dot: md, txt, json, html, etc.)
OUTPUT_FORMAT="$INHERITED_OUTPUT_FORMAT"
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

    # Open both files in vim with vertical split
    ${EDITOR:-vim} -O "$target_dir/.workflow/project.txt" "$target_dir/.workflow/config"

    echo ""
    echo "Next steps:"
    echo "  1. cd $target_dir"
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

# API overrides (optional)
# MODEL="$DEFAULT_MODEL"
# TEMPERATURE=$DEFAULT_TEMPERATURE
# MAX_TOKENS=$DEFAULT_MAX_TOKENS
# SYSTEM_PROMPTS=(Root DataScience)

# Output format override (extension without dot: md, txt, json, html, etc.)
# OUTPUT_FORMAT="txt"
# OUTPUT_FORMAT="json"
WORKFLOW_CONFIG_EOF

    echo "Created workflow: $workflow_name"
    echo "  $WORKFLOW_DIR/task.txt"
    echo "  $WORKFLOW_DIR/config"
    echo ""
    echo "Opening task and config files in editor..."

    # Open both files in vim with vertical split
    ${EDITOR:-vim} -O "$WORKFLOW_DIR/task.txt" "$WORKFLOW_DIR/config"
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
        ${EDITOR:-vim} -O "$PROJECT_ROOT/.workflow/project.txt" "$PROJECT_ROOT/.workflow/config"
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
    ${EDITOR:-vim} -O "$WORKFLOW_DIR/task.txt" "$WORKFLOW_DIR/config"
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

    if list_workflows; then
        list_workflows | while read -r workflow; do
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
        init_project "$2"
        exit 0
        ;;
    new)
        if [[ -z "$2" ]]; then
            echo "Error: Workflow name required"
            echo "Usage: workflow new NAME"
            exit 1
        fi
        new_workflow "$2"
        exit 0
        ;;
    edit)
        if [[ -z "$2" ]]; then
            echo "Error: Workflow name required"
            echo "Usage: workflow edit NAME"
            exit 1
        fi
        edit_workflow "$2"
        exit 0
        ;;
    list|ls)
        list_workflows_cmd
        exit 0
        ;;
    run)
        shift  # Remove 'run' from args
        if [[ -z "$1" ]]; then
            echo "Error: Workflow name required"
            echo "Usage: workflow run NAME [options]"
            exit 1
        fi
        WORKFLOW_NAME="$1"
        shift  # Remove workflow name from args
        # Continue to run mode with remaining args
        ;;
    --help|-h|help)
        show_help
        exit 0
        ;;
    *)
        echo "Error: Unknown subcommand: $1"
        echo "Valid subcommands: init, new, edit, list, run"
        echo ""
        show_help
        exit 1
        ;;
esac

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

# Tier 1: Built-in defaults
SYSTEM_PROMPTS=(Root)
MODEL="$DEFAULT_MODEL"
TEMPERATURE="$DEFAULT_TEMPERATURE"
MAX_TOKENS="$DEFAULT_MAX_TOKENS"
OUTPUT_FORMAT="$DEFAULT_OUTPUT_FORMAT"
CONTEXT_FILES=()
CONTEXT_PATTERN=""
DEPENDS_ON=()

# Tier 2: Project-level config
if [[ -f "$PROJECT_ROOT/.workflow/config" ]]; then
    source "$PROJECT_ROOT/.workflow/config"
fi

# Tier 3: Workflow-level config
if [[ -f "$WORKFLOW_DIR/config" ]]; then
    source "$WORKFLOW_DIR/config"
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
    echo "Set WORKFLOW_PROMPT_PREFIX to the directory containing your System/*.txt prompt files"
    exit 1
fi

PROMPTDIR="$WORKFLOW_PROMPT_PREFIX/System"
if [[ ! -d "$PROMPTDIR" ]]; then
    echo "Error: System prompt directory not found: $PROMPTDIR"
    exit 1
fi

echo "Building system prompt from: ${SYSTEM_PROMPTS[*]}"

# Ensure prompts directory exists
mkdir -p "$(dirname "$SYSTEM_PROMPT_FILE")"

# Try to build system prompt to temp file
TEMP_SYSTEM_PROMPT=$(mktemp)
BUILD_SUCCESS=true

for prompt_name in "${SYSTEM_PROMPTS[@]}"; do
    prompt_file="$PROMPTDIR/${prompt_name}.txt"
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
    (cd "$PROJECT_ROOT" && filecat $CONTEXT_PATTERN) >> "$CONTEXT_PROMPT_FILE"
fi

# Add files from CLI --context-pattern (relative to PWD)
if [[ -n "$CLI_CONTEXT_PATTERN" ]]; then
    echo "  Adding files from CLI pattern: $CLI_CONTEXT_PATTERN"
    filecat $CLI_CONTEXT_PATTERN >> "$CONTEXT_PROMPT_FILE"
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

API_KEY="${ANTHROPIC_API_KEY}"

# Check if API key is set
if [[ -z "$API_KEY" ]]; then
    echo "Error: ANTHROPIC_API_KEY environment variable is not set"
    exit 1
fi

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

# Escape JSON strings
escape_json() {
    local string="$1"
    printf '%s' "$string" | jq -Rs .
}

SYSTEM_JSON=$(escape_json "$SYSTEM_PROMPT")
USER_JSON=$(escape_json "$USER_PROMPT")

# Build JSON payload
JSON_PAYLOAD=$(cat <<EOF
{
  "model": "$MODEL",
  "max_tokens": $MAX_TOKENS,
  "temperature": $TEMPERATURE,
  "system": $SYSTEM_JSON,
  "messages": [
    {
      "role": "user",
      "content": $USER_JSON
    }
  ]
}
EOF
)

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

if [[ "$STREAM_MODE" == true ]]; then
    # Streaming mode
    echo "Sending Messages API request (streaming)..."
    echo "---"
    echo ""

    # Initialize output file
    > "$OUTPUT_FILE"

    curl -Ns https://api.anthropic.com/v1/messages \
        -H "content-type: application/json" \
        -H "x-api-key: $API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d "$(echo "$JSON_PAYLOAD" | jq '. + {stream: true}')" | while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Parse SSE format (lines start with "data: ")
        if [[ "$line" == data:* ]]; then
            json_data="${line#data: }"

            # Skip ping events
            [[ "$json_data" == "[DONE]" ]] && continue

            # Extract event type
            event_type=$(echo "$json_data" | jq -r '.type // empty')

            case "$event_type" in
                "content_block_delta")
                    # Extract and print text incrementally
                    delta_text=$(echo "$json_data" | jq -r '.delta.text // empty')
                    if [[ -n "$delta_text" ]]; then
                        printf '%s' "$delta_text"
                        printf '%s' "$delta_text" >> "$OUTPUT_FILE"
                    fi
                    ;;
                "message_stop")
                    printf '\n'
                    ;;
                "error")
                    echo ""
                    echo "API Error:"
                    echo "$json_data" | jq '.error'
                    exit 1
                    ;;
            esac
        fi
    done

    echo ""
    echo "---"

else
    # Single-batch mode
    echo -n "Sending Messages API request... "

    response=$(curl -s https://api.anthropic.com/v1/messages \
        -H "content-type: application/json" \
        -H "x-api-key: $API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d "$JSON_PAYLOAD")

    echo "done!"

    # Check for errors
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        echo "API Error:"
        echo "$response" | jq '.error'
        exit 1
    fi

    # Extract and save response
    echo "$response" | jq -r '.content[0].text' > "$OUTPUT_FILE"

    # Display with less
    less "$OUTPUT_FILE"
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
