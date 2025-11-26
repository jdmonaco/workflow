# CLI Reference

Complete reference for all WireFlow commands, options, and flags.

## Global Usage

```
wfw <subcommand> [options]
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
| `status` | Show batch processing status |
| `cancel` | Cancel a pending batch |
| `results` | Retrieve completed batch results |
| `cat` | Display workflow output to stdout |
| `open` | Open workflow output in default app (macOS) |
| `tasks` | Manage task templates |
| `list` | List workflows in project |
| `help` | Show help for subcommands |

### Global Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help message |
| `-v`, `--version` | Show version information |

### Quick Help

```bash
wfw help                # Main help
wfw help <subcommand>   # Detailed subcommand help
wfw <subcommand> -h     # Quick subcommand help
```

---

## Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `ANTHROPIC_API_KEY` | Anthropic API key | Yes | None |
| `WIREFLOW_PROMPT_PREFIX` | System prompt directory | No | `~/.config/wireflow/prompts/system` |
| `WIREFLOW_TASK_PREFIX` | Named task directory | No | `~/.config/wireflow/prompts/tasks` |
| `EDITOR` | Text editor for file editing | No | `vi` |

---

## Configuration Files

| Location | Scope |
|----------|-------|
| `~/.config/wireflow/config` | Global defaults |
| `<PROJECT>/.workflow/config` | Project settings |
| `<PROJECT>/.workflow/<NAME>/config` | Workflow-specific |

See [Configuration Guide](../user-guide/configuration.md) for details on the configuration cascade.

---

## Subcommand Reference

### wfw init

Initialize a WireFlow project with `.workflow/` structure.

```
wfw init [<directory>]
```

**Arguments:**

| Argument | Description | Default |
|----------|-------------|---------|
| `<directory>` | Directory to initialize | Current directory |

**Options:**

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Quick help |

**Examples:**

```bash
wfw init .
wfw init my-project
```

---

### wfw new

Create a new workflow in the current project.

```
wfw new <name> [options]
```

**Arguments:**

| Argument | Description | Required |
|----------|-------------|----------|
| `<name>` | Workflow name | Yes |

**Options:**

| Option | Description |
|--------|-------------|
| `--from-task <template>` | Use named task file as a template |
| `-h`, `--help` | Quick help |

**Examples:**

```bash
wfw new 01-outline
wfw new data-analysis --from-task analyze
```

**See Also:** `wfw tasks` to list available task templates.

---

### wfw edit

Edit workflow or project files in text editor.

```
wfw edit [<name>]
```

**Arguments:**

| Argument | Description | Default |
|----------|-------------|---------|
| `<name>` | Workflow name | None (opens project files) |

**Options:**

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Quick help |

**Behavior:**

- Without `<name>`: Opens project files (`project.txt`, `config`)
- With `<name>`: Opens workflow files (`output`, `task.txt`, `config`)

**Examples:**

```bash
wfw edit
wfw edit 01-outline
```

---

### wfw config

Display configuration with source tracking.

```
wfw config [<name>] [options]
```

**Arguments:**

| Argument | Description | Default |
|----------|-------------|---------|
| `<name>` | Workflow name | None (project config) |

**Options:**

| Option | Description |
|--------|-------------|
| `--edit` | Prompt to edit configuration files |
| `-h`, `--help` | Quick help |

**Examples:**

```bash
wfw config
wfw config 01-analysis
wfw config --edit
```

---

### wfw run

Execute a workflow with full context aggregation.

```
wfw run <name> [options] [-- <input>...]
```

**Arguments:**

| Argument | Description | Required |
|----------|-------------|----------|
| `<name>` | Workflow name | Yes |
| `-- <input>...` | Input files/directories (after `--`) | No |

**Input Options (primary documents):**

| Option | Short | Description |
|--------|-------|-------------|
| `--input <path>` | `-in` | Add input file or directory (repeatable) |

**Context Options (background and references):**

| Option | Short | Description |
|--------|-------|-------------|
| `--context <path>` | `-cx` | Add context file or directory (repeatable) |
| `--depends-on <workflow>` | `-d` | Include output from another workflow |

**Model Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--profile <tier>` | | Model tier: fast, balanced, deep |
| `--model <model>` | `-m` | Explicit model override (bypasses profile) |

**Thinking & Effort Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--enable-thinking` | | Enable extended thinking mode |
| `--disable-thinking` | | Disable extended thinking (default) |
| `--thinking-budget <num>` | | Token budget for thinking (min 1024) |
| `--effort <level>` | | Effort level: low, medium, high (Opus 4.5 only) |

**API Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--temperature <temp>` | `-t` | Override temperature (0.0-1.0) |
| `--max-tokens <num>` | | Override max tokens |
| `--system <list>` | `-p` | Comma-separated prompt names |
| `--format <ext>` | `-f` | Output format (md, txt, json, etc.) |
| `--enable-citations` | | Enable Anthropic citations support |
| `--disable-citations` | | Disable citations (default) |

**Output Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--output-file <path>` | `-o` | Copy output to additional path |

**Execution Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--stream` | `-s` | Stream output in real-time |
| `--count-tokens` | | Show token estimation only |
| `--dry-run` | `-n` | Save API request files and inspect in editor |
| `--help` | `-h` | Quick help |

**Batch Processing Options:**

| Option | Description |
|--------|-------------|
| `--batch` | Enable batch mode (one request per input file) |
| `--no-batch` | Disable batch mode (default) |

Batch mode submits each input file as a separate API request via the Message Batches API, providing 50% cost reduction. Results are retrieved asynchronously with `wfw results <name>`.

**Notes:**

Directory paths are expanded non-recursively; all supported files in the directory are included. Duplicate paths are ignored; inputs take precedence over context if the same path appears in both.

**Examples:**

```bash
wfw run 01-analysis --stream
wfw run 01-analysis --profile deep --enable-thinking
wfw run 01-analysis --model claude-opus-4-5 --effort medium
wfw run report -in data.csv -cx notes.md
wfw run analysis --batch -in data/
wfw run analysis -- reports/*.pdf
```

---

### wfw task

Execute a one-off task outside of existing workflows.

```
wfw task <name>|--inline <text> [options] [-- <input>...]
```

**Task Specification:**

| Option | Short | Description |
|--------|-------|-------------|
| `<name>` | | Named task from `$WIREFLOW_TASK_PREFIX/<name>.txt` |
| `--inline <text>` | `-i` | Inline task specification |
| `-- <input>...` | | Input files/directories (after `--`) |

**Input Options (primary documents to analyze):**

| Option | Short | Description |
|--------|-------|-------------|
| `--input <path>` | `-in` | Add input file or directory (repeatable) |

**Context Options (supporting materials and references):**

| Option | Short | Description |
|--------|-------|-------------|
| `--context <path>` | `-cx` | Add context file or directory (repeatable) |

**Model Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--profile <tier>` | | Model tier: fast, balanced, deep |
| `--model <model>` | `-m` | Explicit model override (bypasses profile) |

**Thinking & Effort Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--enable-thinking` | | Enable extended thinking mode |
| `--disable-thinking` | | Disable extended thinking (default) |
| `--thinking-budget <num>` | | Token budget for thinking (min 1024) |
| `--effort <level>` | | Effort level: low, medium, high (Opus 4.5 only) |

**API Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--temperature <temp>` | `-t` | Override temperature |
| `--max-tokens <num>` | | Override max tokens |
| `--system <list>` | `-p` | Comma-separated prompt names |
| `--output-format <ext>` | `-f` | Output format |
| `--enable-citations` | | Enable Anthropic citations support |
| `--disable-citations` | | Disable citations (default) |

**Output Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--output-file <path>` | `-o` | Save to file (default: stdout) |
| `--stream` | | Stream output (default: true) |
| `--no-stream` | | Use batch mode |

**Other Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--count-tokens` | | Show token estimation only |
| `--dry-run` | `-n` | Save API request files and inspect in editor |
| `--help` | `-h` | Quick help |

**Batch Processing Options:**

| Option | Description |
|--------|-------------|
| `--batch` | Enable batch mode (one request per input file) |
| `--no-batch` | Disable batch mode (default) |

**Notes:**

Directory paths are expanded non-recursively; all supported files in the directory are included. Duplicate paths are ignored; inputs take precedence over context if the same path appears in both.

**Examples:**

```bash
wfw task summarize -cx paper.pdf
wfw task -i "Summarize these notes" --profile fast
wfw task analyze -in data/*.csv --enable-thinking
wfw task analyze --batch -- reports/*.pdf
```

**See Also:**

- `wfw tasks` - List available task templates
- `wfw tasks show <name>` - Preview template
- `wfw new <name> --from-task <template>` - Create workflow from template

---

### wfw cat

Display workflow output to stdout.

```
wfw cat <name>
```

**Arguments:**

| Argument | Description | Required |
|----------|-------------|----------|
| `<name>` | Workflow name | Yes |

**Options:**

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Quick help |

**Examples:**

```bash
wfw cat 01-analysis
wfw cat report | less
```

---

### wfw open

Open workflow output in default application (macOS only).

```
wfw open <name>
```

**Arguments:**

| Argument | Description | Required |
|----------|-------------|----------|
| `<name>` | Workflow name | Yes |

**Options:**

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Quick help |

**Examples:**

```bash
wfw open report
wfw open data-viz
```

---

### wfw tasks

Manage task templates.

```
wfw tasks [show|edit <name>]
```

**Commands:**

| Command | Description |
|---------|-------------|
| `tasks` | List available task templates (default) |
| `tasks show <name>` | Display task template in pager |
| `tasks edit <name>` | Open task template in editor |

**Options:**

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Quick help |

**Note:** Default task templates are stored in `~/.config/wireflow/prompts/tasks`.

**Examples:**

```bash
wfw tasks
wfw tasks show summarize
wfw tasks edit summarize
```

**See Also:**

- `wfw task <name>` - Execute task template
- `wfw new <name> --from-task <template>` - Create workflow from template

---

### wfw list

List all workflows in the current project.

```
wfw list
```

**Options:**

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Quick help |

**Example:**

```bash
wfw list
```

---

### wfw status

Show batch processing status.

```
wfw status [<name>]
```

**Arguments:**

| Argument | Description | Default |
|----------|-------------|---------|
| `<name>` | Workflow name | None (project status) |

**Options:**

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Quick help |

**Behavior:**

- Without `<name>`: Shows status of all batches in project
- With `<name>`: Shows detailed status for specific workflow batch
- Outside project: Lists recent batches from Anthropic API

**Examples:**

```bash
wfw status
wfw status my-analysis
```

---

### wfw cancel

Cancel a pending batch.

```
wfw cancel <name>
```

**Arguments:**

| Argument | Description | Required |
|----------|-------------|----------|
| `<name>` | Workflow name | Yes |

**Options:**

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Quick help |

**Note:** Cancellation is asynchronous. Already-completed requests are not affected.

**Examples:**

```bash
wfw cancel my-analysis
```

---

### wfw results

Retrieve results from a completed batch.

```
wfw results <name>
```

**Arguments:**

| Argument | Description | Required |
|----------|-------------|----------|
| `<name>` | Workflow name | Yes |

**Options:**

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Quick help |

**Output:**

Results are written to `.workflow/run/<name>/output/` directory, mirroring the input file structure.

**Examples:**

```bash
wfw results my-analysis
```

---

### wfw help

Show help for subcommands.

```
wfw help [<subcommand>]
```

**Arguments:**

| Argument | Description | Default |
|----------|-------------|---------|
| `<subcommand>` | Subcommand name | None (main help) |

**Examples:**

```bash
wfw help
wfw help run
wfw help task
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | General error |
| `2` | Invalid arguments |

---

## Run vs Task Comparison

| Feature | `wfw run` | `wfw task` |
|---------|-----------|------------|
| **Purpose** | Persistent workflows | One-off tasks |
| **Output** | Saved to `.workflow/run/<name>/output.<ext>` | Stdout (or file with `-o`) |
| **Configuration** | Full cascade (global → project → workflow) | Global only |
| **Input** | `-in/--input`, `-- <files>` | `-in/--input`, `-- <files>` |
| **Context** | `-cx/--context` | `-cx/--context` |
| **Dependencies** | `--depends-on` supported | Not supported |
| **Batch Mode** | `--batch` supported | `--batch` supported |
| **Default Streaming** | Disabled (batch) | Enabled |

---

## Common Patterns

### Quick Task with Inline Prompt

```bash
wfw task -i "Summarize this document" -cx report.pdf
```

### Workflow with Multiple Inputs

```bash
wfw run analysis \
    -in data.csv \
    -in notes.md \
    -cx methodology.md
```

### Workflow with Positional Inputs (after --)

```bash
wfw run review -- src/**/*.py
```

### Workflow with Input Directory

```bash
wfw run analysis -in data/ -cx methodology.md
```

### Chain Workflows with Dependencies

```bash
wfw run 01-research
wfw run 02-outline --depends-on 01-research
wfw run 03-draft --depends-on 02-outline
```

### Dry Run to Inspect Request

```bash
wfw run analysis --dry-run --count-tokens
```

### Batch Process Multiple Files

```bash
# Submit batch job (returns immediately)
wfw run analysis --batch -- reports/*.pdf

# Check status
wfw status analysis

# Retrieve results when complete
wfw results analysis
```
