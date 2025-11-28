# wfw cat

Display workflow output to stdout.

## Usage

```
wfw cat <name>
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

Reads from `.workflow/run/<name>/output.<format>` (or hardlink at `.workflow/output/<name>.<format>`).

## Examples

```bash
# Display output
wfw cat 01-analysis

# Pipe to pager
wfw cat report | less

# Pipe to other tools
wfw cat summary | grep "key points"
```

## See Also

- [`wfw open`](open.md) - Open output in default application
- [`wfw edit`](edit.md) - Edit workflow files
