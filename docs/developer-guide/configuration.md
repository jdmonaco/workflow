# Configuration System

Technical reference for WireFlow's configuration cascade, including implementation details and sourcing behavior.

## Configuration Cascade

WireFlow uses a multi-tier cascade with pass-through inheritance:

| Priority | Source | Location |
|----------|--------|----------|
| 1 (lowest) | Built-in defaults | Hardcoded in `lib/config.sh` |
| 2 | Global config | `~/.config/wireflow/config` |
| 3 | Ancestor configs | Parent project `.workflow/config` files |
| 4 | Project config | `.workflow/config` |
| 5 | Workflow config | `.workflow/run/<name>/config` |
| 6 | CLI flags | Command-line arguments |
| 7 (highest) | Environment | `WIREFLOW_*` environment variables |

### Pass-Through Mechanism

The cascade uses pass-through for unset values:

```bash
# Empty value → Inherit from parent tier
MODEL=

# Explicit value → Override parent, decoupled from changes
MODEL="claude-sonnet-4"
```

**Benefits:**

- Change global default → affects all empty configs
- Explicit values stay independent
- Easy to reset: set to empty to restore pass-through
- Nested projects inherit from ALL ancestors in the tree

### Implementation

Configuration loading is implemented in `lib/config.sh`:

```bash
# Core functions
load_default_config()      # Set built-in defaults
load_config_file()         # Source a single config file safely
load_ancestor_configs()    # Walk up tree loading parent configs
find_ancestor_projects()   # Discover parent .workflow/ directories
```

**Source tracking:** `CONFIG_SOURCE_MAP` associative array tracks which tier set each value.

## Configuration Variables

### Model Selection

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL` | `claude-sonnet-4` | Model identifier |
| `PROFILE` | `balanced` | Model tier (fast/balanced/deep) |
| `TEMPERATURE` | `1.0` | Sampling temperature (0.0-1.0) |
| `MAX_TOKENS` | `8192` | Maximum response tokens |

### Profile System

Profiles provide semantic model selection:

| Profile | Model | Use Case |
|---------|-------|----------|
| `fast` | claude-haiku | Quick tasks, iteration |
| `balanced` | claude-sonnet | Default, general purpose |
| `deep` | claude-opus | Complex reasoning |

```bash
# In config file
PROFILE=deep

# Or via CLI
wfw run analysis --profile deep
```

### Thinking & Effort

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_THINKING` | `false` | Extended thinking mode |
| `THINKING_BUDGET` | `10240` | Token budget for thinking |
| `EFFORT` | (unset) | Effort level (low/medium/high, Opus 4.5 only) |

### Content Options

| Variable | Default | Description |
|----------|---------|-------------|
| `INPUT` | (unset) | Array of input file paths (globs expand at source time) |
| `CONTEXT` | (unset) | Array of context file paths (globs expand at source time) |
| `DEPENDS_ON` | (unset) | Array of workflow dependencies |

### Output Options

| Variable | Default | Description |
|----------|---------|-------------|
| `OUTPUT_FORMAT` | `md` | Output file extension |
| `ENABLE_CITATIONS` | `false` | Enable document citations |

**Note:** `STREAM_MODE` is not a configuration variable. Streaming is controlled at runtime via `--stream` / `--no-stream` CLI flags, with mode-specific defaults (run: buffered, task: streaming).

### System Prompts

| Variable | Default | Description |
|----------|---------|-------------|
| `SYSTEM_PROMPTS` | `(base)` | Array of prompt names |

## Nested Project Configuration

When running workflows in nested projects:

1. `find_ancestor_projects()` walks up the directory tree
2. `load_ancestor_configs()` loads configs oldest to newest
3. Each project can override or pass through values

```
grandparent/.workflow/config    # Loaded first
  parent/.workflow/config       # Loaded second
    current/.workflow/config    # Loaded third (highest priority)
```

### Implementation

```bash
find_ancestor_projects() {
    local dir="$1"
    local ancestors=()

    # Walk up, collecting .workflow/ directories
    while [[ "$dir" != "/" ]]; do
        dir="$(dirname "$dir")"
        if [[ -d "$dir/.workflow" ]]; then
            ancestors+=("$dir")
        fi
    done

    # Return oldest first
    printf '%s\n' "${ancestors[@]}" | tac
}
```

## Config Sourcing Safety

Config files are sourced as bash scripts. Safety measures:

1. **Validation:** Files checked before sourcing
2. **Isolation:** Variables explicitly exported to subprocess
3. **Tracking:** `CONFIG_SOURCE_MAP` records origin of each value

### Safe Loading Pattern

```bash
load_config_file() {
    local file="$1"
    local source_label="$2"

    [[ -f "$file" ]] || return 0

    # Source in subshell for safety
    source "$file"

    # Track source
    for var in MODEL TEMPERATURE MAX_TOKENS ...; do
        if [[ -n "${!var:-}" ]]; then
            CONFIG_SOURCE_MAP[$var]="$source_label"
        fi
    done
}
```

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | API authentication |

### Optional Overrides

| Variable | Description |
|----------|-------------|
| `WIREFLOW_PROMPT_PREFIX` | System prompt directory (default: `~/.config/wireflow/prompts/system`) |
| `WIREFLOW_TASK_PREFIX` | Task template directory (default: `~/.config/wireflow/tasks`) |
| `EDITOR` | Text editor for file editing |
| `VISUAL` | Visual editor (higher priority than EDITOR) |

## Path Resolution

Config paths are resolved relative to project root, CLI paths relative to PWD:

| Source | Resolution |
|--------|------------|
| `CONTEXT` in config | Project-relative (globs expand at source time) |
| `-cx` on CLI | PWD-relative |
| `INPUT` in config | Project-relative (globs expand at source time) |
| `-in` on CLI | PWD-relative |

### Processing Order

Context and input are processed in order (config → CLI):

```
Context:
1. Config CONTEXT (project-relative, already glob-expanded)
2. CLI -cx (PWD-relative)

Input:
1. Config INPUT (project-relative, already glob-expanded)
2. CLI -in (PWD-relative)
```

## Display Functions

`wfw config` shows effective configuration with source tracking:

```
Configuration Paths:
  Global:     ~/.config/wireflow/config                    [✓]
  Project:    ~/project/.workflow/config                   [✓]
  Workflow:   ~/project/.workflow/run/analysis/config      [✓]

Effective Configuration:
  MODEL = claude-opus-4                                    [project]
  TEMPERATURE = 0.3                                        [workflow]
  MAX_TOKENS = 8192                                        [global]
```

**Source labels:** `[builtin]`, `[global]`, `[ancestor]`, `[project]`, `[workflow]`, `[cli]`, `[env]`

## See Also

- [Architecture](architecture.md) - System design overview
- [Implementation](implementation.md) - Module reference for lib/config.sh
- [User Guide: Configuration](../user-guide/configuration.md) - User-facing configuration guide
