#!/usr/bin/env bash
set -e

# =============================================================================
# Unified Workflow Script for AI-Assisted Manuscript Development
# =============================================================================
# This script provides a unified interface for creating and executing AI
# workflows using the Anthropic Messages API.
#
# Subcommands:
#   init NAME    Create new workflow structure with interactive setup
#   run          Execute a workflow (can be implicit)
#
# Usage:
#   ./workflow.sh init WORKFLOW_NAME
#   ./workflow.sh run --workflow WORKFLOW_NAME [options]
#   ./workflow.sh --workflow WORKFLOW_NAME [options]  # 'run' is implicit
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

# Default configuration
DEFAULT_MODEL="claude-sonnet-4-5"
DEFAULT_TEMPERATURE=1.0
DEFAULT_MAX_TOKENS=4096

# =============================================================================
# Help Text
# =============================================================================
show_help() {
    cat <<EOF
Usage: workflow SUBCOMMAND [OPTIONS]

SUBCOMMANDS:
    init [dir]              Initialize workflow project (default: current dir)
    new NAME                Create new workflow in current project
    edit NAME               Edit existing workflow (opens task.txt and config)
    run NAME [OPTIONS]      Execute workflow

RUN OPTIONS:
    --stream                Use streaming API mode (default: single-batch)
    --dry-run              Estimate tokens only, don't make API call
    --context-pattern GLOB  Glob pattern for context files
    --context-file FILE     Add specific file (repeatable)
    --depends-on WORKFLOW   Include output from another workflow
    --model MODEL           Override model from config
    --temperature TEMP      Override temperature
    --max-tokens NUM        Override max tokens
    --system-prompts LIST   Comma-separated prompt names (overrides config)

OTHER:
    --help, -h, help        Show this help message

EXAMPLES:
    # Initialize project
    workflow init .

    # Create new workflow
    workflow new 01-outline-draft

    # Edit existing workflow
    workflow edit 01-outline-draft

    # Execute workflow (uses .workflow/01-outline-draft/config)
    workflow run 01-outline-draft

    # Execute with streaming
    workflow run 01-outline-draft --stream

    # Execute with overrides
    workflow run 02-intro --depends-on 01-outline-draft --max-tokens 8192

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

    # Create .workflow structure
    mkdir -p "$target_dir/.workflow/prompts"
    mkdir -p "$target_dir/.workflow/output"

    # Create default config
    cat > "$target_dir/.workflow/config" <<'CONFIG_EOF'
# Project-level configuration

# System prompts to concatenate (in order)
# Each name maps to $PROMPT_PREFIX/System/{name}.xml
SYSTEM_PROMPTS=(Root NeuroAI)

# API defaults
MODEL="claude-sonnet-4-5"
TEMPERATURE=1.0
MAX_TOKENS=4096
CONFIG_EOF

    echo "Initialized workflow project: $target_dir/.workflow/"
    echo "Created:"
    echo "  $target_dir/.workflow/config"
    echo "  $target_dir/.workflow/prompts/"
    echo "  $target_dir/.workflow/output/"
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
    cat > "$WORKFLOW_DIR/config" <<'WORKFLOW_CONFIG_EOF'
# Workflow-specific configuration
# These values override project defaults from .workflow/config

# Context aggregation methods (uncomment and configure as needed):

# Method 1: Glob pattern
# CONTEXT_PATTERN="../References/*.md"

# Method 2: Explicit file list
# CONTEXT_FILES=(
#     "../References/doc1.md"
#     "../References/doc2.md"
# )

# Method 3: Workflow dependencies
# DEPENDS_ON=(
#     "00-workshop-context"
#     "01-outline-draft"
# )

# API overrides (optional)
# MODEL="claude-sonnet-4-5"
# TEMPERATURE=1.0
# MAX_TOKENS=4096
# SYSTEM_PROMPTS="Root,NeuroAI,DataScience"
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

    if [[ -z "$workflow_name" ]]; then
        echo "Error: Workflow name required"
        echo "Usage: workflow edit NAME"
        exit 1
    fi

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
        ls -1 "$PROJECT_ROOT/.workflow" | grep -v '^config$\|^prompts$\|^output$' || echo "  (none)"
        echo ""
        echo "Create new workflow with: workflow new $workflow_name"
        exit 1
    fi

    # Open both files in vim with vertical split
    ${EDITOR:-vim} -O "$WORKFLOW_DIR/task.txt" "$WORKFLOW_DIR/config"
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
        echo "Valid subcommands: init, new, edit, run"
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
    ls -1 "$PROJECT_ROOT/.workflow" | grep -v '^config$\|^prompts$\|^output$' || echo "  (none)"
    echo ""
    echo "Create new workflow with: workflow new $WORKFLOW_NAME"
    exit 1
fi

# Tier 1: Built-in defaults
SYSTEM_PROMPTS=(Root)
MODEL="$DEFAULT_MODEL"
TEMPERATURE="$DEFAULT_TEMPERATURE"
MAX_TOKENS="$DEFAULT_MAX_TOKENS"
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
            CONTEXT_FILES+=("$2")
            shift 2
            ;;
        --context-pattern)
            CONTEXT_PATTERN="$2"  # Override config
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
OUTPUT_FILE="$WORKFLOW_DIR/output.md"
OUTPUT_LINK="$PROJECT_ROOT/.workflow/output/${WORKFLOW_NAME}.md"
SYSTEM_PROMPT_FILE="$PROJECT_ROOT/.workflow/prompts/system.txt"

# Validate task file exists
if [[ ! -f "$TASK_PROMPT_FILE" ]]; then
    echo "Error: Task file not found: $TASK_PROMPT_FILE"
    echo "Workflow may be incomplete. Re-create with: workflow new $WORKFLOW_NAME"
    exit 1
fi

# Create system prompt if needed
if [[ -z "$PROMPT_PREFIX" ]]; then
    echo "Error: PROMPT_PREFIX environment variable is not set"
    echo "Set PROMPT_PREFIX to the directory containing your System/*.xml prompt files"
    exit 1
fi

PROMPTDIR="$PROMPT_PREFIX/System"
if [[ ! -f "$SYSTEM_PROMPT_FILE" ]]; then
    if [[ ! -d "$PROMPTDIR" ]]; then
        echo "Error: System prompt directory not found: $PROMPTDIR"
        exit 1
    fi

    mkdir -p "$(dirname "$SYSTEM_PROMPT_FILE")"

    # Build system prompt from SYSTEM_PROMPTS array
    > "$SYSTEM_PROMPT_FILE"
    for prompt_name in "${SYSTEM_PROMPTS[@]}"; do
        prompt_file="$PROMPTDIR/${prompt_name}.xml"
        if [[ ! -f "$prompt_file" ]]; then
            echo "Error: System prompt file not found: $prompt_file"
            exit 1
        fi
        cat "$prompt_file" >> "$SYSTEM_PROMPT_FILE"
    done

    echo "Created system prompt: $SYSTEM_PROMPT_FILE (from: ${SYSTEM_PROMPTS[*]})"
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
    for dep in "${DEPENDS_ON[@]}"; do
        dep_file="$PROJECT_ROOT/.workflow/output/${dep}.md"
        if [[ ! -f "$dep_file" ]]; then
            echo "Error: Dependency output not found: $dep_file"
            echo "Ensure workflow '$dep' has been executed successfully"
            exit 1
        fi
        echo "    - $dep"
        filecat "$dep_file" >> "$CONTEXT_PROMPT_FILE"
    done
fi

# Add files from --context-pattern
if [[ -n "$CONTEXT_PATTERN" ]]; then
    echo "  Adding files from pattern: $CONTEXT_PATTERN"
    eval "filecat $CONTEXT_PATTERN" >> "$CONTEXT_PROMPT_FILE"
fi

# Add explicit files from --context-file
if [[ ${#CONTEXT_FILES[@]} -gt 0 ]]; then
    echo "  Adding explicit files..."
    for file in "${CONTEXT_FILES[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "Error: Context file not found: $file"
            exit 1
        fi
        echo "    - $file"
        filecat "$file" >> "$CONTEXT_PROMPT_FILE"
    done
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

# Combine context and task for user prompt
if [[ -s "$CONTEXT_PROMPT_FILE" ]]; then
    USER_PROMPT="$(filecat "$CONTEXT_PROMPT_FILE" "$TASK_PROMPT_FILE")"
else
    USER_PROMPT=$(<"$TASK_PROMPT_FILE")
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

# Format Markdown output files
if [[ -f "$OUTPUT_FILE" && "$OUTPUT_FILE" == *.md ]] && command -v mdformat &>/dev/null; then
    echo "Formatting output with mdformat..."
    mdformat --no-validate "$OUTPUT_FILE"
fi

echo ""
echo "Workflow '$WORKFLOW_NAME' completed successfully!"
