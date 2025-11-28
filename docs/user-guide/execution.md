# Execution Modes

WireFlow provides three execution modes for different use cases.

## Mode Comparison

| Feature | Run Mode | Task Mode | Batch Mode |
|---------|----------|-----------|------------|
| **Command** | `wfw run` | `wfw task` | `wfw batch` |
| **Persistence** | Saves to workflow dir | Streams to stdout | Saves to workflow dir |
| **Context** | Config + CLI + Deps | CLI only | Same as run |
| **Dependencies** | Yes | No | Yes |
| **Use Case** | Iterative work | Quick one-offs | Bulk processing |
| **Cost** | Standard | Standard | 50% savings |

## Run Mode (`wfw run`)

Execute persistent workflows with full context aggregation.

### Basic Usage

```bash
wfw run 01-analysis
wfw run 01-analysis --stream     # Real-time output
```

### With Files

```bash
# Context files
wfw run 01-analysis -cx data.csv -cx notes.md

# Input files
wfw run 01-analysis -in report.pdf

# Glob patterns
wfw run 01-analysis -cx "data/*.csv" -in "docs/*.pdf"
```

### With Dependencies

Include outputs from previous workflows:

```bash
wfw run 02-synthesis --depends-on 01-analysis
wfw run 03-report --depends-on 01-analysis 02-synthesis
```

Or configure in workflow:
```bash
# .workflow/run/04-synthesis/config
DEPENDS_ON=(01-context 02-data 03-models)
```

### Override Configuration

```bash
wfw run analysis --profile deep --temperature 0.5
wfw run analysis --model claude-opus-4-5 --max-tokens 8192
wfw run analysis --system "base,research,stats"
wfw run analysis --format json
```

### Preview Options

```bash
wfw run analysis --count-tokens   # Estimate token usage
wfw run analysis --dry-run        # Save prompts for inspection
```

### Output Management

**Locations:**
- Primary: `.workflow/run/<name>/output.<format>`
- Hardlink: `.workflow/output/<name>.<format>`

**Automatic backups:**
```
.workflow/run/analysis/output/
├── output.md                   # Latest
├── output-20241115143022.md    # Previous
└── output-20241115141530.md    # Older
```

**View output:**
```bash
wfw cat analysis          # Display output
wfw open analysis         # Open in editor
```

## Task Mode (`wfw task`)

Lightweight, one-off task execution without workflow persistence.

### Inline Tasks

```bash
wfw task -i "Summarize these notes" -cx notes.md
wfw task -i "Extract key action items" -cx meeting.md
wfw task -i "Compare these approaches" -cx a.md -cx b.md
```

### Named Tasks

Create reusable templates in `~/.config/wireflow/tasks/`:

```bash
wfw task summarize -cx notes.md
wfw task analyze -cx data.csv
wfw task review -cx script.py
```

### Saving Output

```bash
wfw task -i "Summarize" -cx notes.md -ex summary.md
wfw task -i "Analyze" -cx data.csv --no-stream
```

### Project Context

When run inside a wireflow project, task mode uses:
- Project configuration (`.workflow/config`)
- Project description (`.workflow/project.txt`)

Outside a project, only global config is used.

## Batch Mode (`wfw batch`)

Process workflows at 50% cost savings using the Message Batches API.

### Submit Jobs

```bash
wfw batch submit my-workflow
wfw batch submit my-workflow -cx extra-data.csv
```

### Check Status

```bash
wfw batch status my-workflow
```

Output shows batch state: `in_progress`, `ended`, `canceling`, etc.

### Retrieve Results

```bash
wfw batch results my-workflow
```

Results are saved to `.workflow/run/<name>/output.<format>` like run mode.

### Batch Characteristics

- **Cost:** 50% discount vs standard API
- **Processing:** Up to 24 hours (usually faster)
- **Best for:** Large document processing, batch analysis, cost-sensitive work
- **Context:** Same as run mode (config + CLI + dependencies)

## Model Selection

### Profiles

```bash
wfw run analysis --profile fast       # Haiku
wfw run analysis --profile balanced   # Sonnet (default)
wfw run analysis --profile deep       # Opus
```

### Explicit Model

```bash
wfw run analysis --model claude-opus-4-5-20251101
```

### Extended Thinking

Enable for complex multi-step reasoning (Sonnet/Opus 4.5):

```bash
wfw run analysis --enable-thinking --thinking-budget 15000
```

## Streaming vs Buffered

**Streaming (real-time):**
```bash
wfw run analysis --stream
wfw task -i "Summarize" -cx notes.md   # Default for task
```

**Buffered (single response):**
```bash
wfw run analysis                        # Default for run
wfw task -i "Summarize" --no-stream
```

## Common Patterns

### Iterative Development

```bash
wfw run draft -cx outline.md --stream
wfw edit draft                          # Refine task.txt
wfw run draft -cx outline.md --stream   # Re-run
wfw cat draft                           # View output
```

### Progressive Pipeline

```bash
wfw run 01-analyze -cx "data/*.csv" --stream
wfw run 02-draft --depends-on 01-analyze --stream
wfw run 03-review --depends-on 01-analyze 02-draft --stream
wfw run 04-final --depends-on 03-review --stream
```

### Quick Experiments

```bash
wfw task -i "Summarize in 3 bullets" -cx paper.pdf
wfw task -i "What are the main findings?" -cx results.json
```

## When to Use Each Mode

**Run mode when:**
- Building iterative, evolving content
- Creating workflow dependencies
- Need to compare versions
- Want per-workflow configuration

**Task mode when:**
- Quick, one-off queries
- Exploring ideas
- Don't need persistence

**Batch mode when:**
- Processing many documents
- Cost is a concern (50% savings)
- Can wait for async processing

## Error Handling

| Error | Solution |
|-------|----------|
| "No workflow project found" | Navigate to a project with `.workflow/` |
| "Workflow 'xyz' does not exist" | Run `wfw list` to check, `wfw new xyz` to create |
| "ANTHROPIC_API_KEY not set" | Export the key or set in config |
| "Context file not found" | Check paths (CLI: relative to PWD, config: relative to project root) |

**Interrupt:** Press Ctrl+C. Partial output is saved in streaming mode.

---

Continue to [Configuration](configuration.md) →
