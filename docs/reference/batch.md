# wfw batch

Submit and manage batch processing jobs via the Anthropic Message Batches API.

## Usage

```
wfw batch <name> [options] [-- <input>...]
wfw batch status [<name>]
wfw batch results <name>
wfw batch cancel <name>
```

## Subcommands

| Subcommand | Description |
|------------|-------------|
| `<name>` | Submit batch job (default action) |
| `status [<name>]` | Show batch status (all or specific workflow) |
| `results <name>` | Retrieve completed batch results |
| `cancel <name>` | Cancel a pending batch |

## Arguments

| Argument | Description | Required |
|----------|-------------|----------|
| `<name>` | Workflow name | Yes |
| `-- <input>...` | Input files/directories (after `--`) | No |

## Input Options

Each input file becomes a separate API request.

| Option | Short | Description |
|--------|-------|-------------|
| `--input <path>...` | `-in` | Add input files/directories (multiple allowed) |

## Context Options

Context is shared across all requests.

| Option | Short | Description |
|--------|-------|-------------|
| `--context <path>...` | `-cx` | Add context files/directories (multiple allowed) |
| `--depends-on <name>...` | `-dp` | Include outputs from other workflows |

## Model Options

| Option | Short | Description |
|--------|-------|-------------|
| `--profile <tier>` | | Model tier: `fast`, `balanced`, `deep` |
| `--model <model>` | `-m` | Explicit model override (bypasses profile) |

## Output Options

| Option | Short | Description |
|--------|-------|-------------|
| `--export <dir>` | `-ex` | Copy results to external directory |

## Other Options

| Option | Short | Description |
|--------|-------|-------------|
| `--count-tokens` | | Show token estimation only |
| `--dry-run` | `-n` | Save request JSON, open in editor |
| `--help` | `-h` | Quick help |

## Batch Characteristics

- **Cost:** 50% discount via Message Batches API
- **Processing:** Up to 24 hours (usually faster)
- **Requests:** Each input file = separate API request
- **Context:** Shared across all requests (included once per request)

## Output Location

Results are written to the workflow's output directory:

```
.workflow/run/<name>/output/
├── <input1-basename>.md
├── <input2-basename>.md
└── ...
```

Results are also copied to `.workflow/output/<name>/` for convenient access.

## Examples

```bash
# Submit batch job
wfw batch my-analysis -in data/*.pdf

# Submit with export directory
wfw batch my-analysis -in reports/ -ex ~/processed/

# Check status of specific workflow
wfw batch status my-analysis

# Check status of all batches
wfw batch status

# Get results when complete
wfw batch results my-analysis

# Cancel pending batch
wfw batch cancel my-analysis
```

## Workflow

1. **Submit:** `wfw batch <name> -in <files>`
2. **Monitor:** `wfw batch status <name>`
3. **Retrieve:** `wfw batch results <name>` (when status shows `ended`)

## See Also

- [`wfw run`](run.md) - Single-request execution
- [Execution Modes](../user-guide/execution.md) - Mode comparison
