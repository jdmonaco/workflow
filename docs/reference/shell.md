# wfw shell

Install WireFlow shell integration (binary symlink, bash completions, and prompt helper).

## Usage

```
wfw shell install
```

## Actions

| Action | Description |
|--------|-------------|
| `install` | Install wfw symlink, bash completions, and prompt helper |

## Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Quick help |

## Installation Paths

All components are installed as symlinks to the source repository, so updates to the repo are automatically reflected.

| Component | Path |
|-----------|------|
| Binary | `${XDG_BIN_HOME:-~/.local/bin}/wfw` |
| Completions | `${XDG_DATA_HOME:-~/.local/share}/bash-completion/completions/wfw` |
| Prompt | `${XDG_DATA_HOME:-~/.local/share}/wireflow/wfw-prompt.sh` |

## Examples

```bash
# Install shell integration
wfw shell install

# Enable completions in current shell (after install)
source ~/.local/share/bash-completion/completions/wfw
```

## Prompt Integration

The prompt helper provides `__wfw_ps1()` for including the current project name in your shell prompt, similar to `__git_ps1()` from git.

### Setup

```bash
# Source the prompt helper (add to ~/.bashrc for persistence)
source ~/.local/share/wireflow/wfw-prompt.sh

# Add project indicator to your prompt
export PS1='\w$(__wfw_ps1 " (%s)")\$ '
```

### Usage

```bash
__wfw_ps1 [format]
```

| Argument | Description | Default |
|----------|-------------|---------|
| `format` | printf format string where `%s` is the project name | `" (%s)"` |

### Examples

```bash
# Default format: " (project-name)"
__wfw_ps1

# Custom format: "[project-name] "
__wfw_ps1 "[%s] "

# In PS1 with git integration
export PS1='\w$(__git_ps1 " (%s)")$(__wfw_ps1 " [wfw:%s]")\$ '
```

When outside a WireFlow project, `__wfw_ps1` outputs nothing and returns silently.

## Notes

- Completions load automatically in new shells that use bash-completion
- If `~/.local/bin` is not in your PATH, the installer will suggest adding it
- Running `install` again will update symlinks if they already exist
- The prompt helper is lightweight and suitable for PS1 (runs on every prompt)

## See Also

- [Installation Guide](../getting-started/installation.md) - Complete setup instructions
