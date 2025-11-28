# wfw edit

Edit workflow or project files in text editor.

## Usage

```
wfw edit [<name>]
```

## Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `<name>` | Workflow name | None (opens project files) |

## Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Quick help |

## Behavior

**Without `<name>` (project mode):**

- Opens `project.txt` and `config` from `.workflow/`

**With `<name>` (workflow mode):**

- Opens `output`, `task.txt`, and `config` from `.workflow/run/<name>/`

Files are opened in `$EDITOR` (defaults to `vi`).

## Examples

```bash
# Edit project files
wfw edit

# Edit workflow files
wfw edit 01-outline

# Edit specific workflow
wfw edit data-analysis
```

## See Also

- [`wfw config`](config.md) - View configuration with source tracking
- [Projects Guide](../user-guide/projects.md) - Project structure
