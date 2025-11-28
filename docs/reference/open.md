# wfw open

Open workflow output in default application (macOS only).

## Usage

```
wfw open <name>
```

## Arguments

| Argument | Description | Required |
|----------|-------------|----------|
| `<name>` | Workflow name | Yes |

## Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Quick help |

## Output Location

Opens `.workflow/run/<name>/output.<format>` (or hardlink at `.workflow/output/<name>.<format>`).

## Platform Support

This command uses macOS `open` command and is only available on macOS.

## Examples

```bash
# Open markdown output in default app
wfw open report

# Open visualization output
wfw open data-viz
```

## See Also

- [`wfw cat`](cat.md) - Display output to stdout
- [`wfw edit`](edit.md) - Edit workflow files
