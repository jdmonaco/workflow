# =============================================================================
# Workflow Configuration Management
# =============================================================================
# Configuration functions for the workflow CLI tool.
# Handles global, project, and workflow config loading and management.
# =============================================================================

# =============================================================================
# Configuration -- Writing and Reading Settings
# =============================================================================

# Write default (pass-through) config assignments to stdout
# Used for: creating default config files
cat_default_config() {
    # Add the config parameters
    echo -en "\n# API processing parameters\n"
    for key in "${CONFIG_KEYS[@]}"; do
        printf '%s=\n' "$key"
    done

    # Add the user-env variables
    echo -en "\n# User-env variables\n"
    for key in "${USER_ENV_KEYS[@]}"; do
        printf '%s=\n' "$key"
    done
}

# Write default (pass-through) project config assignments to stdout
# Used for: creating default project config files
cat_default_project_config() {
    # Add the project-level settings
    echo -en "\n# Project-level settings\n"
    for key in "${PROJECT_KEYS[@]}"; do
        # Skip the CLI versions of project settings
        [[ "$key" == *_CLI ]] && continue
        printf '%s=\n' "$key"
    done

    # Append the global configs to enable project overrides
    cat_default_config
}

# Write default (pass-through) workflow config assignments to stdout
# Used for: creating default workflow config files
cat_default_workflow_config() {
    # Add the project-level overrides and workflow-specific settings
    echo -en "\n# Workflow-specific settings\n"
    for key in "${PROJECT_KEYS[@]}"; do
        # Skip the CLI versions of project settings
        [[ "$key" == *_CLI ]] && continue
        printf '%s=\n' "$key"
    done
    for key in "${WORKFLOW_KEYS[@]}"; do
        # Skip the CLI versions of workflow settings
        [[ "$key" == *_CLI ]] && continue
        printf '%s=\n' "$key"
    done

    # Append the global configs to enable workflow overrides
    cat_default_config
}

# Extract config values from a config file and emit as key=value pairs
# for decoding by the load_*_config functions
# This function needs to be updated when new config settings are added.
# Args:
#   $1 - Config file path
# Returns:
#   Outputs key=value pairs to stdout (one per line)
#   Array values are escaped, quoted, and space-separated
#   Empty/unset values output as "KEY="
extract_config() {
    local config_file="$1"

    # Source config in subshell and extract all config values
    # Output key=value pairs for all config variables
    # Handle arrays - output quoted, escapeds, and space-separated
    (
        source "$config_file" 2>/dev/null || true

        # Model profile system
        echo "PROFILE=${PROFILE:-}"
        echo "MODEL_FAST=${MODEL_FAST:-}"
        echo "MODEL_BALANCED=${MODEL_BALANCED:-}"
        echo "MODEL_DEEP=${MODEL_DEEP:-}"
        echo "MODEL=${MODEL:-}"

        # Extended thinking
        echo "ENABLE_THINKING=${ENABLE_THINKING:-}"
        echo "THINKING_BUDGET=${THINKING_BUDGET:-}"

        # Effort parameter
        echo "EFFORT=${EFFORT:-}"

        # Other API parameters
        echo "TEMPERATURE=${TEMPERATURE:-}"
        echo "MAX_TOKENS=${MAX_TOKENS:-}"
        echo "ENABLE_CITATIONS=${ENABLE_CITATIONS:-}"
        echo "OUTPUT_FORMAT=${OUTPUT_FORMAT:-}"

        # Arrays - output as single-line bash array syntax with printf %q
        printf 'SYSTEM_PROMPTS='
        printf '('
        printf '%q ' "${SYSTEM_PROMPTS[@]}"
        printf ')\n'

        # User environment variables
        echo "WIREFLOW_PROMPT_PREFIX=${WIREFLOW_PROMPT_PREFIX:-}"
        echo "WIREFLOW_TASK_PREFIX=${WIREFLOW_TASK_PREFIX:-}"
        echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}"

        # Workflow parameters
        echo "CONTEXT_PATTERN=${CONTEXT_PATTERN:-}"

        printf 'CONTEXT_FILES='
        printf '('
        printf '%q ' "${CONTEXT_FILES[@]}"
        printf ')\n'

        printf 'DEPENDS_ON='
        printf '('
        printf '%q ' "${DEPENDS_ON[@]}"
        printf ')\n'

        echo "INPUT_PATTERN=${INPUT_PATTERN:-}"

        printf 'INPUT_FILES='
        printf '('
        printf '%q ' "${INPUT_FILES[@]}"
        printf ')\n'

        echo "EXPORT_PATH=${EXPORT_PATH:-}"

        # Batch mode
        echo "BATCH_MODE=${BATCH_MODE:-}"
    )
}

# =============================================================================
# Global Configuration
# =============================================================================

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

# Create default global config file with dynamic built-in defaults
# Create default system prompts directory with meta and base prompts
# Create default tasks directory with built-in templates
# Returns: 0 on success, 1 on error
create_default_global_config() {
    # Create system prompt directory structure
    local system_dir="$GLOBAL_CONFIG_DIR/prompts/system"
    if ! mkdir -p "$system_dir" 2>/dev/null; then
        echo "Warning: Cannot create system prompt directory: $system_dir" >&2
        return 1
    fi

    # Create task template directory structure
    local task_dir="$GLOBAL_CONFIG_DIR/prompts/tasks"
    if ! mkdir -p "$task_dir" 2>/dev/null; then
        echo "Warning: Cannot create task template directory: $task_dir" >&2
        # Non-fatal, continue
    fi

    # Create meta system prompt (automatically included first, not user-configurable)
    cat > "$system_dir/meta.txt" <<'META_PROMPT_EOF'
<system-component>
  <metadata>
    <name>meta</name>
    <version>1.0</version>
  </metadata>
  <content>
    <workflow-context>
      You are assisting with a workflow-based task using the WireFlow CLI tool.

      STRUCTURE:
      - System blocks: Meta prompt (this), user system prompts, optional project description, current date
      - User blocks: Context materials, input documents, task (in optimized order)

      CONTENT:
      User content provided in order: PDFs → text documents → images → task
      - Context: Supporting information (wrapped in &lt;metadata type="context"&gt;)
      - Input: Primary materials to analyze (wrapped in &lt;metadata type="input"&gt;)
      - Dependency: Outputs from prior workflows (wrapped in &lt;metadata type="dependency"&gt;)
      - PDFs: Joint text+visual analysis (citable with document indices)
      - Text files: Various formats (citable with document indices)
      - Images: Vision API (not citable)
      - Task: Final block with your objective (wrapped in &lt;task&gt;)

      PROJECT:
      May include nested project hierarchy. Configuration cascade enables project-specific customization.

      Produce well-structured output directly addressing the task using provided context and inputs.
    </workflow-context>
  </content>
</system-component>
META_PROMPT_EOF

    # Create default base system prompt
    cat > "$system_dir/base.txt" <<'PROMPT_EOF'
<system-component>
  <metadata>
    <name>base</name>
    <version>1.0</version>
  </metadata>
  <content>
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
  </content>
</system-component>
PROMPT_EOF

    # Create built-in task templates
    create_builtin_task_templates "$task_dir"

    # Create global config file with dynamic interpolation of built-in defaults
    cat > "$GLOBAL_CONFIG_FILE" <<EOF
# Global Wireflow Configuration
# ~/.config/wireflow/config
#
# Configuration Cascade:
#   builtin defaults → global config → ancestor → project → workflow → CLI
#
# How to set values:
#   - Leave EMPTY to use builtin default:     PROFILE=
#   - Set VALUE to override builtin:          PROFILE=deep
#
# This file sets defaults for all Wireflow projects and workflows.
# Run 'wfw config' from any project to view effective configuration.

# =============================================================================
# Model Selection (Profile System)
# =============================================================================
#
# Three-tier profile system: fast, balanced, deep
# Each profile maps to a configurable model.
# Set MODEL to bypass the profile system entirely.

# Profile selection: fast | balanced | deep
PROFILE=$BUILTIN_PROFILE

# Model for each profile tier
MODEL_FAST=$BUILTIN_MODEL_FAST
MODEL_BALANCED=$BUILTIN_MODEL_BALANCED
MODEL_DEEP=$BUILTIN_MODEL_DEEP

# Explicit model override (bypasses profile system if non-empty)
MODEL=$BUILTIN_MODEL

# =============================================================================
# Extended Thinking
# =============================================================================
#
# Extended thinking enables Claude to reason step-by-step before responding.
# Supported models: Sonnet 4/4.5, Opus 4/4.1/4.5, Haiku 4.5
#
# ENABLE_THINKING: true | false
# THINKING_BUDGET: Token budget for thinking (min 1024, must be < MAX_TOKENS)

ENABLE_THINKING=$BUILTIN_ENABLE_THINKING
THINKING_BUDGET=$BUILTIN_THINKING_BUDGET

# =============================================================================
# Effort Parameter (Claude Opus 4.5 only)
# =============================================================================
#
# Controls token usage vs thoroughness trade-off.
# Only supported on Claude Opus 4.5 models.
#
# EFFORT: low | medium | high
#   high   - Maximum capability (default, equivalent to omitting)
#   medium - Balanced token savings
#   low    - Most efficient, some capability reduction

EFFORT=$BUILTIN_EFFORT

# =============================================================================
# API Request Parameters
# =============================================================================

TEMPERATURE=$BUILTIN_TEMPERATURE
MAX_TOKENS=$BUILTIN_MAX_TOKENS
ENABLE_CITATIONS=$BUILTIN_ENABLE_CITATIONS
SYSTEM_PROMPTS=(${BUILTIN_SYSTEM_PROMPTS[@]})
OUTPUT_FORMAT=$BUILTIN_OUTPUT_FORMAT

# =============================================================================
# User-Environment Variables
# =============================================================================

WIREFLOW_PROMPT_PREFIX=$BUILTIN_WIREFLOW_PROMPT_PREFIX
WIREFLOW_TASK_PREFIX=$BUILTIN_WIREFLOW_TASK_PREFIX

# Anthropic API Key
# WARNING: Storing API keys in plain text poses security risks.
# Recommended: Set as environment variable in ~/.bashrc instead:
#   export ANTHROPIC_API_KEY="sk-ant-..."
# If both are set, environment variable takes precedence.
# ANTHROPIC_API_KEY=$BUILTIN_ANTHROPIC_API_KEY

# =============================================================================
# Configuration Guide
# =============================================================================
#
# Profile System:
#   PROFILE=balanced    # Use the balanced tier (claude-sonnet-4-5)
#   PROFILE=fast        # Use the fast tier (claude-haiku-4-5)
#   PROFILE=deep        # Use the deep tier (claude-opus-4-5)
#   MODEL=claude-opus-4-5-20251101  # Bypass profiles with explicit model
#
# Extended Thinking:
#   ENABLE_THINKING=true
#   THINKING_BUDGET=15000   # More budget = deeper reasoning
#
# Effort (Opus 4.5 only):
#   EFFORT=medium       # Balance speed and quality
#   EFFORT=low          # Fastest, most economical
#
# Scalar Variables:
#   Leave EMPTY to use builtin:    TEMPERATURE=
#   Set VALUE to override:         TEMPERATURE=0.7
#
# Array Variables (SYSTEM_PROMPTS):
# ┌──────────────────────────┬─────────────────────────────────────┐
# │ Syntax                   │ Behavior                            │
# ├──────────────────────────┼─────────────────────────────────────┤
# │ SYSTEM_PROMPTS=          │ Use builtin (pass-through)          │
# │ SYSTEM_PROMPTS=()        │ Clear (no prompts)                  │
# │ SYSTEM_PROMPTS=(base)    │ Replace (override builtin)          │
# │ SYSTEM_PROMPTS+=(custom) │ Append (add to builtin)             │
# └──────────────────────────┴─────────────────────────────────────┘
#
# Temperature Guide:
#   0.0-0.4  - Focused, deterministic (analysis, code)
#   0.5-0.7  - Balanced (general writing)
#   0.8-1.0  - Creative, varied (brainstorming)
#
# Output Formats:
#   md    - Markdown (default)
#   txt   - Plain text
#   json  - JSON structure
#   html  - HTML document
EOF

    return $?
}

# Create built-in task templates
# Args:
#   $1 - task_dir: Directory where task templates should be created
# Returns: 0 on success
create_builtin_task_templates() {
    local task_dir="$1"

    # Only create if directory exists and is writable
    [[ -d "$task_dir" && -w "$task_dir" ]] || return 0

    # default.txt - Default task template
    cat > "$task_dir/default.txt" <<'TASK_EOF'
<user-task>
  <metadata>
    <name>default</name>
    <version>1.0</version>
  </metadata>
  <content>
    <description>
      Summarize the following content:
    </description>
    <instructions>
      - Brief overview (2-3 sentences)
      - Key points (bullet list)
      - Main conclusions or next steps
    </instructions>
    <output-format>
      Markdown format with clear headers for each section
    </output-format>
  </content>
</user-task>
TASK_EOF

    #TODO fix builtin task templates with incomplete XML structure
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

# =============================================================================
# Model Profile Resolution
# =============================================================================

# Resolve effective model from profile system or explicit override
# Uses MODEL if non-empty, otherwise resolves from PROFILE → MODEL_{PROFILE}
# Arguments: None (uses global variables)
# Returns:
#   stdout - Resolved model identifier
#   Sets RESOLVED_MODEL global variable
resolve_model() {
    local effective_model=""

    # If MODEL is explicitly set (non-empty), use it directly
    if [[ -n "$MODEL" ]]; then
        effective_model="$MODEL"
    else
        # Resolve from profile system
        case "$PROFILE" in
            fast)
                effective_model="$MODEL_FAST"
                ;;
            balanced)
                effective_model="$MODEL_BALANCED"
                ;;
            deep)
                effective_model="$MODEL_DEEP"
                ;;
            *)
                echo "Warning: Unknown profile '$PROFILE', using balanced" >&2
                effective_model="$MODEL_BALANCED"
                ;;
        esac
    fi

    # Set global and output
    RESOLVED_MODEL="$effective_model"
    echo "$effective_model"
}

# Validate API configuration for model compatibility
# Checks extended thinking and effort parameter support
# Arguments:
#   $1 - Model identifier
#   $2 - Enable thinking (true/false)
#   $3 - Effort level (low/medium/high)
# Returns:
#   0 - Valid (may emit warnings)
#   Sets EFFORT to "high" if model doesn't support effort
validate_api_config() {
    local model="$1"
    local enable_thinking="$2"
    local effort="$3"

    # Extended thinking validation
    if [[ "$enable_thinking" == "true" ]]; then
        case "$model" in
            claude-sonnet-4*|claude-opus-4*|claude-haiku-4-5*)
                ;; # Supported
            *)
                echo "Warning: Extended thinking may not be supported on model: $model" >&2
                ;;
        esac

        # Validate thinking budget
        if [[ "$THINKING_BUDGET" -lt 1024 ]]; then
            echo "Warning: THINKING_BUDGET must be >= 1024, using 1024" >&2
            THINKING_BUDGET=1024
        fi
        if [[ "$THINKING_BUDGET" -ge "$MAX_TOKENS" ]]; then
            echo "Warning: THINKING_BUDGET must be < MAX_TOKENS, adjusting" >&2
            THINKING_BUDGET=$((MAX_TOKENS - 1000))
        fi
    fi

    # Effort validation (Opus 4.5 only)
    if [[ "$effort" != "high" ]]; then
        if [[ ! "$model" =~ ^claude-opus-4-5 ]]; then
            echo "Warning: Effort parameter only supported on Claude Opus 4.5; ignoring for: $model" >&2
            EFFORT="high"  # Reset to avoid API error
        fi
    fi

    return 0
}

# =============================================================================
# Load Configuration with Source Tracking
# =============================================================================

# Track loaded config files to prevent duplicates
declare -A LOADED_CONFIGS=()

# Generic config loader with source tracking
# Arguments:
#   $1 - Config file path
#   $2 - Source level name (e.g., "global", "project", "workflow", or ancestor path)
# Returns:
#   0 on success, 1 if config file not found
load_config_level() {
    local config_file="$1"
    local source_level="$2"

    [[ -z "$config_file" || ! -f "$config_file" ]] && return 1

    # Ensure associative arrays are properly declared (needed for subshell/test contexts)
    if ! declare -p LOADED_CONFIGS 2>/dev/null | grep -q '^declare -A'; then
        declare -gA LOADED_CONFIGS=()
    fi
    if ! declare -p CONFIG_SOURCE_MAP 2>/dev/null | grep -q '^declare -A'; then
        declare -gA CONFIG_SOURCE_MAP=()
    fi
    if ! declare -p USER_ENV_SOURCE_MAP 2>/dev/null | grep -q '^declare -A'; then
        declare -gA USER_ENV_SOURCE_MAP=()
    fi
    if ! declare -p PROJECT_SOURCE_MAP 2>/dev/null | grep -q '^declare -A'; then
        declare -gA PROJECT_SOURCE_MAP=()
    fi
    if ! declare -p WORKFLOW_SOURCE_MAP 2>/dev/null | grep -q '^declare -A'; then
        declare -gA WORKFLOW_SOURCE_MAP=()
    fi

    # Get real path for tracking config file loading
    local abs_config_file
    abs_config_file="$(real_path "$config_file")" || return 1

    # Skip if already loaded
    if [[ -v LOADED_CONFIGS[$abs_config_file] ]]; then
        return 0
    fi

    # Mark as loaded
    LOADED_CONFIGS[$abs_config_file]=1
    
    while IFS='=' read -r key value; do
        # Skip empty scalar assignments to enable parameter pass-through
        [[ -z "$value" ]] && continue

        # Skip empty array assignments (serialized as "('' )")
        if [[ "$value" =~ ^\([[:space:]]*\'\'[[:space:]]*\)$ ]]; then
            continue
        fi

        # Auto-detect array variables
        if declare -p "$key" 2>/dev/null | grep -q '^declare -a'; then
            # Parse array syntax with eval
            eval "$key=$value"

            # Update appropriate source map
            if [[ -v CONFIG_SOURCE_MAP[$key] ]]; then
                CONFIG_SOURCE_MAP[$key]="$source_level"
            elif [[ -v PROJECT_SOURCE_MAP[$key] ]]; then
                PROJECT_SOURCE_MAP[$key]="$source_level"
            elif [[ -v WORKFLOW_SOURCE_MAP[$key] ]]; then
                WORKFLOW_SOURCE_MAP[$key]="$source_level"
            fi
        # Handle scalar variables
        elif [[ -v CONFIG_SOURCE_MAP[$key] ]]; then
            printf -v "$key" '%s' "$value"
            CONFIG_SOURCE_MAP[$key]="$source_level"
        elif [[ -v USER_ENV_SOURCE_MAP[$key] ]]; then
            # Skip user-env variables if already set from the environment
            [[ "${USER_ENV_SOURCE_MAP[$key]}" == "env" ]] && continue
            # Override builtin value with config value
            printf -v "$key" '%s' "$value"
            USER_ENV_SOURCE_MAP[$key]="$source_level"
        elif [[ -v PROJECT_SOURCE_MAP[$key] ]]; then
            printf -v "$key" '%s' "$value"
            PROJECT_SOURCE_MAP[$key]="$source_level"
        elif [[ -v WORKFLOW_SOURCE_MAP[$key] ]]; then
            printf -v "$key" '%s' "$value"
            WORKFLOW_SOURCE_MAP[$key]="$source_level"
        fi
    done < <(extract_config "$config_file" 2>/dev/null || true)
}

# Load global configuration from ~/.config/wireflow/config
# Handles environment variable precedence for API key and path prefixes
# Silently fall back to builtin default values if file unavailable
load_global_config() {
    load_config_level "${1:-$GLOBAL_CONFIG_FILE}" "global"
}

# Loads configs from ancestor projects
load_ancestor_configs() {
    local ancestors
    ancestors=$(find_ancestor_projects) || return 1

    # Load each ancestor config in order
    while IFS= read -r ancestor; do
        local config_file="$ancestor/.workflow/config"
        load_config_level "$config_file" "$ancestor"
    done <<< "$ancestors"
}

# Load config from current project
load_project_config() {
    load_config_level "${1:-$PROJECT_CONFIG}" "project"
}

# Load config for a given workflow in the current project
load_workflow_config() {
    local config_file="${1:-$WORKFLOW_CONFIG}"

    if [[ -n "$config_file" && ! -f "$config_file" ]]; then
        echo "Error: Workflow '$WORKFLOW_NAME' config not found" >&2
        echo "Run '$SCRIPT_NAME new $WORKFLOW_NAME' to create it." >&2
        return 1
    fi

    load_config_level "$config_file" "workflow"
}

# =============================================================================
# Configuration Display Helpers
# =============================================================================

# Format config source for display
# Arguments:
#   $1 - Source from *_SOURCE_MAP value or a path
# Returns:
#   stdout - source label or path string for display
display_config_source() {
    local source="$1"
    if [[ -z "$source" ]]; then
        echo "none"
    elif [[ "$source" =~ unset|builtin|env|global|project|workflow ]]; then
        echo "$source"
    elif [[ -d "$source" ]]; then
        echo "ancestor:$(display_absolute_path "$source")"
    else
        echo "$(sanitize "$source")"
    fi
}

# Check config file status for display note
# Arguments:
#   $1 - Config file path, required
# Returns:
#   stdout - status note that can be appended to a path string
display_config_note() {
    local config_path="$1"
    [[ -z "$config_path" ]] && {
        echo "display_config_note: config path required" >&2
        exit 1
    }

    # Create note with config file status
    local note=""
    if [[ ! -e "$config_path" ]]; then
        note=" [file missing]"
    elif [[ ! -s "$config_path" ]]; then
        note=" [empty config]"
    elif [[ ! -r "$config_path" ]]; then
        note=" [not readable]"
    elif ! bash -n "$config_path" 2>/dev/null; then
        note=" [syntax errors]"
    else
        note=" [OK]"
    fi
    echo "$note"
}

# Show a report of detected config cascade paths
# Arguments:
#   $1 - Global config path, optional
#   $2 - Project root path, optional
#   $3 - Workflow directory, optional
show_config_paths() {
    local global_config="${1:-$GLOBAL_CONFIG_FILE}"
    local wireflow_config=".workflow/config"
    local indent="  "
    local config
    local note
    local display
    local ancestors

    # Display global config path
    display="$(display_absolute_path "$global_config")"
    note="$(display_config_note "$global_config")"
    echo "Configuration Paths:"
    printf "${indent}%-12s%-55s%s\n" "Global:" "$display" "$note"

    # Display ancestor paths
    if ancestors=$(find_ancestor_projects); then
        while IFS= read -r ancestor; do
            config="$ancestor/$wireflow_config"
            display="$(display_absolute_path "$config")"
            note="$(display_config_note "$config")"
            printf "${indent}%-12s%-55s%s\n" "Ancestor:" "$display" "$note"
        done <<< "$ancestors"
    fi

    # Display project path
    local project_config="${2:-$PROJECT_CONFIG}"
    if [[ -n "$project_config" ]]; then
        display="$(display_absolute_path "$project_config")"
        note="$(display_config_note "$project_config")"
        printf "${indent}%-12s%-55s%s\n" "Project:" "$display" "$note"

        # Display workflow path
        local workflow_dir="${3:-$WORKFLOW_DIR}"
        if [[ -n "$workflow_dir" ]]; then
            display="$(display_absolute_path "$workflow_dir/config")"
            note="$(display_config_note "$workflow_dir/config")"
            printf "${indent}%-12s%-55s%s\n" "Workflow:" "$display" "$note"
        fi
    fi
}

# Show a report of effective configuration values and sources
# Arguments:
#   $1 - Project root path, optional
#   $2 - Workflow name, optional
show_effective_config() {
    local project_root="${1:-$PROJECT_ROOT}"
    local workflow_name="${2:-$WORKFLOW_NAME}"
    local indent="  "

    # Helper function to print configs from a source-map array
    print_config() {
        local -n keys=$1
        local -n source_map=$2
        local title="${3:-"Configuration Values"}"
        local indent="$4"

        # Check if array has any entries
        if [[ ${#source_map[@]} -eq 0 ]]; then
            echo "$indent$title: (none)"
            return
        fi

        # Print config values and sources
        echo "$indent$title:"
        for key in "${keys[@]}"; do
            local display_value
            local is_array=false

            # Check if this is an array variable
            if declare -p "$key" 2>/dev/null | grep -q '^declare -a'; then
                is_array=true
                local -n arr="$key"

                if [[ ${#arr[@]} -eq 0 ]]; then
                    display_value="()"
                elif [[ ${#arr[@]} -eq 1 ]]; then
                    # Single element
                    display_value="${arr[0]}"
                else
                    # Multiple elements - will show on separate lines
                    display_value="(${#arr[@]} items)"
                fi
                unset -n arr
            else
                # Regular scalar variable
                display_value="${!key}"

                # Truncate sensitive values
                if [[ "$key" == *"API_KEY"* ]] || [[ "$key" == *"SECRET"* ]]; then
                    display_value="${display_value:0:10}..."
                elif [[ "$key" == *"_PATH" ]] || [[ "$key" == *"_PREFIX" ]]; then
                    display_value="$(display_absolute_path "$display_value")"
                fi
            fi

            # Print the parameter key, value, and source
            printf "$indent$indent%-65s [%s]\n" "$key = $display_value" "${source_map[$key]}"

            # If array with multiple items, show them indented
            if $is_array; then
                local -n arr="$key"
                if [[ ${#arr[@]} -gt 1 ]]; then
                    for item in "${arr[@]}"; do
                        printf "$indent$indent$indent- %s\n" "$item"
                    done
                fi
                unset -n arr
            fi
        done
        printf "\n"
    }

    # Call with each source map
    echo "Effective Configuration:"
    print_config CONFIG_KEYS CONFIG_SOURCE_MAP "API Request Parameters" "$indent"
    print_config USER_ENV_KEYS USER_ENV_SOURCE_MAP "User-Environment Variables" "$indent"
    if [[ -n "$project_root" ]]; then
        print_config PROJECT_KEYS PROJECT_SOURCE_MAP "Project-Level Settings" "$indent"
        if [[ -n "$workflow_name" ]]; then
            print_config WORKFLOW_KEYS WORKFLOW_SOURCE_MAP "Workflow-Specific Settings" "$indent"
        fi
    fi
}
