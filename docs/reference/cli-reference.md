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
| `config` | View/edit configuration |
| `run` | Execute workflow with full context |
| `task` | Execute one-off task (lightweight) |
| `cat` | Display workflow output to stdout |
| `open` | Open workflow output in default app (macOS) |
| `list`, `ls` | List workflows in project |
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
- `<name>/` - Individual workflow directories

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

## `workflow cat`

Display workflow output to stdout.

### Usage

```bash
workflow cat <name>
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

Outputs the workflow result file to stdout for viewing or piping to other commands. Useful for quick viewing or shell pipeline processing.

Reads from `.workflow/output/<name>.<format>` (automatically detects format).

### Requirements

Must be run within an initialized workflow project. Workflow must have been run at least once (output must exist).

### Examples

```bash
# View output
workflow cat 01-analysis

# Search in output
workflow cat data-summary | grep "findings"

# Pipe to pager
workflow cat report | less

# Process JSON
workflow cat extract | jq .results

# Save to file
workflow cat draft > published.md
```

### See Also

- [`workflow run`](#workflow-run) - Execute workflows
- [`workflow open`](#workflow-open) - Open in default app (macOS)

---

## `workflow open`

Open workflow output in default application (macOS only).

### Usage

```bash
workflow open <name>
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

Opens the workflow result file using the macOS `open` command, which launches the default application for the file type.

**File type behavior:**

- `.md` files open in default Markdown editor/viewer
- `.json` files open in default JSON viewer
- `.html` files open in default browser
- `.txt` files open in default text editor
- Other formats open with registered application

Reads from `.workflow/output/<name>.<format>` (automatically detects format).

### Requirements

- macOS system (uses `open` command)
- Initialized workflow project
- Workflow output must exist

### Examples

```bash
# Open Markdown in editor
workflow open report

# Open HTML in browser
workflow open data-viz

# Open JSON in viewer
workflow open analysis
```

### Platform Notes

This command is **macOS-specific**. On other platforms:

- **Linux:** Use `workflow cat <name> | xdg-open -` or similar
- **Windows/WSL:** Use `workflow cat <name>` and open manually

The command checks for `open` availability and fails gracefully with a helpful message suggesting `workflow cat` as an alternative.

### See Also

- [`workflow cat`](#workflow-cat) - Display to stdout
- [`workflow run`](#workflow-run) - Execute workflows

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

Display configuration with source tracking. Optionally prompt to edit files.

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
| `--edit` | Prompt to edit configuration files |
| `-h`, `--help` | Show help |

### Behavior

**Without `<name>` (project config):**

- Shows project configuration
- Lists all workflows
- Source tracking: `(global)`, `(ancestor:path)`, `(project)`

**With `<name>` (workflow config):**

- Shows workflow configuration
- Full cascade: global → ancestors → project → workflow
- Shows context sources (`CONTEXT_PATTERN`, `CONTEXT_FILES`, `DEPENDS_ON`)

### Configuration Cascade

```
1. Global:      ~/.config/workflow/config
2. Ancestors:   Parent project configs (oldest to newest)
3. Project:     .workflow/config
4. Workflow:    .workflow/<name>/config
5. CLI flags:   (highest priority)
```

### Source Indicators

| Indicator | Meaning |
|-----------|---------|
| `(global)` | From `~/.config/workflow/config` |
| `(ancestor:path)` | From ancestor project config |
| `(project)` | From `.workflow/config` |
| `(workflow)` | From `.workflow/<name>/config` |

### Examples

```bash
# Show project config
workflow config

# Show workflow config
workflow config 01-analysis

# Show config and prompt to edit
workflow config --edit
```

### Sample Output

```
Current Workflow:
  Name: 01-analysis
  Location: ~/projects/research/.workflow/01-analysis

Configuration Cascade:
  Global:   ~/.config/workflow/config
  Ancestor: ~/projects/.workflow/config
  Project:  ~/projects/research/.workflow/config
  Workflow: ~/projects/research/.workflow/01-analysis/config

Effective Configuration:
  MODEL: claude-opus-4 (ancestor:projects)
  TEMPERATURE: 0.3 (workflow)
  MAX_TOKENS: 8192 (project)
  SYSTEM_PROMPTS: base research (project)
  OUTPUT_FORMAT: md (global)

Context Sources:
  CONTEXT_PATTERN: data/*.csv
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
| `--context-pattern <glob>` | Add files matching pattern (relative to PWD) | ❌ No |
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
| `.workflow/<name>/output.<format>` | Primary output location |
| `.workflow/output/<name>.<format>` | Hardlinked copy |
| `.workflow/<name>/output-TIMESTAMP.<format>` | Previous versions |

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
| `--context-pattern <glob>` | Add files matching pattern (relative to PWD) | ❌ No |

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
diff .workflow/analysis/output/<name>.md \
     .workflow/analysis/output/<name>.md-*.*
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
