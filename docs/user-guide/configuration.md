# Configuration

Master the cascading configuration system that makes WireFlow flexible and powerful.

## Configuration Cascade

WireFlow uses a **cascading configuration system** where each level inherits from and can override previous levels:

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

## Configuration Levels

### 1. Global Configuration

**Location:** `~/.config/wireflow/config`

```bash
MODEL=claude-sonnet-4-5
TEMPERATURE=1.0
MAX_TOKENS=4096
OUTPUT_FORMAT=md
SYSTEM_PROMPTS=(base)
```

### 2. Project Configuration

**Location:** `.workflow/config`

```bash
MODEL=claude-opus-4
TEMPERATURE=0.5
SYSTEM_PROMPTS=(base research)
MAX_TOKENS=        # Inherit from global
```

### 3. Workflow Configuration

**Location:** `.workflow/run/<name>/config`

```bash
INPUT=(data.csv notes.md)
DEPENDS_ON=(preprocessing)
TEMPERATURE=0.3
SYSTEM_PROMPTS+=(statistics)  # Append to project's prompts
```

### 4. CLI Overrides

```bash
wfw run analysis --model claude-opus-4 --temperature 0.3
wfw run analysis -cx extra-notes.md
```

## Variable Syntax

### Scalar Variables

```bash
MODEL=claude-opus-4     # Override parent
MODEL=                  # Inherit from parent (pass-through)
```

### Array Variables

```bash
CONTEXT=           # Inherit from parent
CONTEXT=()         # Clear (reset to empty)
CONTEXT=(file.pdf) # Replace (override parent)
CONTEXT+=(add.pdf) # Append (add to parent)

# Glob patterns expand at config source time (from project root)
CONTEXT=(data/*.csv notes.md docs/**/*.pdf)

# Multi-line arrays (use quotes for filenames with spaces)
CONTEXT=(
    "notes/background.md"
    "data/results.csv"
)
```

## Configuration Variables

### Model & Profile

| Variable | Description | Default |
|----------|-------------|---------|
| `PROFILE` | Model tier: `fast`, `balanced`, `deep` | `balanced` |
| `MODEL_FAST` | Model for fast profile | `claude-haiku-4-5` |
| `MODEL_BALANCED` | Model for balanced profile | `claude-sonnet-4-5` |
| `MODEL_DEEP` | Model for deep profile | `claude-opus-4-5` |
| `MODEL` | Explicit model override | (empty) |

### Extended Thinking & Effort

| Variable | Description | Default |
|----------|-------------|---------|
| `ENABLE_THINKING` | Enable extended thinking | `false` |
| `THINKING_BUDGET` | Token budget (min 1024) | `10000` |
| `EFFORT` | Opus 4.5 effort: `low`, `medium`, `high` | `high` |

### API Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `TEMPERATURE` | Randomness (0.0-1.0) | `1.0` |
| `MAX_TOKENS` | Max response tokens | `16000` |
| `ENABLE_CITATIONS` | Enable source citations | `false` |

### Output & Prompts

| Variable | Description | Default |
|----------|-------------|---------|
| `OUTPUT_FORMAT` | File extension (`md`, `txt`, `json`) | `md` |
| `EXPORT_FILE` | Additional output path | (empty) |
| `SYSTEM_PROMPTS` | Prompt names | `(base)` |
| `WIREFLOW_PROMPT_PREFIX` | Prompts directory | `~/.config/wireflow/prompts` |

### Context & Input

| Variable | Description | Scope |
|----------|-------------|-------|
| `CONTEXT` | Context file paths (globs expand at source time) | Project, Workflow |
| `INPUT` | Input file paths (globs expand at source time) | Workflow |
| `DEPENDS_ON` | Workflow dependencies | Workflow |

## CLI Flags

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
| `-in/--input` | `INPUT` | `-in data.csv` |
| `-cx/--context` | `CONTEXT` | `-cx notes.md` |
| `--depends-on` | `DEPENDS_ON` | `--depends-on preprocessing` |
| `--export-file` | `EXPORT_FILE` | `--export-file reports/out.md` |

## Viewing Configuration

```bash
wfw config              # Project configuration
wfw config analysis     # Workflow configuration
```

**Example output:**
```
Configuration Paths:
  Global:     ~/.config/wireflow/config                    [✓]
  Project:    ~/project/.workflow/config                   [✓]
  Workflow:   ~/project/.workflow/run/analysis/config      [✓]

Effective Configuration:
  MODEL = claude-opus-4                                    [project]
  TEMPERATURE = 0.3                                        [workflow]
  MAX_TOKENS = 8192                                        [global]
  SYSTEM_PROMPTS = (base research statistics)              [workflow]
```

Source labels: `[builtin]`, `[global]`, `[ancestor]`, `[project]`, `[workflow]`, `[cli]`, `[env]`

## Pass-Through Inheritance

Leave values empty to inherit from parent levels:

```bash
# .workflow/config (project)
MODEL=claude-opus-4
TEMPERATURE=          # Inherit from global
```

```bash
# .workflow/run/analysis/config (workflow)
MODEL=                # Inherit from project (claude-opus-4)
TEMPERATURE=0.3       # Override for this workflow
```

## Override Patterns

### Per-Workflow Overrides

```bash
# .workflow/run/exploratory/config
TEMPERATURE=0.9
SYSTEM_PROMPTS=(base creative)

# .workflow/run/analysis/config
TEMPERATURE=0.3
SYSTEM_PROMPTS=(base research stats)
```

### CLI Experiments

```bash
wfw run analysis --profile deep --enable-thinking
wfw run analysis --temperature 0.5 --model claude-opus-4-5
```

## Best Practices

**Do:**
- Use global config for personal defaults
- Use project config for project-wide settings
- Use workflow config for context and task-specific settings
- Use CLI flags for experiments
- Leave values empty to enable inheritance
- Use array append (`+=`) to build on parent values

**Don't:**
- Set the same value at multiple levels
- Put sensitive data in project configs (use global or env)
- Override everything at every level

### Parameter Guidelines

| Temperature | Use Case |
|-------------|----------|
| 0.0-0.4 | Technical analysis, data processing |
| 0.5-0.7 | Balanced tasks, general writing |
| 0.8-1.0 | Creative writing, brainstorming |

| Profile | Model | Use Case |
|---------|-------|----------|
| `fast` | Haiku | Quick iterations, simple tasks |
| `balanced` | Sonnet | General use (default) |
| `deep` | Opus | Complex reasoning |

---

← Back to [Execution Modes](execution.md)
