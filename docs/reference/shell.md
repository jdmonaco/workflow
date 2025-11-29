# wfw shell

Manage WireFlow shell integration (binary symlink, bash completions, and prompt helper).

## Usage

```
wfw shell <install|doctor|uninstall>
```

## Actions

| Action | Description |
|--------|-------------|
| `install` | Install symlinks (skip if already installed) |
| `doctor` | Force reinstall symlinks + diagnose completions and prompt |
| `uninstall` | Remove symlinks and check for config references |

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
# First-time installation
wfw shell install

# Fix broken symlinks + diagnose setup
wfw shell doctor

# Remove all symlinks
wfw shell uninstall

# Enable completions in current shell (after install)
source ~/.local/share/bash-completion/completions/wfw
```

## Doctor Diagnostics

The `doctor` action performs the following checks:

1. **Force reinstall symlinks** - Replaces existing symlinks with current targets (useful after moving the repo)
2. **Check bash-completion** - Verifies `_wireflow` completion function is loaded; provides OS-specific setup hints if not
3. **Check PS1/prompt** - Reports whether `__wfw_ps1` is in your PS1 and whether the function is defined

Example output:

```
Installed: ~/.local/bin/wfw -> /path/to/wireflow/wireflow.sh
Installed: ~/.local/share/bash-completion/completions/wfw -> ...
Installed: ~/.local/share/wireflow/wfw-prompt.sh -> ...

Warning: Completions not loaded in current shell
  Ensure bash-completion is installed and sourced:
    brew install bash-completion@2
  ...

Prompt: __wfw_ps1 not in PS1 (optional)
  To enable: source ~/.local/share/wireflow/wfw-prompt.sh
  Then: export PS1='\w$(__wfw_ps1 " (%s)")\$ '
```

## Uninstall

The `uninstall` action removes symlinks and scans shell config files for wireflow references:

```bash
wfw shell uninstall
```

It checks `~/.bashrc`, `~/.bash_profile`, and `~/.profile` for references to `wfw`, `wireflow`, or `__wfw_ps1` and displays any matches for manual cleanup.

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
- Use `install` for first-time setup; use `doctor` to fix or diagnose issues
- The prompt helper is lightweight and suitable for PS1 (runs on every prompt)

## See Also

- [Installation Guide](../getting-started/installation.md) - Complete setup instructions
