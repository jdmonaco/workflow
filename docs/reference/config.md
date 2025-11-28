# wfw config

Display configuration with source tracking.

## Usage

```
wfw config [<name>] [options]
```

## Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `<name>` | Workflow name | None (project config) |

## Options

| Option | Description |
|--------|-------------|
| `--edit` | Prompt to edit configuration files |
| `-h`, `--help` | Quick help |

## Output

Shows effective configuration with source labels indicating where each value comes from:

```
Configuration Paths:
  Global:     ~/.config/wireflow/config                    [✓]
  Project:    ~/project/.workflow/config                   [✓]
  Workflow:   ~/project/.workflow/run/analysis/config      [✓]

Effective Configuration:
  MODEL = claude-opus-4                                    [project]
  TEMPERATURE = 0.3                                        [workflow]
  MAX_TOKENS = 8192                                        [global]
  SYSTEM_PROMPTS = (base research)                         [workflow]
```

**Source labels:** `[builtin]`, `[global]`, `[ancestor]`, `[project]`, `[workflow]`, `[cli]`, `[env]`

## Examples

```bash
# View project configuration
wfw config

# View workflow configuration
wfw config 01-analysis

# View and optionally edit
wfw config --edit
```

## See Also

- [Configuration Guide](../user-guide/configuration.md) - Configuration cascade details
- [`wfw edit`](edit.md) - Direct file editing
