# wfw run

Execute a workflow with full context aggregation.

## Usage

```
wfw run <name> [options] [-- <input>...]
```

## Arguments

| Argument | Description | Required |
|----------|-------------|----------|
| `<name>` | Workflow name | Yes |
| `-- <input>...` | Input files/directories (after `--`) | No |

## Input Options

Primary documents to be analyzed or transformed.

| Option | Short | Description |
|--------|-------|-------------|
| `--input <path>` | `-in` | Add input file or directory (repeatable) |

## Context Options

Background materials and references.

| Option | Short | Description |
|--------|-------|-------------|
| `--context <path>` | `-cx` | Add context file or directory (repeatable) |
| `--depends-on <workflow>` | `-d` | Include output from another workflow |

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
| `--temperature <temp>` | `-t` | Override temperature (0.0-1.0) |
| `--max-tokens <num>` | | Override max tokens |
| `--system <list>` | `-p` | Comma-separated prompt names |
| `--format <ext>` | `-f` | Output format (md, txt, json, etc.) |
| `--enable-citations` | | Enable Anthropic citations support |
| `--disable-citations` | | Disable citations (default) |

## Output Options

| Option | Short | Description |
|--------|-------|-------------|
| `--export <path>` | `-ex` | Copy output to external path |

## Execution Options

| Option | Short | Description |
|--------|-------|-------------|
| `--stream` | `-s` | Stream output in real-time |
| `--count-tokens` | | Show token estimation only |
| `--dry-run` | `-n` | Save API request files and inspect in editor |
| `--help` | `-h` | Quick help |

## Output Location

- **Primary:** `.workflow/run/<name>/output.<format>`
- **Hardlink:** `.workflow/output/<name>.<format>`
- **Backups:** `.workflow/run/<name>/output-TIMESTAMP.<format>`

## Notes

- Directory paths are expanded non-recursively
- All supported files in a directory are included
- Duplicate paths are ignored
- Inputs take precedence over context if same path appears in both
- For batch processing, use [`wfw batch`](batch.md) instead

## Examples

```bash
# Basic execution
wfw run 01-analysis --stream

# With model options
wfw run 01-analysis --profile deep --enable-thinking
wfw run 01-analysis --model claude-opus-4-5 --effort medium

# With input and context
wfw run report -in data.csv -cx notes.md

# With dependencies
wfw run 02-synthesis --depends-on 01-analysis

# Token estimation only
wfw run analysis --count-tokens

# Export to external path
wfw run analysis -ex ~/output/analysis.md

# Positional inputs after --
wfw run analysis -- reports/*.pdf
```

## See Also

- [`wfw task`](task.md) - One-off tasks without persistence
- [`wfw batch`](batch.md) - Batch processing multiple files
- [Execution Modes](../user-guide/execution.md) - Mode comparison
