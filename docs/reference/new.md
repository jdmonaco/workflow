# wfw new

Create a new workflow in the current project.

## Usage

```
wfw new <name> [options]
```

## Arguments

| Argument | Description | Required |
|----------|-------------|----------|
| `<name>` | Workflow name | Yes |

## Options

| Option | Description |
|--------|-------------|
| `--from-task <template>` | Use named task file as a template |
| `-h`, `--help` | Quick help |

## What Gets Created

```
.workflow/run/<name>/
├── task.txt    # Task description (your prompt)
└── config      # Workflow-specific configuration
```

## Behavior

- Creates workflow directory in `.workflow/run/`
- Copies task template if `--from-task` specified
- Opens editor with `task.txt` for editing

## Examples

```bash
# Create simple workflow
wfw new 01-outline

# Create workflow from task template
wfw new data-analysis --from-task analyze

# Create workflow with descriptive name
wfw new 00-gather-context
```

## See Also

- [`wfw tasks`](tasks.md) - List available task templates
- [`wfw edit`](edit.md) - Edit workflow files
- [`wfw run`](run.md) - Execute workflow
