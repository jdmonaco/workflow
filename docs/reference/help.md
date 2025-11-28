# wfw help

Show help for subcommands.

## Usage

```
wfw help [<subcommand>]
```

## Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `<subcommand>` | Subcommand name | None (main help) |

## Help Levels

| Command | Description |
|---------|-------------|
| `wfw help` | Main help with subcommand overview |
| `wfw help <subcommand>` | Detailed help for specific subcommand |
| `wfw <subcommand> -h` | Quick inline help |

## Examples

```bash
# Main help
wfw help

# Detailed subcommand help
wfw help run
wfw help task
wfw help batch

# Quick help
wfw run -h
```

## See Also

- [CLI Reference](index.md) - Complete CLI documentation
