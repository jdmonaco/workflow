# wfw tasks

List and manage task templates.

## Usage

```
wfw tasks [show|edit <name>]
```

## Subcommands

| Command | Description |
|---------|-------------|
| `tasks` | List available task templates (default) |
| `tasks show <name>` | Display task template in pager |
| `tasks edit <name>` | Open task template in editor |

## Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Quick help |

## Template Location

Task templates are stored in `$WIREFLOW_TASK_PREFIX` (default: `~/.config/wireflow/tasks/`).

Each template is a `.txt` file containing the task prompt.

## Examples

```bash
# List all available templates
wfw tasks

# Preview a template
wfw tasks show summarize

# Edit a template
wfw tasks edit summarize

# Create new template (use editor)
wfw tasks edit my-new-task
```

## See Also

- [`wfw task`](task.md) - Execute task template
- [`wfw new`](new.md) - Create workflow from template (`--from-task`)
