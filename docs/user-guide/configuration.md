# Configuration Guide

Master the four-tier configuration cascade system that makes Workflow flexible and powerful.

## Configuration Overview

Workflow uses a **four-tier cascade** where each level can override the previous:

```
1. Global Config (~/.config/workflow/config)
        ↓
2. Project Config (.workflow/config)
        ↓
3. Workflow Config (.workflow/<name>/config)
        ↓
4. CLI Flags (--model, --temperature, etc.)
```

Lower tiers override higher tiers. **Empty values pass through** to inherit from above.

## Global Configuration

### Location

`~/.config/workflow/config`

### Auto-Creation

On first use, Workflow automatically creates:

- `~/.config/workflow/config` - Global configuration file
- `~/.config/workflow/prompts/base.txt` - Default system prompt

This makes the tool self-contained and ready to use immediately.

### Default Contents

```bash
# Global Workflow Configuration
MODEL="claude-3-5-sonnet-20241022"
TEMPERATURE=1.0
MAX_TOKENS=8192
OUTPUT_FORMAT="md"
SYSTEM_PROMPTS=(base)

# System prompt directory
WORKFLOW_PROMPT_PREFIX="$HOME/.config/workflow/prompts"

# Optional: Store API key (environment variable preferred)
# ANTHROPIC_API_KEY="sk-ant-..."

# Optional: Named task directory
# WORKFLOW_TASK_PREFIX="$HOME/.config/workflow/tasks"
```

### Why Global Config?

Set your preferences **once** and they apply to **all projects**:

- ✅ Consistent defaults across projects
- ✅ Single place to update API key
- ✅ Change model globally when new versions release
- ✅ Manage system prompts centrally

### Editing Global Config

```bash
nano ~/.config/workflow/config
```

Or from any directory:

```bash
workflow config  # Shows global config if not in a project
```

## Project Configuration

### Location

`.workflow/config` (in your project root)

### Creation

Created automatically when you run `workflow init`:

```bash
cd my-project
workflow init .
# Creates .workflow/config
```

### Purpose

Set defaults for all workflows in the project without affecting other projects.

### Example Project Config

```bash
# Use more capable model for this complex project
MODEL="claude-3-opus-4-20250514"

# Lower temperature for technical accuracy
TEMPERATURE=0.5

# Higher token limit for comprehensive outputs
MAX_TOKENS=8192

# Project-specific system prompts
SYSTEM_PROMPTS=(base research)

# Default to markdown output
OUTPUT_FORMAT=md
```

### Pass-Through Pattern (Recommended)

Leave values empty to inherit from global config:

```bash
# Inherit everything from global config
MODEL=
TEMPERATURE=
MAX_TOKENS=
SYSTEM_PROMPTS=()
OUTPUT_FORMAT=
```

This allows you to change global defaults and affect all projects that don't explicitly override.

### Editing Project Config

```bash
workflow edit  # Without workflow name, edits project config
```

Or directly:

```bash
nano .workflow/config
```

## Workflow Configuration

### Location

`.workflow/<name>/config`

### Creation

Created when you run `workflow new`:

```bash
workflow new analysis-01
# Creates .workflow/analysis-01/config
```

### Purpose

Override settings for specific workflows without affecting others.

### Example Workflow Config

```bash
# Context aggregation (workflow-specific)
CONTEXT_PATTERN="data/*.csv"
CONTEXT_FILES=("notes.md" "references.txt")
DEPENDS_ON=("00-context" "01-preprocessing")

# API overrides (optional, empty = inherit)
MODEL=
TEMPERATURE=0.3  # Override: use lower temperature for this workflow
MAX_TOKENS=
SYSTEM_PROMPTS=(base stats)  # Override: add stats prompt
OUTPUT_FORMAT=json  # Override: JSON output for this workflow
```

### Context Configuration

Workflow configs commonly specify context sources:

- `CONTEXT_PATTERN` - Glob pattern relative to project root
- `CONTEXT_FILES` - Array of files relative to project root
- `DEPENDS_ON` - Array of workflow names to include outputs from

### Editing Workflow Config

```bash
workflow edit analysis-01  # Edits workflow-specific config
```

Or directly:

```bash
nano .workflow/analysis-01/config
```

## CLI Overrides

### Highest Priority

Command-line flags **always override** all config levels.

### Common CLI Flags

| Flag | Config Variable | Example |
|------|----------------|---------|
| `--model` | `MODEL` | `--model claude-3-opus-4-20250514` |
| `--temperature` | `TEMPERATURE` | `--temperature 0.5` |
| `--max-tokens` | `MAX_TOKENS` | `--max-tokens 8192` |
| `--system-prompts` | `SYSTEM_PROMPTS` | `--system-prompts "base,research"` |
| `--format-hint` | `OUTPUT_FORMAT` | `--format-hint json` |
| `--context-file` | `CONTEXT_FILES` | `--context-file data.csv` |
| `--context-pattern` | `CONTEXT_PATTERN` | `--context-pattern "*.md"` |
| `--depends-on` | `DEPENDS_ON` | `--depends-on 01-analysis` |

### One-Time Overrides

CLI flags don't modify config files - they apply only to the current execution:

```bash
# Use opus just for this run
workflow run analysis --model claude-3-opus-4-20250514

# Next run uses config default
workflow run analysis
```

### When to Use CLI Flags

✅ **Use CLI flags for:**

- One-time experiments
- Temporary overrides
- Testing different parameters
- Quick adjustments

✅ **Use config files for:**

- Persistent settings
- Workflow defaults
- Project standards
- Shared configurations

## Configuration Pass-Through

### The Pass-Through Rule

**Empty values inherit from parent tier. Non-empty values override.**

This enables transparent cascading where global changes affect uncustomized projects.

### Example: Transparent Cascade

```bash
# Global config
MODEL="claude-3-5-sonnet-20241022"

# Project config
MODEL=  # Empty - passes through

# Workflow config
MODEL=  # Empty - passes through

# Result: Uses claude-3-5-sonnet-20241022 from global
```

**Change global config:**

```bash
# Global config
MODEL="claude-3-opus-4-20250514"  # Changed

# Result: All empty configs now automatically use opus-4
```

### Example: Explicit Override

```bash
# Global config
MODEL="claude-3-5-sonnet-20241022"

# Project config
MODEL="claude-3-opus-4-20250514"  # Explicit value

# Workflow config
MODEL=  # Empty - inherits from project

# Result: Uses opus-4 from project (ignores global changes)
```

### Why This Matters

**Without pass-through:**

- Must update every config file when you want to change a default
- Can't manage settings centrally
- Hard to maintain consistency

**With pass-through:**

- Change global config once → affects all empty configs
- Explicit values stay independent
- Best of both worlds: central defaults + local overrides

## Configuration Variables

### API Settings

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `MODEL` | String | Claude model name | `claude-3-5-sonnet-20241022` |
| `TEMPERATURE` | Float | Response randomness (0.0-1.0) | `1.0` |
| `MAX_TOKENS` | Integer | Maximum response tokens | `8192` |

### Output Settings

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `OUTPUT_FORMAT` | String | Output file extension | `md` |
| `STREAM_MODE` | Boolean | Enable streaming | `true` (workflow mode defaults to batch) |

### System Prompts

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `SYSTEM_PROMPTS` | Array | Prompt names (no `.txt`) | `(base)` |
| `WORKFLOW_PROMPT_PREFIX` | String | Prompt directory path | `~/.config/workflow/prompts` |

### Context Configuration

| Variable | Type | Description | Scope |
|----------|------|-------------|-------|
| `CONTEXT_PATTERN` | String | Glob pattern for files | Project, Workflow |
| `CONTEXT_FILES` | Array | Explicit file paths | Project, Workflow |
| `DEPENDS_ON` | Array | Workflow dependencies | Workflow only |
| `CONTEXT_FILE_PREFIX` | String | Base path for relative paths | All |

### Task Mode Settings

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `WORKFLOW_TASK_PREFIX` | String | Named task directory | `~/.config/workflow/tasks` |

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `ANTHROPIC_API_KEY` | Anthropic API key | ✅ Yes |
| `EDITOR` | Text editor for editing files | No (defaults to `vi`) |

## Path Resolution

Understanding path resolution is critical for context aggregation.

### Config File Paths (Relative to Project Root)

When paths appear in config files, they're **relative to project root**:

```bash
# In .workflow/config or .workflow/<name>/config
CONTEXT_PATTERN="data/*.csv"
CONTEXT_FILES=("notes/analysis.md" "refs/paper.pdf")
```

**Benefits:**

- Works regardless of where you run `workflow` from
- Consistent paths across the project
- Easy to share configs

**Example:**

```bash
# Project structure
/home/user/project/
├── .workflow/
│   └── workflows/
│       └── analysis/
│           └── config  # CONTEXT_PATTERN="data/*.csv"
└── data/
    ├── file1.csv
    └── file2.csv

# Works from anywhere:
cd /home/user/project/subdir
workflow run analysis  # Still finds /home/user/project/data/*.csv
```

### CLI Paths (Relative to PWD)

Command-line paths are **relative to current working directory**:

```bash
cd /home/user/project/subdir
workflow run analysis --context-file local-notes.md
# Looks for: /home/user/project/subdir/local-notes.md
```

**This is standard CLI behavior** - same as `cp`, `cat`, etc.

### Glob Pattern Features

#### Brace Expansion

```bash
CONTEXT_PATTERN="data/{experiment1,experiment2}/*.csv"
# Expands to: data/experiment1/*.csv data/experiment2/*.csv
```

#### Recursive Patterns

```bash
CONTEXT_PATTERN="notes/**/*.md"
# Matches all .md files in notes/ and subdirectories
```

#### Spaces in Names

```bash
CONTEXT_PATTERN="{Name\ One,Name\ Two}/*.txt"
# Handles directories with spaces
```

### Array Values

For multiple files, use bash array syntax:

```bash
# Config file
CONTEXT_FILES=("file1.md" "file2.md" "data/file3.csv")

DEPENDS_ON=("workflow1" "workflow2" "workflow3")

SYSTEM_PROMPTS=(base research stats)
```

## Viewing Configuration

### View Current Configuration

```bash
# Project config
workflow config

# Workflow config
workflow config <name>
```

### Output Format

```
Configuration for workflow: analysis-01

MODEL: claude-3-opus-4-20250514 (project)
TEMPERATURE: 0.3 (workflow)
MAX_TOKENS: 8192 (default)
STREAM_MODE: true (default)
SYSTEM_PROMPTS: base, stats (workflow)
OUTPUT_FORMAT: json (workflow)
CONTEXT_FILE_PREFIX: ./ (default)

Workflow-specific settings:
  CONTEXT_PATTERN: data/*.csv
  CONTEXT_FILES: notes.md, references.txt
  DEPENDS_ON: 00-context, 01-preprocessing
```

**Source labels:**

- `(default)` - Hard-coded default
- `(global)` - Global config file
- `(project)` - Project config
- `(workflow)` - Workflow config

This shows you exactly where each value comes from!

## Configuration Examples

### Example 1: Minimal (All Defaults)

**Global:**
```bash
# Use all defaults (created automatically)
MODEL="claude-3-5-sonnet-20241022"
TEMPERATURE=1.0
MAX_TOKENS=8192
```

**Project:**
```bash
# Empty - inherit global
MODEL=
TEMPERATURE=
MAX_TOKENS=
```

**Workflow:**
```bash
# Only specify context
CONTEXT_PATTERN="data/*.csv"
```

### Example 2: Project Override

**Global:**
```bash
MODEL="claude-3-5-sonnet-20241022"
TEMPERATURE=1.0
MAX_TOKENS=4096
```

**Project:**
```bash
# This is a complex project - use opus
MODEL="claude-3-opus-4-20250514"
MAX_TOKENS=8192
# Inherit temperature
TEMPERATURE=
```

**Workflow:**
```bash
# Inherit project settings
MODEL=
TEMPERATURE=
MAX_TOKENS=

# Add context
CONTEXT_FILES=("data.csv")
```

### Example 3: Workflow Specialization

**Global:**
```bash
MODEL="claude-3-5-sonnet-20241022"
TEMPERATURE=1.0
```

**Project:**
```bash
# Inherit global
MODEL=
TEMPERATURE=
```

**Workflow 1 (creative writing):**
```bash
TEMPERATURE=1.0  # Creative
MODEL=  # Use project default
```

**Workflow 2 (data analysis):**
```bash
TEMPERATURE=0.3  # Focused
MODEL="claude-3-opus-4-20250514"  # More capable
```

### Example 4: Environment-Specific

**Development:**
```bash
# Global config
MODEL="claude-3-5-haiku-20241022"  # Fast, cheap
MAX_TOKENS=4096  # Smaller
```

**Production:**
```bash
# Global config
MODEL="claude-3-opus-4-20250514"  # Best quality
MAX_TOKENS=8192  # Larger
```

Projects inherit appropriate defaults based on which environment.

## Best Practices

### Configuration Strategy

✅ **Do:**

- Use global config for your personal defaults
- Use project config for project-wide settings
- Use workflow config for workflow-specific context and specialization
- Use CLI flags for one-time experiments
- Leave values empty to enable pass-through
- Document non-obvious configuration choices

❌ **Don't:**

- Set the same value in multiple tiers (use pass-through)
- Put sensitive data in project configs (use global or environment variables)
- Hardcode absolute paths in configs (use project-relative paths)
- Override everything at every level (defeats the cascade)

### Organization Tips

**Global config:**

- Set your preferred model
- Set your API key
- Define reusable system prompts

**Project config:**

- Set project-specific model if needed
- Set project-specific temperature range
- Define project system prompts

**Workflow config:**

- Specify context sources (CONTEXT_PATTERN, CONTEXT_FILES)
- Set dependencies (DEPENDS_ON)
- Override temperature for specific workflows
- Set output format if different from project default

### When to Override

**Temperature:**

- **Low (0.0-0.4):** Technical analysis, data processing, code review
- **Medium (0.5-0.7):** Balanced tasks, general writing
- **High (0.8-1.0):** Creative writing, brainstorming, varied outputs

**Model:**

- **Haiku:** Fast iterations, simple tasks, testing
- **Sonnet:** Balanced quality and cost (default)
- **Opus:** Complex reasoning, highest quality needed

**Max Tokens:**

- **Low (1024-2048):** Summaries, short responses
- **Medium (4096-8192):** Standard workflows (default)
- **High (16384+):** Comprehensive reports, long-form content

## Troubleshooting

### "Configuration not found"

You're not in a workflow project:

```bash
cd /path/to/project  # Navigate to project
workflow config
```

### Values Not Taking Effect

Check the cascade - CLI flags override everything:

```bash
workflow config analysis  # See where each value comes from
```

### Glob Patterns Not Matching

- Check paths are relative to project root (config) or PWD (CLI)
- Verify files exist: `ls data/*.csv`
- Check pattern syntax: use quotes around patterns

### Dependencies Not Found

Dependent workflows must exist and have outputs:

```bash
workflow list  # Check workflow exists
ls .workflow/dependency/output/  # Check output exists
```

## Next Steps

Now that you understand configuration:

- **[Use system prompts](system-prompts.md)** to customize AI behavior
- **[See examples](examples.md)** of configuration patterns
- **[Explore execution](execution.md)** to use your configurations

---

Continue to [System Prompts](system-prompts.md) →
