# Execution Guide

Learn how to execute workflows and tasks, understand the different execution modes, and master context aggregation.

## Two Execution Modes

Workflow provides two distinct modes for different use cases:

| Feature | Workflow Mode (`run`) | Task Mode (`task`) |
|---------|----------------------|-------------------|
| **Persistence** | Creates directories, saves config | No directories created |
| **Output** | Saved to file | Streams to stdout (optional file) |
| **Context** | Config + CLI + Dependencies | CLI only (+ project if available) |
| **Use Case** | Iterative, persistent work | Quick, one-off queries |
| **Dependencies** | Supports `--depends-on` | No workflow dependencies |
| **Default Streaming** | Batch (file after complete) | Streaming (real-time) |

## Workflow Mode (`run`)

Workflow mode executes persistent workflows with full context aggregation.

### Basic Usage

```bash
workflow run <name>
```

Example:

```bash
workflow run 01-analysis
```

### With Streaming

Stream output in real-time:

```bash
workflow run 01-analysis --stream
```

### With Context Files

Add specific files as context:

```bash
workflow run 01-analysis --context-file data.csv
```

Multiple files:

```bash
workflow run 01-analysis --context-file data.csv --context-file notes.md
```

### With Glob Patterns

Add files matching patterns:

```bash
workflow run 01-analysis --context-pattern "data/*.csv"
```

Multiple patterns:

```bash
workflow run 01-analysis --context-pattern "data/*.csv" --context-pattern "notes/*.md"
```

### With Dependencies

Include outputs from other workflows:

```bash
workflow run 02-synthesis --depends-on 01-analysis
```

Multiple dependencies:

```bash
workflow run 03-report --depends-on 01-analysis,02-synthesis
```

### Override Configuration

Override model, temperature, or tokens:

```bash
workflow run 01-analysis \
  --model claude-3-5-sonnet-20241022 \
  --temperature 0.5 \
  --max-tokens 8192
```

### Custom System Prompts

Override system prompts:

```bash
workflow run 01-analysis --system-prompts "base,research,stats"
```

### Specify Output Format

Change output file extension:

```bash
workflow run 01-analysis --format-hint json  # Creates response.json
workflow run 01-analysis --format-hint txt   # Creates response.txt
```

### Estimate Tokens (Dry Run)

Preview token count and cost without making an API call:

```bash
workflow run 01-analysis --dry-run
```

Output:

```
Token Estimation:
─────────────────────────────────────────────────────────
System prompts:   ~1,200 tokens
  - base.txt
Task:             ~150 tokens
Project description: ~300 tokens
Context:          ~4,500 tokens
  - data/results.csv (2,100 tokens)
  - notes.md (800 tokens)
  - 00-context output (1,600 tokens)

Total estimated:  ~6,150 tokens
Estimated cost:   $0.0185 (claude-3-5-sonnet-20241022)
─────────────────────────────────────────────────────────

Use --stream to execute
```

## Task Mode (`task`)

Task mode provides lightweight, one-off task execution without workflow persistence.

### Inline Tasks

Execute tasks with inline text:

```bash
workflow task -i "Summarize these notes" --context-file notes.md
```

Long form:

```bash
workflow task --inline "Extract key action items from the meeting notes" \
  --context-file meeting.md
```

### Named Tasks

Create reusable task templates in `$WORKFLOW_TASK_PREFIX/`:

```bash
# Setup task directory
mkdir -p ~/.config/workflow/tasks

# Create named task
cat > ~/.config/workflow/tasks/summarize.txt << 'EOF'
Create a concise summary of the provided content including:
1. Main topics discussed
2. Key conclusions
3. Action items or next steps

Format as structured markdown with bullet points.
EOF

# Use named task
workflow task summarize --context-file notes.md
```

### Task Mode with Context

Add context files:

```bash
workflow task -i "Analyze this data" --context-file data.csv
```

Use glob patterns:

```bash
workflow task -i "What are the common themes?" --context-pattern "reports/*.md"
```

### Saving Task Output

By default, task mode streams to stdout. To save to a file:

```bash
workflow task -i "Summarize notes" --context-file notes.md --output-file summary.md
```

### Batch Mode for Tasks

Disable streaming and use single-batch mode:

```bash
workflow task -i "Analyze data" --context-file data.csv --no-stream
```

### Task Mode in Projects

When run from within a workflow project, task mode automatically uses:

- Project configuration (`.workflow/config`)
- Project description (`.workflow/project.txt`)

But it does NOT use workflow directories or dependencies.

### Task Mode Standalone

Outside a project, task mode uses only:

- Global configuration (`~/.config/workflow/config`)
- CLI-provided options

## Context Aggregation

Context is gathered from multiple sources and sent to the API along with your task.

### Context Sources (Priority Order)

For **workflow mode (`run`)**:

1. **System prompts** - From `$WORKFLOW_PROMPT_PREFIX/` directory
2. **Project description** - From `.workflow/project.txt` (if non-empty)
3. **Dependent workflow outputs** - Via `--depends-on` or `DEPENDS_ON` config
4. **Context patterns from config** - `CONTEXT_PATTERN` in workflow config
5. **Context patterns from CLI** - `--context-pattern` flags
6. **Context files from config** - `CONTEXT_FILES` in workflow config
7. **Context files from CLI** - `--context-file` flags

For **task mode (`task`)**:

1. **System prompts** - From `$WORKFLOW_PROMPT_PREFIX/` directory
2. **Project description** - From `.workflow/project.txt` (if in a project)
3. **Context patterns from CLI** - `--context-pattern` flags
4. **Context files from CLI** - `--context-file` flags

### File Path Resolution

**Workflow mode:**

- Config file paths (CONTEXT_PATTERN, CONTEXT_FILES) are relative to **project root**
- CLI paths (`--context-file`, `--context-pattern`) are relative to **PWD**

**Task mode:**

- All CLI paths are relative to **PWD**

### Glob Pattern Examples

```bash
# All CSV files in data/
--context-pattern "data/*.csv"

# All markdown files recursively in notes/
--context-pattern "notes/**/*.md"

# Multiple patterns
--context-pattern "data/*.csv" --context-pattern "*.md"

# Complex pattern
--context-pattern "experiments/*/results.json"
```

### Context Order Matters

Files are processed in the order specified. For narrative context, order carefully:

```bash
workflow run draft \
  --context-file 00-outline.md \
  --context-file 01-introduction.md \
  --context-file 02-methods.md
```

## Streaming vs Batch Mode

### Streaming Mode (Real-Time)

**Workflow mode:**

```bash
workflow run analysis --stream
```

**Task mode (default):**

```bash
workflow task -i "Summarize" --context-file notes.md
```

**Behavior:**

- Output appears in real-time as generated
- Saved to file as it arrives (workflow mode) or stdout (task mode)
- Better user experience for long responses
- Can interrupt with Ctrl+C

### Batch Mode (Single Response)

**Workflow mode (default):**

```bash
workflow run analysis  # No --stream flag
```

**Task mode (opt-in):**

```bash
workflow task -i "Summarize" --context-file notes.md --no-stream
```

**Behavior:**

- Waits for complete response
- Saves entire response at once
- No partial results if interrupted
- Slightly more reliable for large responses

## Workflow Dependencies (`--depends-on`)

Build workflow chains by including outputs from previous workflows.

### Simple Dependency

```bash
workflow run 02-analysis --depends-on 01-context
```

This automatically includes `.workflow/01-context/output/response.*` as context.

### Multiple Dependencies

```bash
workflow run 04-synthesis --depends-on 01-context,02-data,03-models
```

Includes outputs from all three workflows.

### Dependency Configuration

Set dependencies in workflow config:

```bash
# .workflow/04-synthesis/config
DEPENDS_ON=01-context,02-data,03-models
```

Then simply run:

```bash
workflow run 04-synthesis
```

### Override Dependencies

CLI flags override config:

```bash
# Config says: DEPENDS_ON=01-context
# But you want different dependencies:
workflow run 04-synthesis --depends-on 02-data,03-models
```

### Dependency Resolution

- Dependencies must exist and have outputs
- Outputs are included in the order specified
- Use descriptive names to understand the chain
- Tool does NOT detect circular dependencies (don't create them!)

### Building DAGs

Create complex directed acyclic graphs:

```
01-raw-data
     ↓
02-clean-data
     ↓
     ├──→ 03-exploratory
     │         ↓
     └──→ 03-statistical
               ↓
           04-final-report ←── 03-exploratory
```

Execute in order:

```bash
workflow run 02-clean-data --depends-on 01-raw-data --stream
workflow run 03-exploratory --depends-on 02-clean-data --stream
workflow run 03-statistical --depends-on 02-clean-data --stream
workflow run 04-final-report \
  --depends-on 03-exploratory,03-statistical \
  --stream
```

## Output Management

### Output Location (Workflow Mode)

Outputs are saved in two places:

**Primary location:**

```
.workflow/<name>/output/response.<format>
```

**Hardlinked copy:**

```
.workflow/output/<name>.<format>
```

The hardlink means both files point to the same data - no duplication.

### Automatic Backups

Each re-run creates timestamped backups:

```
.workflow/analysis/output/
├── response.md                           # Latest
├── response.md.backup.20241115_143022    # Previous
└── response.md.backup.20241115_141530    # Older
```

### Output Formats

Specify output format with `--format-hint`:

```bash
workflow run analysis --format-hint json    # response.json
workflow run analysis --format-hint txt     # response.txt
workflow run analysis --format-hint html    # response.html
```

Or set in config:

```bash
# .workflow/analysis/config
OUTPUT_FORMAT=json
```

### Cross-Format Dependencies

If a dependency has a different format, it's still included:

```bash
workflow run 01-data --format-hint json  # Creates response.json
workflow run 02-analysis --depends-on 01-data --format-hint md
# Includes the JSON file as context
```

## API Configuration Options

### Model Selection

Available models (as of 2024):

- `claude-3-5-sonnet-20241022` - Balanced (default)
- `claude-3-5-haiku-20241022` - Fast, economical
- `claude-3-opus-4-20250514` - Most capable

```bash
workflow run analysis --model claude-3-opus-4-20250514
```

### Temperature

Controls randomness (0.0 to 1.0):

- `0.0` - Deterministic, focused
- `0.5` - Balanced
- `1.0` - Creative, varied (default)

```bash
workflow run analysis --temperature 0.3
```

### Max Tokens

Maximum response length:

```bash
workflow run analysis --max-tokens 8192
```

Default: 8192 (from config)

## Common Workflows

### Iterative Development

```bash
# First draft
workflow run draft --context-file outline.md --stream

# Review and refine
nano .workflow/draft/task.txt  # Refine instructions

# Re-run with improvements
workflow run draft --context-file outline.md --stream

# Compare outputs
diff .workflow/draft/output/response.md \
     .workflow/draft/output/response.md.backup.*
```

### Progressive Refinement

```bash
# Stage 1: Analysis
workflow run 01-analyze --context-pattern "data/*.csv" --stream

# Stage 2: Initial draft (using analysis)
workflow run 02-draft --depends-on 01-analyze --stream

# Stage 3: Review (using both)
workflow run 03-review --depends-on 01-analyze,02-draft --stream

# Stage 4: Final version (using review)
workflow run 04-final --depends-on 03-review --stream
```

### Quick Experiments

Use task mode for quick tests:

```bash
# Quick summary
workflow task -i "Summarize in 3 bullets" --context-file paper.pdf

# Quick analysis
workflow task -i "What are the main findings?" --context-file results.json

# Quick comparison
workflow task -i "Compare these approaches" \
  --context-file approach-a.md \
  --context-file approach-b.md
```

## Error Handling

### Common Errors

**"No workflow project found":**

```bash
cd /path/to/project  # Navigate to project with .workflow/
workflow run analysis
```

**"Workflow 'xyz' does not exist":**

```bash
workflow list  # Check available workflows
workflow new xyz  # Create it if needed
```

**"ANTHROPIC_API_KEY environment variable is not set":**

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
# Or set in ~/.config/workflow/config
```

**"Context file not found":**

```bash
# Check paths are relative to PWD (for CLI) or project root (for config)
ls -la data.csv  # Verify file exists
workflow run analysis --context-file ./data.csv  # Use explicit path
```

### Interrupting Execution

Press **Ctrl+C** to interrupt during streaming:

- Workflow mode: Partial output is saved
- Task mode: Output printed so far is preserved in terminal

## Best Practices

### When to Use Workflow Mode

✅ Use `workflow run` when:

- Building iterative, evolving content
- Creating workflow dependencies
- Need to compare multiple versions
- Working on persistent analysis or writeup
- Want configuration per workflow

### When to Use Task Mode

✅ Use `workflow task` when:

- Quick, one-off queries
- Temporary analysis
- Exploring ideas
- Don't need to save workflow structure
- Want immediate stdout results

### Context Best Practices

✅ **Do:**

- Use glob patterns for sets of related files
- Order context logically (chronological or hierarchical)
- Include project.txt for domain-specific context
- Use dependencies to chain related work

❌ **Don't:**

- Include unnecessary large files (token costs!)
- Duplicate context (file included multiple ways)
- Create circular dependencies
- Mix incompatible context sources

### Streaming Best Practices

✅ **Use streaming when:**

- You want real-time feedback
- Working interactively
- Long responses expected
- Testing and iterating

✅ **Use batch mode when:**

- Running automated pipelines
- Want atomic file writes
- Scripting workflow execution

## Next Steps

Now that you understand execution:

- **[Configure workflows](configuration.md)** to customize behavior
- **[Use system prompts](system-prompts.md)** for specialized behavior
- **[See examples](examples.md)** of real-world patterns

---

Continue to [Configuration Guide](configuration.md) →
