# Configuration Guide  

Master the multi-tier configuration cascade system that makes Wireflow flexible and powerful.  

## Configuration Overview  

Wireflow uses a **cascading configuration system** where each level inherits from and can override previous levels:  

```  
Builtin Defaults
        ↓  
Global Config (~/.config/wireflow/config)  
        ↓  
Ancestor Projects (grandparent → parent)  
        ↓  
Project Config (.workflow/config)  
        ↓  
Workflow Config (.workflow/run/<name>/config)  
        ↓  
CLI Flags (--model, --temperature, etc.)  
```  

**Key principle:** Empty values pass through to inherit from parent levels. Set a value to override.

## Quick Start

### First-Time Setup

On first use, Wireflow automatically creates:  

- `~/.config/wireflow/config` - Your global configuration  
- `~/.config/wireflow/prompts/base.txt` - Default system prompt  

Edit global config to set your preferences:

```bash
nano ~/.config/wireflow/config
```

### Project Setup

Initialize a project to create local configuration:

```bash
cd my-project
wfw init .
# Creates .workflow/config
```

### View Configuration

See your effective configuration at any level:

```bash
wfw config              # Project configuration
wfw config <workflow>   # Workflow configuration
```

## Configuration Levels

### 1. Global Configuration

**Location:** `~/.config/wireflow/config`

**Purpose:** Set your personal defaults for all projects

**Example:**
```bash
# API Settings
MODEL=claude-sonnet-4-5
TEMPERATURE=1.0
MAX_TOKENS=4096
OUTPUT_FORMAT=md

# System Prompts
SYSTEM_PROMPTS=(base)
WIREFLOW_PROMPT_PREFIX=$HOME/.config/wireflow/prompts

# Optional: Store API key (environment variable preferred)
# ANTHROPIC_API_KEY=sk-ant-...
```

**When to use:**
- Set your preferred model and parameters
- Store API key (or use environment variable)
- Define reusable system prompts
- Establish personal defaults across all projects

### 2. Ancestor Projects

**Location:** Parent project `.workflow/config` files

**Purpose:** Nested projects automatically inherit configuration from all ancestor projects

**Example hierarchy:**
```bash
~/research/                    # Parent project
├── .workflow/config          # Sets MODEL=claude-opus-4
└── data-analysis/            # Nested project
    └── .workflow/config      # Inherits opus-4, adds CONTEXT_FILES
```

**When to use:**
- Monorepo organization with subprojects
- Shared defaults across related projects
- Hierarchical configuration management

### 3. Project Configuration

**Location:** `.workflow/config` (in project root)

**Purpose:** Set defaults for all workflows in this project

**Example:**
```bash
# Override model for this project
MODEL=claude-opus-4

# Lower temperature for technical accuracy
TEMPERATURE=0.5

# Project-specific prompts
SYSTEM_PROMPTS=(base research)

# Inherit other settings from global
MAX_TOKENS=
OUTPUT_FORMAT=
```

**When to use:**
- Project requires specific model or parameters
- All workflows share common settings
- Override global defaults for this project only

### 4. Workflow Configuration

**Location:** `.workflow/run/<name>/config`

**Purpose:** Configure individual workflows with specific context and parameters

**Example:**
```bash
# Workflow-specific context
CONTEXT_FILES=(
    "project-notes.md"
    "reference data.csv"
)
DEPENDS_ON=(preprocessing analysis)

# Override temperature for this workflow
TEMPERATURE=0.3

# Inherit other settings from project
MODEL=
MAX_TOKENS=
SYSTEM_PROMPTS+=(statistics)  # Append to project's prompts
```

**When to use:**
- Specify input files and context
- Set workflow dependencies
- Fine-tune parameters for specific tasks
- Add workflow-specific prompts

### 5. CLI Overrides

**Purpose:** One-time parameter changes without modifying config files

**Example:**
```bash
# Use opus just for this run
wfw run analysis --model claude-opus-4

# Experiment with lower temperature
wfw run analysis --temperature 0.3

# Add extra context file
wfw run analysis -cx extra-notes.md
```

**When to use:**
- Testing different parameters
- One-time experiments
- Quick adjustments
- Temporary overrides

## Configuration Syntax

### Scalar Variables

Most settings are simple key-value pairs:

```bash
# Set a value (overrides parent)
MODEL=claude-opus-4
TEMPERATURE=0.7

# Leave empty (inherits from parent)
MODEL=
TEMPERATURE=
```

### Array Variables

Some settings accept multiple values (SYSTEM_PROMPTS, CONTEXT_FILES, INPUT_FILES, DEPENDS_ON):

```bash
# Array Operations:
# ┌──────────────────────────┬─────────────────────────────────────┐
# │ Syntax                   │ Behavior                            │
# ├──────────────────────────┼─────────────────────────────────────┤
# │ CONTEXT_FILES=           │ Inherit from parent (pass-through)  │
# │ CONTEXT_FILES=()         │ Clear (reset to empty)              │
# │ CONTEXT_FILES=(file.pdf) │ Replace (override parent)           │
# │ CONTEXT_FILES+=(add.pdf) │ Append (add to parent)              │
# └──────────────────────────┴─────────────────────────────────────┘

# Multi-line arrays (recommended for readability):
CONTEXT_FILES=(
    "notes/project background.md"
    "data/experiment results.csv"
    "references/related work.pdf"
)

# Append to inherited array:
SYSTEM_PROMPTS+=(statistics grant-writing)
```

### Comments

Use `#` for comments in config files:

```bash
# This is a comment
MODEL=claude-opus-4  # Inline comment
```

## Configuration Variables

### Model Profile System

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `PROFILE` | String | Model tier: `fast`, `balanced`, `deep` | `balanced` |
| `MODEL_FAST` | String | Model for fast profile | `claude-haiku-4-5` |
| `MODEL_BALANCED` | String | Model for balanced profile | `claude-sonnet-4-5` |
| `MODEL_DEEP` | String | Model for deep profile | `claude-opus-4-5` |
| `MODEL` | String | Explicit model override (bypasses profile) | (empty) |

### Extended Thinking

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `ENABLE_THINKING` | Boolean | Enable extended thinking mode | `false` |
| `THINKING_BUDGET` | Integer | Token budget for thinking (min 1024) | `10000` |

### Effort Parameter (Opus 4.5 only)

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `EFFORT` | String | Effort level: `low`, `medium`, `high` | `high` |

### API Settings

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `TEMPERATURE` | Float | Response randomness (0.0-1.0) | `1.0` |
| `MAX_TOKENS` | Integer | Maximum response tokens | `16000` |
| `ENABLE_CITATIONS` | Boolean | Enable source citations | `false` |

### Output Settings

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `OUTPUT_FORMAT` | String | Output file extension (`md`, `txt`, `json`) | `md` |

### System Prompts

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `SYSTEM_PROMPTS` | Array | Prompt names (without `.txt` extension) | `(base)` |
| `WIREFLOW_PROMPT_PREFIX` | String | Directory containing prompt files | `~/.config/wireflow/prompts` |

### Context Configuration

| Variable | Type | Description | Scope |
|----------|------|-------------|-------|
| `CONTEXT_PATTERN` | String | Glob pattern for context files | Project, Workflow |
| `CONTEXT_FILES` | Array | Explicit context file paths | Project, Workflow |

### Input Configuration

| Variable | Type | Description | Scope |
|----------|------|-------------|-------|
| `INPUT_PATTERN` | String | Glob pattern for input files | Workflow only |
| `INPUT_FILES` | Array | Explicit input file paths | Workflow only |

### Workflow Dependencies

| Variable | Type | Description | Scope |
|----------|------|-------------|-------|
| `DEPENDS_ON` | Array | Workflow names to include outputs from | Workflow only |

### Output Configuration

| Variable | Type | Description | Scope |
|----------|------|-------------|-------|
| `EXPORT_FILE` | String | Additional path to copy output | Workflow only |

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `ANTHROPIC_API_KEY` | Anthropic API key | ✅ Yes |
| `WIREFLOW_PROMPT_PREFIX` | System prompt directory | No (has default) |
| `WIREFLOW_TASK_PREFIX` | Named task directory | No (has default) |
| `EDITOR` | Text editor for editing files | No (defaults to `vi`) |

## Path Resolution

Understanding path resolution is critical for context and input file aggregation.

### Config File Paths

Paths in config files are **relative to project root**:

```bash
# In .workflow/config or .workflow/run/<name>/config
CONTEXT_PATTERN=data/*.csv
CONTEXT_FILES=(notes/analysis.md refs/paper.pdf)
```

**Benefits:**
- Works regardless of where you run `wfw` from
- Consistent paths across the project
- Easy to share configs

**Example:**
```bash
# Project structure
/home/user/project/
├── .workflow/
│   └── run/
│       └── analysis/
│           └── config  # CONTEXT_PATTERN=data/*.csv
└── data/
    ├── file1.csv
    └── file2.csv

# Works from anywhere:
cd /home/user/project/subdir
wfw run analysis  # Finds /home/user/project/data/*.csv
```

### CLI Paths

Command-line paths are **relative to current working directory**:

```bash
cd /home/user/project/subdir
wfw run analysis -cx local-notes.md
# Looks for: /home/user/project/subdir/local-notes.md
```

This is standard CLI behavior (same as `cp`, `cat`, etc.).

### Special Path Syntax

**Tilde expansion:**
```bash
CONTEXT_FILES=(~/documents/notes.md)  # Expands to home directory
```

**Absolute paths:**
```bash
CONTEXT_FILES=(/absolute/path/to/file.pdf)
```

**Relative paths (from project root in config):**
```bash
CONTEXT_FILES=(data/file.csv notes/background.md)
```

### Glob Patterns

**Basic wildcards:**
```bash
CONTEXT_PATTERN=data/*.csv           # All CSV files in data/
INPUT_PATTERN=notes/*.md             # All markdown files in notes/
```

**Recursive patterns:**
```bash
CONTEXT_PATTERN=notes/**/*.md        # All .md files in notes/ and subdirectories
```

**Brace expansion:**
```bash
CONTEXT_PATTERN=data/{exp1,exp2}/*.csv  # Multiple directories
```

**Spaces in names:**
```bash
CONTEXT_PATTERN="Name\ With\ Spaces/*.txt"
CONTEXT_FILES=("file with spaces.pdf")
```

## Configuration Patterns

### Pattern 1: Minimal (All Defaults)

**Use case:** Quick start, standard workflows

**Global:**
```bash
# Use defaults (auto-created)
MODEL=claude-sonnet-4-5
TEMPERATURE=1.0
MAX_TOKENS=4096
```

**Project:**
```bash
# Inherit everything
MODEL=
TEMPERATURE=
MAX_TOKENS=
```

**Workflow:**
```bash
# Only specify context
CONTEXT_FILES=(data.csv notes.md)
```

### Pattern 2: Project Specialization

**Use case:** Project needs different model or parameters

**Global:**
```bash
MODEL=claude-sonnet-4-5
TEMPERATURE=1.0
```

**Project:**
```bash
# Complex project - use opus
MODEL=claude-opus-4
MAX_TOKENS=8192
# Inherit temperature
TEMPERATURE=
```

**Workflows:**
```bash
# All workflows inherit opus-4 from project
MODEL=
TEMPERATURE=
```

### Pattern 3: Workflow Variations

**Use case:** Different workflows need different parameters

**Global & Project:**
```bash
# Standard defaults
MODEL=claude-sonnet-4-5
TEMPERATURE=1.0
```

**Workflow 1 (creative):**
```bash
TEMPERATURE=1.0  # High creativity
SYSTEM_PROMPTS+=(creative-writing)
```

**Workflow 2 (analysis):**
```bash
TEMPERATURE=0.3  # Low, focused
MODEL=claude-opus-4  # More capable
SYSTEM_PROMPTS+=(data-analysis)
```

### Pattern 4: Incremental Prompts

**Use case:** Build up specialized prompt combinations

**Global:**
```bash
SYSTEM_PROMPTS=(base)
```

**Project:**
```bash
SYSTEM_PROMPTS+=(research neuroai)  # Add project domain
```

**Workflow:**
```bash
SYSTEM_PROMPTS+=(grant-writing)  # Add workflow task
# Result: (base research neuroai grant-writing)
```

### Pattern 5: Shared Context

**Use case:** All workflows share common context files

**Project:**
```bash
CONTEXT_FILES=(
    project-background.md
    team-notes.md
)
```

**Workflow 1:**
```bash
CONTEXT_FILES+=(workflow1-specific.csv)
# Has: project files + workflow1 file
```

**Workflow 2:**
```bash
CONTEXT_FILES+=(workflow2-data.json)
# Has: project files + workflow2 file
```

## Viewing Configuration

### View Effective Configuration

```bash
# Project configuration
wfw config

# Workflow configuration
wfw config <workflow-name>
```

### Sample Output

```
Current Project:
  Root:       ~/projects/research
  Project:    ~/projects/research/.workflow/project.txt
  Output:     ~/projects/research/.workflow/output

Configuration Paths:
  Global:     ~/.config/wireflow/config                    [✓]
  Project:    ~/projects/research/.workflow/config         [✓]
  Workflow:   ~/projects/research/.workflow/run/analysis/config  [✓]

Effective Configuration:
  API Request Parameters:
    MODEL = claude-opus-4                                  [project]
    TEMPERATURE = 0.3                                      [workflow]
    MAX_TOKENS = 8192                                      [global]
    SYSTEM_PROMPTS = (3 items)                             [workflow]
      - base
      - research
      - statistics

  Project-Level Settings:
    CONTEXT_FILES = (2 items)                              [workflow]
      - project-background.md
      - experiment-data.csv

  Workflow-Specific Settings:
    INPUT_FILES = (1 items)                                [workflow]
      - data/input.txt
    DEPENDS_ON = (1 items)                                 [workflow]
      - preprocessing
```

**Source labels show where each value comes from:**
- `[builtin]` - Hard-coded default
- `[global]` - Global config file
- `[ancestor]` - Ancestor project config
- `[project]` - Project config
- `[workflow]` - Workflow config
- `[cli]` - Command-line flag
- `[env]` - Environment variable
- `[unset]` - No value set at any level

## CLI Overrides

### Common Flags

| Flag | Config Variable | Example |
|------|----------------|---------|
| `--profile` | `PROFILE` | `--profile deep` |
| `--model` | `MODEL` | `--model claude-opus-4-5` |
| `--enable-thinking` | `ENABLE_THINKING` | `--enable-thinking` |
| `--thinking-budget` | `THINKING_BUDGET` | `--thinking-budget 15000` |
| `--effort` | `EFFORT` | `--effort medium` |
| `--temperature` | `TEMPERATURE` | `--temperature 0.5` |
| `--max-tokens` | `MAX_TOKENS` | `--max-tokens 8192` |
| `--system` | `SYSTEM_PROMPTS` | `--system base,research` |
| `--format` | `OUTPUT_FORMAT` | `--format json` |
| `-in/--input` | `INPUT_FILES` | `-in data.csv` |
| `-cx/--context` | `CONTEXT_FILES` | `-cx notes.md` |
| `--depends-on` | `DEPENDS_ON` | `--depends-on preprocessing` |
| `--export-file` | `EXPORT_FILE` | `--export-file reports/out.md` |

### Usage Examples

```bash
# Use fast profile for quick iterations
wfw run analysis --profile fast

# Use deep profile with extended thinking
wfw run analysis --profile deep --enable-thinking

# Explicit model with effort control (Opus 4.5)
wfw run analysis --model claude-opus-4-5 --effort medium

# Experiment with temperature
wfw run creative --temperature 1.0

# Add extra context
wfw run analysis -cx extra-notes.md

# Multiple overrides
wfw run analysis \
  --profile deep \
  --enable-thinking \
  --thinking-budget 20000 \
  -cx data.csv
```

**Important:** CLI flags apply only to the current execution and don't modify config files.

## Best Practices

### Configuration Strategy

✅ **Do:**
- Use global config for personal defaults
- Use project config for project-wide settings
- Use workflow config for context and specialization
- Use CLI flags for experiments and one-time changes
- Leave values empty to enable pass-through inheritance
- Use array append (`+=`) to build on parent values
- Document non-obvious configuration choices

❌ **Don't:**
- Set the same value at multiple levels (use pass-through)
- Put sensitive data in project configs (use global or environment)
- Hardcode absolute paths (use project-relative paths)
- Override everything at every level (defeats the cascade)

### When to Override Settings

**Temperature:**
- **Low (0.0-0.4):** Technical analysis, data processing, code review
- **Medium (0.5-0.7):** Balanced tasks, general writing
- **High (0.8-1.0):** Creative writing, brainstorming, varied outputs

**Profile (Model Tier):**
- **fast:** Quick iterations, simple tasks, testing (Haiku)
- **balanced:** General use, good quality/cost ratio (Sonnet) - default
- **deep:** Complex reasoning, highest quality (Opus)

**Extended Thinking:**
- Enable for complex multi-step reasoning tasks
- Increase budget for deeper analysis
- Works best with Sonnet 4.5 and Opus 4.5

**Effort (Opus 4.5 only):**
- **high:** Maximum capability (default)
- **medium:** Balanced speed and quality
- **low:** Fastest, most economical

**Max Tokens:**
- **Low (1024-4096):** Summaries, short responses
- **Medium (8192-16384):** Standard workflows (default: 16000)
- **High (32768+):** Comprehensive reports, long-form content

### Organization Tips

**Global config:**
- Your preferred model and parameters
- API key (or use environment variable)
- Reusable system prompts

**Project config:**
- Project-specific model if needed
- Project-wide prompts
- Shared context files

**Workflow config:**
- Input and context files
- Workflow dependencies
- Task-specific parameter tweaks
- Workflow-specific prompts (via `+=`)

## Troubleshooting

### "Configuration not found"

You're not in a workflow project. Navigate to your project:

```bash
cd /path/to/project
wfw config
```

### Values Not Taking Effect

Check the cascade to see where values come from:

```bash
wfw config <workflow>  # Shows source for each value
```

Remember: CLI flags override everything.

### Glob Patterns Not Matching

- Verify paths are relative to project root (in config) or PWD (in CLI)
- Check files exist: `ls data/*.csv`
- Use quotes around patterns with special characters
- Enable extended globbing if needed: `shopt -s extglob`

### Array Values Not Appending

Check your syntax:

```bash
# Wrong (replaces)
SYSTEM_PROMPTS=(new-prompt)

# Correct (appends)
SYSTEM_PROMPTS+=(new-prompt)
```

### Dependencies Not Found

Dependent workflows must exist and have outputs:

```bash
wfw list                              # Check workflow exists
ls .workflow/run/dependency/output/   # Check output exists
```

### Empty Array Shows as Single Empty Element

Use `()` to explicitly clear, not `('')`:

```bash
# Wrong
CONTEXT_FILES=('')

# Correct
CONTEXT_FILES=()
```

## Next Steps

Now that you understand configuration:

- **[Use system prompts](system-prompts.md)** to customize AI behavior
- **[See examples](examples.md)** of configuration patterns
- **[Explore execution](execution.md)** to use your configurations

---

Continue to [System Prompts](system-prompts.md) →