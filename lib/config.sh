# =============================================================================
# Workflow Configuration Management
# =============================================================================
# Configuration functions for the workflow CLI tool.
# Handles global, project, and workflow config loading and management.
# This file is sourced by wireflow.sh and lib/core.sh.
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
        echo "ENABLE_CITATIONS=${ENABLE_CITATIONS:-}"
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
GLOBAL_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wireflow"
GLOBAL_CONFIG_FILE="$GLOBAL_CONFIG_DIR/config"

# Ensure global config directory and file exist
# Creates default config with hard-coded defaults if missing
# Returns:
#   0 - Success (config exists or was created)
#   1 - Error (permission issues, conflicts)
# Side effects:
#   Creates ~/.config/wireflow/ directory
#   Creates ~/.config/wireflow/config file
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

# Create built-in task templates
# Args:
#   $1 - task_dir: Directory where task templates should be created
# Returns: 0 on success
create_builtin_task_templates() {
    local task_dir="$1"

    # Only create if directory exists and is writable
    [[ -d "$task_dir" && -w "$task_dir" ]] || return 0

    # summarize.txt
    cat > "$task_dir/summarize.txt" <<'TASK_EOF'
<description>
  Create concise summary with key points and action items
</description>

<guidance>
  Extract and synthesize the most important information from the provided content
</guidance>

<instructions>
  Analyze the provided content and create a comprehensive summary that includes:

  1. **Main Topics:** What are the primary subjects discussed?
  2. **Key Findings:** What are the most important conclusions or discoveries?
  3. **Significant Points:** What details or arguments support the main ideas?
  4. **Action Items:** What tasks, next steps, or follow-ups are mentioned or implied?
  5. **Open Questions:** What issues remain unresolved or require further investigation?
</instructions>

<output-format>
  Use clear markdown structure with headers and bullet points.
  Keep the summary concise but comprehensive - aim for 1-2 pages of content.
</output-format>
TASK_EOF

    # extract.txt
    cat > "$task_dir/extract.txt" <<'TASK_EOF'
<description>
  Extract specific information, quotes, data points, or references
</description>

<guidance>
  Identify and organize targeted information from the source material
</guidance>

<instructions>
  Extract and organize specific information from the provided content:

  1. **Key Facts and Data:** Numerical data, statistics, measurements, dates
  2. **Important Quotes:** Significant statements or claims (with context)
  3. **Names and Entities:** People, organizations, locations mentioned
  4. **References:** Citations, sources, external materials referenced
  5. **Technical Terms:** Specialized vocabulary or jargon with definitions
</instructions>

<output-format>
  Format as structured lists with clear categories.
  Include page numbers or section references where available.
  Preserve exact wording for quotes and maintain proper citation format.
</output-format>
TASK_EOF

    # analyze.txt
    cat > "$task_dir/analyze.txt" <<'TASK_EOF'
<description>
  Perform deep analysis identifying patterns, insights, and implications
</description>

<guidance>
  Go beyond surface-level observations to uncover deeper meanings and connections
</guidance>

<instructions>
  Conduct a thorough analysis of the provided content focusing on:

  1. **Patterns and Trends:** What recurring themes, patterns, or trends appear?
  2. **Key Insights:** What important insights or discoveries emerge from the content?
  3. **Relationships:** How do different concepts, data points, or arguments connect?
  4. **Implications:** What are the broader implications or consequences?
  5. **Context:** How does this fit within the larger field or domain?
  6. **Recommendations:** Based on the analysis, what actions or directions are suggested?
</instructions>

<output-format>
  Provide detailed explanations for each observation.
  Support your analysis with specific evidence from the content.
  Use clear structure with headers and subsections for readability.
</output-format>
TASK_EOF

    # review.txt
    cat > "$task_dir/review.txt" <<'TASK_EOF'
<description>
  Critical evaluation with strengths, weaknesses, and improvement suggestions
</description>

<guidance>
  Provide balanced, constructive assessment of the content quality and effectiveness
</guidance>

<instructions>
  Provide a balanced critical review of the provided content covering:

  1. **Strengths:** What aspects are well-executed, clear, or effective?
  2. **Weaknesses:** What issues, gaps, or problems are present?
  3. **Clarity:** Is the content well-organized and easy to understand?
  4. **Completeness:** Are important topics adequately covered?
  5. **Quality Assessment:** How does the work compare to standards or expectations?
  6. **Suggestions for Improvement:** Specific, actionable recommendations
</instructions>

<output-format>
  Be constructive and specific in your feedback.
  Support critiques with examples from the content.
  Balance critical observations with recognition of strengths.
</output-format>
TASK_EOF

    # compare.txt
    cat > "$task_dir/compare.txt" <<'TASK_EOF'
<description>
  Compare and contrast multiple items, approaches, or perspectives
</description>

<guidance>
  Perform systematic comparison highlighting similarities, differences, and trade-offs
</guidance>

<instructions>
  Perform a systematic comparison of the provided items, documents, or perspectives:

  1. **Overview:** Brief summary of each item being compared
  2. **Key Similarities:** What common features, themes, or approaches exist?
  3. **Key Differences:** How do the items differ in approach, content, or conclusions?
  4. **Strengths and Weaknesses:** What are the relative advantages and disadvantages?
  5. **Trade-offs:** What compromises or trade-offs does each option present?
  6. **Recommendations:** Based on the comparison, which option is preferable and why?
</instructions>

<output-format>
  Use clear parallel structure when discussing similarities and differences.
  Create comparison tables if helpful for structured data.
  Provide objective analysis before offering recommendations.
</output-format>
TASK_EOF

    # outline.txt
    cat > "$task_dir/outline.txt" <<'TASK_EOF'
<description>
  Generate structured outline with hierarchical organization
</description>

<guidance>
  Create logical organization and flow for the content or topic
</guidance>

<instructions>
  Create a detailed outline for the provided content or topic:

  1. **Main Sections:** Identify the major sections or chapters needed
  2. **Subsections:** Break down each main section into logical subsections
  3. **Key Points:** List the primary points to cover in each subsection
  4. **Logical Flow:** Ensure smooth transitions and progression of ideas
  5. **Supporting Elements:** Note where examples, data, or references are needed
</instructions>

<output-format>
  Use hierarchical numbering (1, 1.1, 1.1.1) or nested bullets.
  Aim for 3-4 levels of depth where appropriate.
  Include brief notes on the purpose or content of each section.
  Ensure the outline is comprehensive but not overly detailed.
</output-format>
TASK_EOF

    # explain.txt
    cat > "$task_dir/explain.txt" <<'TASK_EOF'
<description>
  Explain complex topics in clear, accessible language with examples
</description>

<guidance>
  Make complex or technical content accessible to a general audience
</guidance>

<instructions>
  Provide a clear explanation of the content or concept for a general audience:

  1. **Overview:** What is the topic and why is it important?
  2. **Core Concepts:** Break down the fundamental ideas or components
  3. **Plain Language:** Explain technical terms and jargon in accessible ways
  4. **Analogies:** Use relevant comparisons to familiar concepts
  5. **Examples:** Provide concrete examples that illustrate key points
  6. **Step-by-Step:** If applicable, break processes into clear sequential steps
  7. **Common Misconceptions:** Address frequent misunderstandings
</instructions>

<output-format>
  Aim for clarity over precision when necessary for understanding.
  Use short paragraphs and clear transitions between ideas.
  Build from simple to complex concepts progressively.
</output-format>
TASK_EOF

    # critique.txt
    cat > "$task_dir/critique.txt" <<'TASK_EOF'
<description>
  Identify problems, gaps, inconsistencies, and suggest improvements
</description>

<guidance>
  Provide thorough critical analysis focused on identifying issues and solutions
</guidance>

<instructions>
  Provide a detailed critique identifying issues and opportunities for improvement:

  1. **Logical Problems:** Are there flaws in reasoning or argumentation?
  2. **Factual Issues:** Are there errors, unsupported claims, or questionable statements?
  3. **Structural Problems:** Are there organizational issues or unclear flow?
  4. **Gaps and Omissions:** What important topics or perspectives are missing?
  5. **Inconsistencies:** Where does the content contradict itself or lack coherence?
  6. **Methodological Issues:** If applicable, are there problems with approach or methods?
  7. **Actionable Improvements:** What specific changes would address these issues?
</instructions>

<output-format>
  Be thorough and specific. Point to exact locations when identifying issues.
  Prioritize problems by severity or impact.
  For each criticism, suggest a constructive path forward.
</output-format>
TASK_EOF

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

    # Create task template directory
    local task_dir="$GLOBAL_CONFIG_DIR/tasks"
    if ! mkdir -p "$task_dir" 2>/dev/null; then
        echo "Warning: Cannot create task template directory: $task_dir" >&2
        # Non-fatal, continue
    fi

    # Create meta system prompt (automatically included first, not user-configurable)
    cat > "$prompt_dir/meta.txt" <<'META_PROMPT_EOF'
<workflow-context>
You are assisting with a workflow-based task using the Workflow CLI tool.

STRUCTURE:
- System blocks: Meta prompt (this), user system prompts, optional project description, current date
- User blocks: Context materials, input documents, task (in optimized order)

CONTENT:
User content provided in order: PDFs → text documents → images → task
- Context: Supporting information (wrapped in <metadata type="context">)
- Input: Primary materials to analyze (wrapped in <metadata type="input">)
- Dependency: Outputs from prior workflows (wrapped in <metadata type="dependency">)
- PDFs: Joint text+visual analysis (citable with document indices)
- Text files: Various formats (citable with document indices)
- Images: Vision API (not citable)
- Task: Final block with your objective (wrapped in <task>)

PROJECT:
May include nested project hierarchy. Configuration cascade enables project-specific customization.

Produce well-structured output directly addressing the task using provided context and inputs.
</workflow-context>
META_PROMPT_EOF

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

    # Create built-in task templates
    create_builtin_task_templates "$task_dir"

    # Create global config file
    cat > "$GLOBAL_CONFIG_FILE" <<'EOF'
# Global WireFlow Configuration
# ~/.config/wireflow/config
#
# This file sets default values for all wireflow projects.
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

# Enable citations for document analysis
# Default: false
# When true, context and input documents use citations.enabled=true
ENABLE_CITATIONS=false

# =============================================================================
# System Prompts
# =============================================================================

# System prompt files to concatenate (space-separated or array syntax)
# Files are loaded from $WIREFLOW_PROMPT_PREFIX/{name}.txt
# Default: (base)
SYSTEM_PROMPTS=(base)

# System prompt directory (contains prompt .txt files)
# Default prompt included at ~/.config/wireflow/prompts/base.txt
# Override to use custom prompt directory
WIREFLOW_PROMPT_PREFIX="$HOME/.config/wireflow/prompts"

# =============================================================================
# Task Files
# =============================================================================

# Task file directory (contains named task .txt files)
# Used by 'wireflow task NAME' subcommand
# Built-in task templates are created automatically on first use
WIREFLOW_TASK_PREFIX="$HOME/.config/wireflow/tasks"

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
# Reads from ~/.config/wireflow/config if exists
# Handles environment variable precedence for API key and prompt prefix
# Always succeeds (uses fallbacks if global config unavailable)
#
# Side effects:
#   Sets: MODEL, TEMPERATURE, MAX_TOKENS, OUTPUT_FORMAT, SYSTEM_PROMPTS
#   May set: ANTHROPIC_API_KEY, WIREFLOW_PROMPT_PREFIX (if not in env)
load_global_config() {
    # Start with hard-coded fallbacks
    local FALLBACK_MODEL="claude-sonnet-4-5"
    local FALLBACK_TEMPERATURE=1.0
    local FALLBACK_MAX_TOKENS=4096
    local FALLBACK_OUTPUT_FORMAT="md"
    local FALLBACK_ENABLE_CITATIONS=false

    MODEL="$FALLBACK_MODEL"
    TEMPERATURE="$FALLBACK_TEMPERATURE"
    MAX_TOKENS="$FALLBACK_MAX_TOKENS"
    OUTPUT_FORMAT="$FALLBACK_OUTPUT_FORMAT"
    ENABLE_CITATIONS="$FALLBACK_ENABLE_CITATIONS"
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
                ENABLE_CITATIONS) [[ -n "$value" ]] && ENABLE_CITATIONS="$value" ;;
                SYSTEM_PROMPTS) [[ -n "$value" ]] && SYSTEM_PROMPTS=($value) ;;
                ANTHROPIC_API_KEY)
                    # Only use config value if env var not already set
                    if [[ -z "$ANTHROPIC_API_KEY" && -n "$value" ]]; then
                        ANTHROPIC_API_KEY="$value"
                    fi
                    ;;
                WIREFLOW_PROMPT_PREFIX)
                    # Only use config value if env var not already set
                    if [[ -z "$WIREFLOW_PROMPT_PREFIX" && -n "$value" ]]; then
                        WIREFLOW_PROMPT_PREFIX="$value"
                    fi
                    ;;
                WIREFLOW_TASK_PREFIX)
                    # Only use config value if env var not already set
                    if [[ -z "$WIREFLOW_TASK_PREFIX" && -n "$value" ]]; then
                        WIREFLOW_TASK_PREFIX="$value"
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
