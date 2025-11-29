# wfw shell

Install WireFlow shell integration (binary symlink and bash completions).

## Usage

```
wfw shell install
```

## Actions

| Action | Description |
|--------|-------------|
| `install` | Install wfw symlink and bash completions |

## Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Quick help |

## Installation Paths

Both are installed as symlinks to the source repository, so updates to the repo are automatically reflected.

| Component | Path |
|-----------|------|
| Binary | `${XDG_BIN_HOME:-~/.local/bin}/wfw` |
| Completions | `${XDG_DATA_HOME:-~/.local/share}/bash-completion/completions/wfw` |

## Examples

```bash
# Install shell integration
wfw shell install

# Enable completions in current shell (after install)
source ~/.local/share/bash-completion/completions/wfw
```

## Notes

- Completions load automatically in new shells that use bash-completion
- If `~/.local/bin` is not in your PATH, the installer will suggest adding it
- Running `install` again will update symlinks if they already exist

## See Also

- [Installation Guide](../getting-started/installation.md) - Complete setup instructions
