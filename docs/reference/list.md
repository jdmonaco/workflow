# wfw list

List all workflows in the current project.

## Usage

```
wfw list
```

## Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Quick help |

## Output

Lists workflow names from `.workflow/run/` directory, one per line.

## Examples

```bash
# List workflows
wfw list

# Count workflows
wfw list | wc -l

# Filter workflows
wfw list | grep analysis
```

## See Also

- [`wfw new`](new.md) - Create new workflow
- [`wfw run`](run.md) - Execute workflow
