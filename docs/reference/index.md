# CLI Reference

Complete reference for all WireFlow commands, options, and flags.

## Global Usage

```
wfw <subcommand> [options]
```

### Available Subcommands

| Subcommand | Description |
|------------|-------------|
| [`init`](init.md) | Initialize wireflow project |
| [`new`](new.md) | Create new workflow |
| [`edit`](edit.md) | Edit project or workflow files |
| [`config`](config.md) | View/edit configuration |
| [`run`](run.md) | Execute workflow with full context |
| [`task`](task.md) | Execute one-off task (lightweight) |
| [`batch`](batch.md) | Submit and manage batch processing jobs |
| [`cat`](cat.md) | Display workflow output to stdout |
| [`open`](open.md) | Open workflow output in default app (macOS) |
| [`tasks`](tasks.md) | Manage task templates |
| [`list`](list.md) | List workflows in project |
| [`help`](help.md) | Show help for subcommands |

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

## Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `ANTHROPIC_API_KEY` | Anthropic API key | Yes | None |
| `WIREFLOW_PROMPT_PREFIX` | System prompt directory | No | `~/.config/wireflow/prompts` |
| `WIREFLOW_TASK_PREFIX` | Named task directory | No | `~/.config/wireflow/tasks` |
| `EDITOR` | Text editor for file editing | No | `vi` |

## Configuration Files

| Location | Scope |
|----------|-------|
| `~/.config/wireflow/config` | Global defaults |
| `<PROJECT>/.workflow/config` | Project settings |
| `<PROJECT>/.workflow/run/<NAME>/config` | Workflow-specific |

See [Configuration Guide](../user-guide/configuration.md) for details on the configuration cascade.

## Run vs Task Comparison

| Feature | `wfw run` | `wfw task` |
|---------|-----------|------------|
| **Purpose** | Persistent workflows | One-off tasks |
| **Output** | Saved to `.workflow/run/<name>/output.<ext>` | Stdout (or file with `-ex`) |
| **Configuration** | Full cascade (global → project → workflow) | Global only |
| **Dependencies** | `--depends-on` supported | Not supported |
| **Batch API** | Use `wfw batch` instead | Not supported |
| **Default Streaming** | Disabled (buffered) | Enabled |

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | General error |
| `2` | Invalid arguments |
