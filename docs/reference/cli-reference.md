# CLI Reference

Complete reference for all Workflow commands, options, and flags.

## Global Usage

```
workflow <subcommand> [options]
```

### Available Subcommands

| Subcommand | Description |
|------------|-------------|
| `init` | Initialize workflow project |
| `new` | Create new workflow |
| `edit` | Edit workflow or project files |
| `list`, `ls` | List workflows in project |
| `config` | View/edit configuration |
| `run` | Execute workflow with full context |
| `task` | Execute one-off task (lightweight) |
| `help` | Show help for subcommands |

### Global Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help message |

### Quick Help

```bash
workflow help                # Main help
workflow help <subcommand>   # Detailed subcommand help
workflow <subcommand> -h     # Quick subcommand help
```

## Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `ANTHROPIC_API_KEY` | Anthropic API key | ✅ Yes | None |
| `WORKFLOW_PROMPT_PREFIX` | System prompt directory | No | `~/.config/workflow/prompts` |
| `WORKFLOW_TASK_PREFIX` | Named task directory | No | `~/.config/workflow/tasks` |
| `EDITOR` | Text editor for file editing | No | `vi` |

## Configuration Files

| Location | Purpose |
|----------|---------|
| `~/.config/workflow/config` | Global user configuration |
| `.workflow/config` | Project-level configuration |
| `.workflow/<name>/config` | Workflow-specific configuration |

---

## `workflow init`

Initialize a workflow project with `.workflow/` structure.

### Usage

```bash
workflow init [<directory>]
```

### Arguments

| Argument | Description | Required |
|----------|-------------|----------|
| `<directory>` | Directory to initialize | No (default: current directory) |

### Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help |

### Description

Creates `.workflow/` directory structure with:

- `config` - Project-level configuration
- `project.txt` - Project description (optional)
- `prompts/` - System prompt cache
- `output/` - Hardlinks to workflow outputs
- `workflows/` - Directory for individual workflows

Opens `project.txt` and `config` in `$EDITOR` for editing.

### Config Inheritance

**Global inheritance:**

New projects inherit defaults from `~/.config/workflow/config`:

- `MODEL`, `TEMPERATURE`, `MAX_TOKENS`
- `SYSTEM_PROMPTS`, `OUTPUT_FORMAT`

**Parent project inheritance:**

If initializing inside an existing workflow project:

- Detects parent `.workflow/` directory
- Offers to inherit parent configuration
- Creates separate workflow namespace

### Examples

```bash
# Initialize in current directory
workflow init .

# Initialize in new directory
workflow init my-project

# Navigate and initialize
cd existing-project
workflow init .
```

### See Also

- [`workflow new`](#workflow-new) - Create workflows
- [`workflow config`](#workflow-config) - View configuration

---

## `workflow new`

Create a new workflow in the current project.

### Usage

```bash
workflow new <name>
```

### Arguments

| Argument | Description | Required |
|----------|-------------|----------|
| `<name>` | Workflow name | ✅ Yes |

### Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help |

### Description

Creates `.workflow/<name>/` directory with:

- `task.txt` - Task description (opens in `$EDITOR`)
- `config` - Workflow configuration (opens in `$EDITOR`)
- `context/` - Context file directory (created on first use)
- `output/` - Output directory (created on first run)

Workflow config supports:

- `CONTEXT_PATTERN` - Glob pattern for context files
- `CONTEXT_FILES` - Explicit file list (array)
- `DEPENDS_ON` - Workflow dependencies (array)
- API overrides - `MODEL`, `TEMPERATURE`, etc.

### Requirements

Must be run within an initialized workflow project. Use `workflow init` first if needed.

### Examples

```bash
# Simple workflow
workflow new 01-outline

# Descriptive name
workflow new analyze-data

# Numbered sequence
workflow new 00-context
workflow new 01-analysis
workflow new 02-writeup
```

### See Also

- [`workflow init`](#workflow-init) - Initialize project
- [`workflow edit`](#workflow-edit) - Edit workflows
- [`workflow run`](#workflow-run) - Execute workflows

---

## `workflow edit`

Edit workflow or project files in `$EDITOR`.

### Usage

```bash
workflow edit [<name>]
```

### Arguments

| Argument | Description | Required |
|----------|-------------|----------|
| `<name>` | Workflow name | No |

### Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help |

### Behavior

**Without `<name>` (project files):**

Opens:

- `.workflow/project.txt`
- `.workflow/config`

**With `<name>` (workflow files):**

Opens:

- `.workflow/<name>/task.txt`
- `.workflow/<name>/config`

### Requirements

Must be run within an initialized workflow project.

### Examples

```bash
# Edit project files
workflow edit

# Edit workflow files
workflow edit 01-outline
workflow edit analyze-data
```

### See Also

- [`workflow config`](#workflow-config) - View configuration

---

## `workflow list`

List all workflows in the current project.

### Usage

```bash
workflow list
workflow ls    # Alias
```

### Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help |

### Description

Lists workflow directories in `.workflow/`, excluding:

- `config`, `prompts/`, `output/`, `project.txt`

Shows status indicators:

- `[complete]` - Has `task.txt` and `config`
- `[incomplete]` - Missing required files

### Requirements

Must be run within an initialized workflow project.

### Examples

```bash
workflow list
workflow ls
```

### Sample Output

```
Available workflows in /path/to/project/.workflow:

  00-context
  01-analysis
  02-draft
  03-review
```

### See Also

- [`workflow new`](#workflow-new) - Create workflows
- [`workflow run`](#workflow-run) - Execute workflows

---

## `workflow config`

Display configuration with source tracking and option to edit.

### Usage

```bash
workflow config [<name>] [options]
```

### Arguments

| Argument | Description | Required |
|----------|-------------|----------|
| `<name>` | Workflow name | No |

### Options

| Option | Description |
|--------|-------------|
| `--no-edit` | Skip interactive edit prompt |
| `-h`, `--help` | Show help |

### Behavior

**Without `<name>` (project config):**

- Shows project configuration
- Lists all workflows
- Source tracking: `(global)`, `(project)`

**With `<name>` (workflow config):**

- Shows workflow configuration
- Full cascade: global → project → workflow
- Shows context sources (`CONTEXT_PATTERN`, `CONTEXT_FILES`, `DEPENDS_ON`)

### Configuration Cascade

```
1. Global:   ~/.config/workflow/config
2. Project:  .workflow/config
3. Workflow: .workflow/<name>/config
4. CLI flags (highest priority)
```

### Source Indicators

| Indicator | Meaning |
|-----------|---------|
| `(default)` | Hard-coded default value |
| `(global)` | From `~/.config/workflow/config` |
| `(project)` | From `.workflow/config` |
| `(workflow)` | From `.workflow/<name>/config` |

### Examples

```bash
# Show project config
workflow config

# Show workflow config
workflow config 01-analysis

# Skip edit prompt
workflow config --no-edit
```

### Sample Output

```
Configuration for workflow: 01-analysis

MODEL: claude-3-opus-4-20250514 (project)
TEMPERATURE: 0.3 (workflow)
MAX_TOKENS: 8192 (default)
STREAM_MODE: true (default)
SYSTEM_PROMPTS: base, research (project)
OUTPUT_FORMAT: md (default)

Workflow-specific settings:
  CONTEXT_PATTERN: data/*.csv
  CONTEXT_FILES: notes.md
  DEPENDS_ON: 00-context
```

### See Also

- [`workflow help run`](#workflow-run) - Execution options
- [`workflow help task`](#workflow-task) - Task mode

---

## `workflow run`

Execute a workflow with full context aggregation and persistence.

### Usage

```bash
workflow run <name> [options]
```

### Arguments

| Argument | Description | Required |
|----------|-------------|----------|
| `<name>` | Workflow name | ✅ Yes |

### Context Options

| Option | Description | Repeatable |
|--------|-------------|------------|
| `--context-file <file>` | Add context file (relative to PWD) | ✅ Yes |
| `--context-pattern <glob>` | Add files matching pattern (relative to PWD) | ✅ Yes |
| `--depends-on <workflow>` | Include output from another workflow | ✅ Yes |

### API Options

| Option | Description |
|--------|-------------|
| `--model <model>` | Override model |
| `--temperature <temp>` | Override temperature (0.0-1.0) |
| `--max-tokens <num>` | Override max tokens |
| `--system-prompts <list>` | Comma-separated prompt names (e.g., "base,research") |
| `--format-hint <ext>` | Output format: md, txt, json, html, etc. |

### Execution Options

| Option | Description |
|--------|-------------|
| `--stream` | Stream output in real-time |
| `--dry-run` | Estimate tokens without API call |
| `-h`, `--help` | Show help |

### Description

Executes workflow by:

1. Finding project root
2. Loading config (global → project → workflow → CLI)
3. Building context from configured sources
4. Making API request
5. Saving output with hardlink in `.workflow/output/`

### Context Sources (Priority Order)

1. `DEPENDS_ON` workflows (from config or CLI)
2. `CONTEXT_PATTERN` (from config, relative to project root)
3. CLI `--context-pattern` (relative to PWD)
4. `CONTEXT_FILES` (from config, relative to project root)
5. CLI `--context-file` (relative to PWD)

### Output

| Location | Description |
|----------|-------------|
| `.workflow/<name>/output/response.<format>` | Primary output location |
| `.workflow/output/<name>.<format>` | Hardlinked copy |
| `.workflow/<name>/output/response.<format>.backup.TIMESTAMP` | Previous versions |

Previous outputs are automatically backed up with timestamps.

### Examples

```bash
# Basic execution
workflow run 01-analysis

# With streaming
workflow run 01-analysis --stream

# With dependencies
workflow run 02-report --depends-on 01-analysis

# With context files
workflow run draft --context-file notes.md --context-file data.csv

# With glob pattern
workflow run analysis --context-pattern "data/2024-01/*.csv"

# Multiple dependencies
workflow run final --depends-on 01-context,02-analysis,03-draft

# Override configuration
workflow run analysis \
  --model claude-3-opus-4-20250514 \
  --temperature 0.5 \
  --max-tokens 8192 \
  --stream

# Estimate tokens first
workflow run analysis --dry-run

# Custom system prompts
workflow run analysis --system-prompts "base,stats,research"

# Different output format
workflow run extract --format-hint json
```

### See Also

- [`workflow config`](#workflow-config) - View configuration
- [`workflow task`](#workflow-task) - Lightweight tasks

---

## `workflow task`

Execute a one-off task without creating workflow directories.

### Usage

```bash
workflow task <name> [options]
workflow task --inline <text> [options]
workflow task -i <text> [options]
```

### Arguments

| Argument | Description | Required |
|----------|-------------|----------|
| `<name>` | Named task from `$WORKFLOW_TASK_PREFIX/<name>.txt` | Mutually exclusive with `--inline` |

### Task Specification

| Option | Description | Required |
|--------|-------------|----------|
| `-i`, `--inline <text>` | Inline task specification | Mutually exclusive with `<name>` |

!!! note "Mutually Exclusive"
    You must provide either `<name>` OR `--inline`, not both.

### Context Options

| Option | Description | Repeatable |
|--------|-------------|------------|
| `--context-file <file>` | Add context file (relative to PWD) | ✅ Yes |
| `--context-pattern <glob>` | Add files matching pattern (relative to PWD) | ✅ Yes |

### API Options

| Option | Description |
|--------|-------------|
| `--model <model>` | Override model |
| `--temperature <temp>` | Override temperature (0.0-1.0) |
| `--max-tokens <num>` | Override max tokens |
| `--system-prompts <list>` | Comma-separated prompt names |
| `--format-hint <ext>` | Output format: md, txt, json, html, etc. |

### Output Options

| Option | Description |
|--------|-------------|
| `--output-file <path>` | Save to file (default: stream to stdout) |
| `--stream` | Stream output (default: true) |
| `--no-stream` | Use single-batch mode |

### Other Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Estimate tokens without API call |
| `-h`, `--help` | Show help |

### Description

Lightweight mode for one-off tasks:

- Does not create workflow directories
- Streams to stdout by default
- No workflow dependencies
- CLI context only

Uses project context if run from within a project:

- Project config (`.workflow/config`)
- Project description (`.workflow/project.txt`)

Otherwise runs in standalone mode with global config only.

### Named Tasks

Create reusable task templates in `$WORKFLOW_TASK_PREFIX/`:

```bash
mkdir -p ~/.config/workflow/tasks
echo "Summarize the key points" > ~/.config/workflow/tasks/summarize.txt
workflow task summarize --context-file notes.md
```

### Examples

```bash
# Named task with context
workflow task summarize --context-file notes.md

# Inline task
workflow task -i "Extract action items" --context-file meeting.md

# Long inline task
workflow task --inline "Analyze the data and create a comprehensive report" \
  --context-pattern "data/*.csv"

# Save output to file
workflow task -i "Analyze data" \
  --context-pattern "data/*.csv" \
  --output-file analysis.md

# Override model
workflow task summarize \
  --model claude-3-opus-4-20250514 \
  --context-file report.md

# Multiple context files
workflow task -i "Compare these approaches" \
  --context-file approach-a.md \
  --context-file approach-b.md

# Use glob pattern
workflow task -i "What are the common themes?" \
  --context-pattern "reports/2024/*.md"

# Batch mode (no streaming)
workflow task -i "Generate JSON" \
  --context-file data.txt \
  --format-hint json \
  --no-stream

# Estimate tokens
workflow task summarize --context-file large-file.md --dry-run
```

### Key Differences from `workflow run`

| Feature | `workflow run` | `workflow task` |
|---------|----------------|-----------------|
| Workflow directory | Required | Not created |
| Default output | File | stdout |
| Default mode | Batch | Streaming |
| Dependencies | Supported | Not supported |
| Workflow config | Used | Not used |
| Context sources | Config + CLI | CLI only |
| Output file | Automatic | Optional |

### See Also

- [`workflow run`](#workflow-run) - Full workflow execution
- [`workflow config`](#workflow-config) - Configuration

---

## `workflow help`

Show help for subcommands.

### Usage

```bash
workflow help [<subcommand>]
```

### Arguments

| Argument | Description | Required |
|----------|-------------|----------|
| `<subcommand>` | Subcommand name | No |

### Behavior

**Without `<subcommand>`:**

Shows main help with all available subcommands.

**With `<subcommand>`:**

Shows detailed help for the specified subcommand.

### Examples

```bash
# Main help
workflow help

# Subcommand-specific help
workflow help init
workflow help run
workflow help task

# Quick help (alternative)
workflow init -h
workflow run -h
workflow task -h
```

---

## Common Option Patterns

### Multiple Context Files

```bash
--context-file file1.md --context-file file2.csv --context-file file3.txt
```

### Multiple Glob Patterns

```bash
--context-pattern "data/*.csv" --context-pattern "notes/*.md"
```

### Multiple Dependencies

```bash
--depends-on workflow1 --depends-on workflow2 --depends-on workflow3

# Or comma-separated
--depends-on workflow1,workflow2,workflow3
```

### System Prompts

```bash
# Comma-separated list
--system-prompts "base,research,stats"

# No spaces
--system-prompts "base,custom"
```

### Temperature Range

| Value | Use Case |
|-------|----------|
| 0.0-0.3 | Analytical, deterministic tasks |
| 0.4-0.7 | Balanced, general purpose |
| 0.8-1.0 | Creative, varied outputs |

### Model Selection

| Model | Use Case |
|-------|----------|
| `claude-3-5-haiku-20241022` | Fast, economical |
| `claude-3-5-sonnet-20241022` | Balanced (default) |
| `claude-3-opus-4-20250514` | Most capable |

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid usage or arguments |

---

## Tips and Tricks

### Combining Options

```bash
# Full configuration
workflow run analysis \
  --context-file data.csv \
  --context-pattern "notes/*.md" \
  --depends-on 00-context \
  --model claude-3-opus-4-20250514 \
  --temperature 0.5 \
  --max-tokens 8192 \
  --system-prompts "base,research,stats" \
  --format-hint json \
  --stream
```

### Dry Run Before Execution

```bash
# Check token estimate
workflow run expensive-analysis --dry-run

# If acceptable, run for real
workflow run expensive-analysis --stream
```

### Quick Iterations

```bash
# Edit task
workflow edit analysis

# Run with streaming
workflow run analysis --stream

# Compare with previous
diff .workflow/analysis/output/response.md \
     .workflow/analysis/output/response.md.backup.*
```

### Scripting Workflows

```bash
#!/bin/bash
# Run workflow pipeline
for wf in 01-preprocess 02-analyze 03-visualize 04-report; do
  echo "Running $wf..."
  workflow run "$wf" --stream || exit 1
done
echo "Pipeline complete!"
```

---

Continue to [Project Structure](project-structure.md) →
