# wfw task

Execute a one-off task outside of existing workflows.

## Usage

```
wfw task <name>|--inline <text> [options] [-- <input>...]
```

## Task Specification

| Option | Short | Description |
|--------|-------|-------------|
| `<name>` | | Named task from `$WIREFLOW_TASK_PREFIX/<name>.txt` |
| `--inline <text>` | `-i` | Inline task specification |
| `-- <input>...` | | Input files/directories (after `--`) |

## Input Options

| Option | Short | Description |
|--------|-------|-------------|
| `--input <path>...` | `-in` | Add input files/directories (multiple allowed) |

## Context Options

| Option | Short | Description |
|--------|-------|-------------|
| `--context <path>...` | `-cx` | Add context files/directories (multiple allowed) |

## Model Options

| Option | Short | Description |
|--------|-------|-------------|
| `--profile <tier>` | | Model tier: `fast`, `balanced`, `deep` |
| `--model <model>` | `-m` | Explicit model override (bypasses profile) |

## Thinking & Effort Options

| Option | Description |
|--------|-------------|
| `--enable-thinking` | Enable extended thinking mode |
| `--disable-thinking` | Disable extended thinking (default) |
| `--thinking-budget <num>` | Token budget for thinking (min 1024) |
| `--effort <level>` | Effort level: `low`, `medium`, `high` (Opus 4.5 only) |

## API Options

| Option | Short | Description |
|--------|-------|-------------|
| `--temperature <temp>` | `-t` | Override temperature |
| `--max-tokens <num>` | | Override max tokens |
| `--system <list>` | `-p` | Comma-separated prompt names |
| `--format <ext>` | `-f` | Output format |
| `--enable-citations` | | Enable Anthropic citations support |
| `--disable-citations` | | Disable citations (default) |

## Output Options

| Option | Short | Description |
|--------|-------|-------------|
| `--export <path>` | `-ex` | Save to file (default: stdout) |
| `--stream` | | Stream output (default: true) |
| `--no-stream` | | Buffered mode (wait for complete response) |

## Other Options

| Option | Short | Description |
|--------|-------|-------------|
| `--count-tokens` | | Show token estimation only |
| `--dry-run` | `-n` | Save API request files and inspect in editor |
| `--help` | `-h` | Quick help |

## Notes

- Output streams to stdout by default (no persistence)
- Uses global config only (not project/workflow config)
- Dependencies (`--depends-on`) not supported
- Directory paths expanded non-recursively

## Examples

```bash
# Named task template
wfw task summarize -cx paper.pdf

# Inline task with multiple context files
wfw task -i "Summarize these notes" -cx notes.md references.md

# With model options and multiple input files
wfw task analyze -in data/*.csv --enable-thinking

# Save to file
wfw task -i "Extract key points" -cx report.pdf -ex summary.md

# Quick analysis
wfw task -i "What are the main themes?" -cx *.md --profile fast
```

## See Also

- [`wfw tasks`](tasks.md) - List available task templates
- [`wfw run`](run.md) - Persistent workflow execution
- [Execution Modes](../user-guide/execution.md) - Mode comparison
