# =============================================================================
# Workflow Configuration Management
# =============================================================================
# Configuration functions for the workflow CLI tool.
# Handles global, project, and workflow config loading and management.
# This file is sourced by workflow.sh and lib/core.sh.
# =============================================================================

# =============================================================================
# Configuration Extraction
# =============================================================================

# Extract config values from a config file
# General-purpose function for reading config files and outputting key=value pairs
# Used for: parent config inheritance, config display, config cascade tracking
#
# Args:
#   $1 - Config file path
# Returns:
#   Outputs key=value pairs to stdout (one per line)
#   Arrays are space-separated
#   Empty/unset values output as "KEY="
extract_config() {
    local config_file="$1"

    # Source config in subshell and extract all config values
    (
        # Suppress errors if config doesn't exist or has issues
        source "$config_file" 2>/dev/null || true

        # Output key=value pairs for all config variables
        echo "MODEL=${MODEL:-}"
        echo "TEMPERATURE=${TEMPERATURE:-}"
        echo "MAX_TOKENS=${MAX_TOKENS:-}"
        echo "OUTPUT_FORMAT=${OUTPUT_FORMAT:-}"
        # Handle arrays - output space-separated
        echo "SYSTEM_PROMPTS=${SYSTEM_PROMPTS[*]:-}"
        echo "INPUT_PATTERN=${INPUT_PATTERN:-}"
        echo "INPUT_FILES=${INPUT_FILES[*]:-}"
        echo "CONTEXT_PATTERN=${CONTEXT_PATTERN:-}"
        echo "CONTEXT_FILES=${CONTEXT_FILES[*]:-}"
        echo "DEPENDS_ON=${DEPENDS_ON[*]:-}"
    )
}

# =============================================================================
# Global Configuration Management
# =============================================================================

# Global config directory and file paths
GLOBAL_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/workflow"
GLOBAL_CONFIG_FILE="$GLOBAL_CONFIG_DIR/config"

# Ensure global config directory and file exist
# Creates default config with hard-coded defaults if missing
# Returns:
#   0 - Success (config exists or was created)
#   1 - Error (permission issues, conflicts)
# Side effects:
#   Creates ~/.config/workflow/ directory
#   Creates ~/.config/workflow/config file
#   Outputs message if created for first time
ensure_global_config() {
    # Check if path exists and is not a directory (conflict)
    if [[ -e "$GLOBAL_CONFIG_DIR" && ! -d "$GLOBAL_CONFIG_DIR" ]]; then
        echo "Error: $GLOBAL_CONFIG_DIR exists but is not a directory" >&2
        echo "Please resolve this conflict manually" >&2
        return 1
    fi

    # Create directory if doesn't exist
    if [[ ! -d "$GLOBAL_CONFIG_DIR" ]]; then
        if ! mkdir -p "$GLOBAL_CONFIG_DIR" 2>/dev/null; then
            echo "Warning: Cannot create global config directory: $GLOBAL_CONFIG_DIR" >&2
            echo "Permission denied. Using hard-coded defaults." >&2
            return 1
        fi
    fi

    # Create config file if doesn't exist
    if [[ ! -f "$GLOBAL_CONFIG_FILE" ]]; then
        if ! create_default_global_config; then
            echo "Warning: Cannot create global config file: $GLOBAL_CONFIG_FILE" >&2
            echo "Using hard-coded defaults." >&2
            return 1
        fi
        echo "Created global config: $GLOBAL_CONFIG_FILE"
    fi

    return 0
}

# Create default global config file with hard-coded defaults
# Also creates default system prompt directory and base.txt
# Returns: 0 on success, 1 on error
create_default_global_config() {
    # Create system prompt directory
    local prompt_dir="$GLOBAL_CONFIG_DIR/prompts"
    if ! mkdir -p "$prompt_dir" 2>/dev/null; then
        echo "Warning: Cannot create system prompt directory: $prompt_dir" >&2
        return 1
    fi

    # Create default base system prompt
    cat > "$prompt_dir/base.txt" <<'PROMPT_EOF'
<system>
You are a helpful AI assistant supporting workflow-based content development and analysis.

Your role is to assist users with various tasks including:

- Research synthesis and literature analysis
- Content drafting and refinement
- Data analysis and interpretation
- Technical writing and documentation
- Creative ideation and brainstorming
- Structured problem-solving

When responding:

- Provide clear, well-organized outputs
- Use appropriate formatting (Markdown, JSON, etc. as requested)
- Cite sources and reasoning when relevant
- Break down complex tasks into manageable steps
- Maintain consistency across workflow stages
- Build upon context from previous workflow outputs

Focus on producing high-quality, actionable content that advances the user's project goals.
</system>
PROMPT_EOF

    # Create global config file
    cat > "$GLOBAL_CONFIG_FILE" <<'EOF'
# Global Workflow Configuration
# ~/.config/workflow/config
#
# This file sets default values for all workflow projects.
# Configuration cascade: global → project → workflow → CLI flags
#
# Each tier inherits from the previous tier when values are empty.
# Set explicit values here to change defaults for all projects.

# =============================================================================
# API Configuration
# =============================================================================

# Model to use for API requests
# Default: claude-sonnet-4-5
# Examples: claude-opus-4, claude-sonnet-4-5, claude-haiku-4
MODEL="claude-sonnet-4-5"

# Temperature for generation (0.0 = deterministic, 1.0 = creative)
# Default: 1.0
TEMPERATURE=1.0

# Maximum tokens to generate
# Default: 4096
MAX_TOKENS=4096

# Output file format/extension
# Default: md
# Options: md, txt, json, html, etc.
OUTPUT_FORMAT="md"

# =============================================================================
# System Prompts
# =============================================================================

# System prompt files to concatenate (space-separated or array syntax)
# Files are loaded from $WORKFLOW_PROMPT_PREFIX/{name}.txt
# Default: (base)
SYSTEM_PROMPTS=(base)

# System prompt directory (contains prompt .txt files)
# Default prompt included at ~/.config/workflow/prompts/base.txt
# Override to use custom prompt directory
WORKFLOW_PROMPT_PREFIX="$HOME/.config/workflow/prompts"

# =============================================================================
# Task Files
# =============================================================================

# Task file directory (contains named task .txt files)
# Used by 'workflow task NAME' subcommand
# Leave commented to require explicit setting or use --inline flag
# WORKFLOW_TASK_PREFIX="$HOME/.config/workflow/tasks"

# =============================================================================
# Optional: API Credentials
# =============================================================================

# Anthropic API key
# WARNING: Storing API keys in plain text poses security risks on shared systems.
# Recommended: Set as environment variable in ~/.bashrc instead:
#   export ANTHROPIC_API_KEY="sk-ant-..."
# If both config file and environment variable are set, environment variable takes precedence.
# ANTHROPIC_API_KEY=""

EOF
    return $?
}

# Find ancestor project roots (excluding current project)
# Returns newline-separated paths from oldest to newest ancestor
# Args: $1 = current project root
find_ancestor_projects() {
    local current="$1"

    # Get all project roots from current location
    local all_roots
    all_roots=$(cd "$current" && find_all_project_roots) || return 1

    # Filter out current project, keep only ancestors
    local ancestors=()
    while IFS= read -r root; do
        if [[ "$root" != "$current" ]]; then
            ancestors+=("$root")
        fi
    done <<< "$all_roots"

    # Reverse array to get oldest first
    local reversed=()
    for ((i=${#ancestors[@]}-1; i>=0; i--)); do
        reversed+=("${ancestors[i]}")
    done

    # Output newline-separated
    if [[ ${#reversed[@]} -gt 0 ]]; then
        printf '%s\n' "${reversed[@]}"
        return 0
    else
        return 1
    fi
}

# Load configuration cascade from ancestor projects
# Loads configs from all ancestor projects (oldest to newest)
# Tracks which ancestor set each configuration value
# Args: $1 = current project root
# Side effects:
#   Sets: MODEL, TEMPERATURE, MAX_TOKENS, OUTPUT_FORMAT, SYSTEM_PROMPTS (if non-empty in configs)
#   Sets: CONFIG_SOURCE_MAP (associative array tracking source for each key)
load_ancestor_configs() {
    local current_root="$1"

    # Initialize source tracking map
    declare -gA CONFIG_SOURCE_MAP

    # Get ancestors (oldest first)
    local ancestors
    ancestors=$(find_ancestor_projects "$current_root") || return 0

    # Load each ancestor config in order
    while IFS= read -r ancestor; do
        local config_file="$ancestor/.workflow/config"
        [[ ! -f "$config_file" ]] && continue

        while IFS='=' read -r key value; do
            [[ -z "$value" ]] && continue
            case "$key" in
                MODEL|TEMPERATURE|MAX_TOKENS|OUTPUT_FORMAT|SYSTEM_PROMPTS)
                    # Set value and track source
                    case "$key" in
                        SYSTEM_PROMPTS)
                            SYSTEM_PROMPTS=($value)
                            ;;
                        *)
                            eval "$key=\"$value\""
                            ;;
                    esac
                    CONFIG_SOURCE_MAP[$key]="$ancestor"
                    ;;
            esac
        done < <(extract_config "$config_file")
    done <<< "$ancestors"
}

# Load global configuration with fallback to hard-coded defaults
# Reads from ~/.config/workflow/config if exists
# Handles environment variable precedence for API key and prompt prefix
# Always succeeds (uses fallbacks if global config unavailable)
#
# Side effects:
#   Sets: MODEL, TEMPERATURE, MAX_TOKENS, OUTPUT_FORMAT, SYSTEM_PROMPTS
#   May set: ANTHROPIC_API_KEY, WORKFLOW_PROMPT_PREFIX (if not in env)
load_global_config() {
    # Start with hard-coded fallbacks
    local FALLBACK_MODEL="claude-sonnet-4-5"
    local FALLBACK_TEMPERATURE=1.0
    local FALLBACK_MAX_TOKENS=4096
    local FALLBACK_OUTPUT_FORMAT="md"

    MODEL="$FALLBACK_MODEL"
    TEMPERATURE="$FALLBACK_TEMPERATURE"
    MAX_TOKENS="$FALLBACK_MAX_TOKENS"
    OUTPUT_FORMAT="$FALLBACK_OUTPUT_FORMAT"
    SYSTEM_PROMPTS=(base)

    # Try to load global config if it exists
    if [[ -f "$GLOBAL_CONFIG_FILE" ]]; then
        # Source config and extract values
        while IFS='=' read -r key value; do
            case "$key" in
                MODEL) [[ -n "$value" ]] && MODEL="$value" ;;
                TEMPERATURE) [[ -n "$value" ]] && TEMPERATURE="$value" ;;
                MAX_TOKENS) [[ -n "$value" ]] && MAX_TOKENS="$value" ;;
                OUTPUT_FORMAT) [[ -n "$value" ]] && OUTPUT_FORMAT="$value" ;;
                SYSTEM_PROMPTS) [[ -n "$value" ]] && SYSTEM_PROMPTS=($value) ;;
                ANTHROPIC_API_KEY)
                    # Only use config value if env var not already set
                    if [[ -z "$ANTHROPIC_API_KEY" && -n "$value" ]]; then
                        ANTHROPIC_API_KEY="$value"
                    fi
                    ;;
                WORKFLOW_PROMPT_PREFIX)
                    # Only use config value if env var not already set
                    if [[ -z "$WORKFLOW_PROMPT_PREFIX" && -n "$value" ]]; then
                        WORKFLOW_PROMPT_PREFIX="$value"
                    fi
                    ;;
                WORKFLOW_TASK_PREFIX)
                    # Only use config value if env var not already set
                    if [[ -z "$WORKFLOW_TASK_PREFIX" && -n "$value" ]]; then
                        WORKFLOW_TASK_PREFIX="$value"
                    fi
                    ;;
            esac
        done < <(extract_config "$GLOBAL_CONFIG_FILE" 2>/dev/null || true)
    fi

    return 0
}

# =============================================================================
# Configuration Display Helpers
# =============================================================================

# Load configuration cascade for project (Tiers 1-3)
# Loads global config → ancestor configs → project config
# Updates CONFIG_VALUE array with final values after each tier
#
# Args:
#   $1 - PROJECT_ROOT (required)
# Side effects:
#   Sets: MODEL, TEMPERATURE, MAX_TOKENS, OUTPUT_FORMAT, SYSTEM_PROMPTS
#   Updates: CONFIG_VALUE associative array
#   Updates: CONFIG_SOURCE_MAP via load_ancestor_configs()
load_project_config_tiers() {
    local PROJECT_ROOT="$1"

    # Tier 1: Load global config
    load_global_config

    # Track initial values
    declare -gA CONFIG_VALUE
    CONFIG_VALUE[MODEL]="$MODEL"
    CONFIG_VALUE[TEMPERATURE]="$TEMPERATURE"
    CONFIG_VALUE[MAX_TOKENS]="$MAX_TOKENS"
    CONFIG_VALUE[OUTPUT_FORMAT]="$OUTPUT_FORMAT"
    CONFIG_VALUE[SYSTEM_PROMPTS]="${SYSTEM_PROMPTS[*]}"

    # Tier 2: Ancestor project cascade
    load_ancestor_configs "$PROJECT_ROOT"

    # Update values after ancestor cascade
    CONFIG_VALUE[MODEL]="$MODEL"
    CONFIG_VALUE[TEMPERATURE]="$TEMPERATURE"
    CONFIG_VALUE[MAX_TOKENS]="$MAX_TOKENS"
    CONFIG_VALUE[OUTPUT_FORMAT]="$OUTPUT_FORMAT"
    CONFIG_VALUE[SYSTEM_PROMPTS]="${SYSTEM_PROMPTS[*]}"

    # Tier 3: Current project config (only apply non-empty values)
    if [[ -f "$PROJECT_ROOT/.workflow/config" ]]; then
        while IFS='=' read -r key value; do
            [[ -z "$value" ]] && continue
            case "$key" in
                MODEL|TEMPERATURE|MAX_TOKENS|OUTPUT_FORMAT)
                    eval "$key=\"$value\""
                    CONFIG_SOURCE_MAP[$key]="project"
                    ;;
                SYSTEM_PROMPTS)
                    SYSTEM_PROMPTS=($value)
                    CONFIG_SOURCE_MAP[SYSTEM_PROMPTS]="project"
                    ;;
            esac
        done < <(extract_config "$PROJECT_ROOT/.workflow/config")
    fi

    # Update final values
    CONFIG_VALUE[MODEL]="$MODEL"
    CONFIG_VALUE[TEMPERATURE]="$TEMPERATURE"
    CONFIG_VALUE[MAX_TOKENS]="$MAX_TOKENS"
    CONFIG_VALUE[OUTPUT_FORMAT]="$OUTPUT_FORMAT"
    CONFIG_VALUE[SYSTEM_PROMPTS]="${SYSTEM_PROMPTS[*]}"
}

# Display configuration cascade hierarchy
# Shows cascade path: Global → Ancestors → Project → [Workflow]
#
# Args:
#   $1 - global_config_path (formatted with ~/)
#   $2 - project_root (absolute path)
#   $3 - workflow_dir (optional, absolute path)
display_config_cascade_hierarchy() {
    local global_display="$1"
    local project_root="$2"
    local workflow_dir="${3:-}"

    # Format project display path
    local project_display
    project_display=$(format_path_with_tilde "$project_root")

    echo "Configuration Cascade:"
    echo "  Global:   $global_display"

    # Display each ancestor project
    local ancestors
    if ancestors=$(find_ancestor_projects "$project_root" 2>/dev/null); then
        while IFS= read -r ancestor; do
            local ancestor_display
            ancestor_display=$(format_path_with_tilde "$ancestor")
            echo "  Ancestor: $ancestor_display/.workflow/config"
        done <<< "$ancestors"
    fi

    echo "  Project:  $project_display/.workflow/config"

    # Add workflow tier if provided
    if [[ -n "$workflow_dir" ]]; then
        local workflow_display
        workflow_display=$(format_path_with_tilde "$workflow_dir")
        echo "  Workflow: $workflow_display/config"
    fi

    echo ""
}

# Display effective configuration values with sources
# Shows the 5 main config parameters with their source tier
#
# Requires:
#   CONFIG_VALUE associative array (set by load_project_config_tiers)
#   CONFIG_SOURCE_MAP associative array (set by load_ancestor_configs)
display_effective_config_values() {
    echo "Effective Configuration:"

    # Use CONFIG_SOURCE_MAP if keys exist, otherwise default to "global"
    local model_source="${CONFIG_SOURCE_MAP[MODEL]:-global}"
    local temp_source="${CONFIG_SOURCE_MAP[TEMPERATURE]:-global}"
    local tokens_source="${CONFIG_SOURCE_MAP[MAX_TOKENS]:-global}"
    local prompts_source="${CONFIG_SOURCE_MAP[SYSTEM_PROMPTS]:-global}"
    local format_source="${CONFIG_SOURCE_MAP[OUTPUT_FORMAT]:-global}"

    # Helper function to format source (from lib/core.sh, duplicated here for clarity)
    format_config_source() {
        local source="$1"
        if [[ "$source" == "global" || "$source" == "workflow" || "$source" == "project" ]]; then
            echo "$source"
        elif [[ "$source" =~ ^/ ]]; then
            local rel_path
            rel_path=$(format_path_with_tilde "$source")
            echo "ancestor:$(basename "$source")"
        else
            echo "$source"
        fi
    }

    echo "  MODEL: ${CONFIG_VALUE[MODEL]} ($(format_config_source "$model_source"))"
    echo "  TEMPERATURE: ${CONFIG_VALUE[TEMPERATURE]} ($(format_config_source "$temp_source"))"
    echo "  MAX_TOKENS: ${CONFIG_VALUE[MAX_TOKENS]} ($(format_config_source "$tokens_source"))"
    echo "  SYSTEM_PROMPTS: ${CONFIG_VALUE[SYSTEM_PROMPTS]} ($(format_config_source "$prompts_source"))"
    echo "  OUTPUT_FORMAT: ${CONFIG_VALUE[OUTPUT_FORMAT]} ($(format_config_source "$format_source"))"
    echo ""
}
