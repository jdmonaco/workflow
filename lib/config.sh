#!/usr/bin/env bash

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
            esac
        done < <(extract_config "$GLOBAL_CONFIG_FILE" 2>/dev/null || true)
    fi

    return 0
}
