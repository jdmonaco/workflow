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
wfw run <name> [options]
```

**Arguments:**

| Argument | Description | Required |
|----------|-------------|----------|
| `<name>` | Workflow name | Yes |

**Input Options (primary documents):**

| Option | Short | Description |
|--------|-------|-------------|
| `--input-file <file>` | `-in` | Add input document (repeatable) |
| `--input-pattern <glob>` | | Add input files matching pattern |

**Context Options (background and references):**

| Option | Short | Description |
|--------|-------|-------------|
| `--context-file <file>` | `-cx` | Add context file (repeatable) |
| `--context-pattern <glob>` | | Add context files matching pattern |
| `--depends-on <workflow>` | `-d` | Include output from another workflow |

**API Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--model <model>` | `-m` | Override model |
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

**Examples:**

```bash
wfw run 01-analysis --stream
wfw run 01-analysis --count-tokens
wfw run 01-analysis --dry-run --count-tokens
wfw run report --input-file data.csv --context-file notes.md
```

---

### wfw task

Execute a one-off task outside of existing workflows.

```
wfw task <name>|--inline <text> [options]
```

**Task Specification:**

| Option | Short | Description |
|--------|-------|-------------|
| `<name>` | | Named task from `$WIREFLOW_TASK_PREFIX/<name>.txt` |
| `--inline <text>` | `-i` | Inline task specification |

**Input Options (primary documents to analyze):**

| Option | Short | Description |
|--------|-------|-------------|
| `--input-file <file>` | `-in` | Add input document (repeatable) |
| `--input-pattern <glob>` | | Add input files matching pattern |

**Context Options (supporting materials and references):**

| Option | Short | Description |
|--------|-------|-------------|
| `--context-file <file>` | `-cx` | Add context file (repeatable) |
| `--context-pattern <glob>` | | Add context files matching pattern |

**API Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--model <model>` | `-m` | Override model |
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

**Examples:**

```bash
wfw task summarize --context-file paper.pdf
wfw task -i "Summarize these notes" --context-file notes.md
wfw task analyze --input-pattern "data/*.csv" --stream
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
| **Output** | Saved to `.workflow/<name>/output.<ext>` | Stdout (or file with `-o`) |
| **Configuration** | Full cascade (global → project → workflow) | Global only |
| **Input Files** | `--input-file`, `--input-pattern` | `--input-file`, `--input-pattern` |
| **Context Files** | `--context-file`, `--context-pattern` | `--context-file`, `--context-pattern` |
| **Dependencies** | `--depends-on` supported | Not supported |
| **Default Streaming** | Disabled (batch) | Enabled |

---

## Common Patterns

### Quick Task with Inline Prompt

```bash
wfw task -i "Summarize this document" --context-file report.pdf
```

### Workflow with Multiple Inputs

```bash
wfw run analysis \
    --input-file data.csv \
    --input-file notes.md \
    --context-file methodology.md
```

### Workflow with Glob Patterns

```bash
wfw run review --input-pattern "src/**/*.py" --context-file guidelines.md
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
