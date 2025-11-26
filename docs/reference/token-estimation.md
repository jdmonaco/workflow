# Token Estimation

Reference for token estimation and cost calculation in Workflow.

## Overview

Before making API calls, Workflow estimates token usage and cost. This helps you:

- Avoid unexpectedly large API bills
- Optimize context size
- Plan workflow execution

## Automatic Estimation

Every workflow run shows token estimates:

```
Building context...
  Adding system prompts...
    - base.txt
  Adding project description...
  Adding dependencies...
    - 00-context (00-context.md)
  Adding files from pattern: data/*.csv
    - data/results.csv
  Adding files from CLI...
    - notes.md

Estimated system tokens: ~1,200
Estimated task tokens: ~150
Estimated project description tokens: ~300
Estimated context tokens: ~4,500
  - 00-context output: 1,600
  - data/results.csv: 2,100
  - notes.md: 800

Total estimated input tokens: ~6,150
Estimated cost: ~$0.0185 (claude-opus-4-5-20251101)

Sending Messages API request...
```

## Dry Run Mode

Get estimates without making API calls:

```bash
wfw run analysis --count-tokens
```

Output:

```
Token Estimation:
─────────────────────────────────────────────────────────
System prompts:   ~1,200 tokens
Task:             ~150 tokens
Project:          ~300 tokens
Context:          ~4,500 tokens
  - 00-context.md (1,600 tokens)
  - data/results.csv (2,100 tokens)
  - notes.md (800 tokens)

Total estimated:  ~6,150 tokens
Estimated cost:   $0.0185 (claude-opus-4-5-20251101)
─────────────────────────────────────────────────────────

Use --stream to execute
```

## Estimation Formula

Workflow uses a simple character-based estimation:

```
estimated_tokens = characters / 4
```

This is a reasonable approximation for English text. Actual tokenization may vary slightly.

## Cost Calculation

Costs are calculated using current Anthropic API pricing:

**Input token costs (see [Anthropic pricing](https://anthropic.com/pricing) for current rates):**

| Model | Cost per 1M tokens |
|-------|-------------------|
| Claude Haiku 4.5 | $1.00 |
| Claude Sonnet 4.5 | $3.00 |
| Claude Opus 4.5 | $5.00 |

**Output tokens:** Not estimated (depends on response length)

### Formula

```
cost = (estimated_input_tokens / 1,000,000) × cost_per_million
```

### Example

6,150 input tokens with Sonnet:

```
cost = (6,150 / 1,000,000) × $3.00 = $0.01845
```

Displayed as: `~$0.0185`

## Token Breakdown

Estimates show token contribution from each source:

### System Components

**System prompts:**

```
System prompts: ~1,200 tokens
  - base.txt (800 tokens)
  - research.txt (400 tokens)
```

**Task description:**

```
Task: ~150 tokens
```

**Project description:**

```
Project: ~300 tokens
```

### Context Components

**Dependencies:**

```
Dependencies: ~1,600 tokens
  - 00-context.md (1,600 tokens)
```

**Pattern-matched files:**

```
Pattern files: ~2,900 tokens
  - data/file1.csv (1,500 tokens)
  - data/file2.csv (1,400 tokens)
```

**Explicit files:**

```
Explicit files: ~800 tokens
  - notes.md (800 tokens)
```

## Managing Token Usage

### Reduce System Prompt Size

```bash
# Use fewer prompts
SYSTEM_PROMPTS=(base)  # Instead of (base research stats writing)

# Or create concise custom prompts
```

### Reduce Context Size

**Use specific patterns:**

```bash
# Instead of:
CONTEXT_PATTERN="data/**/*.csv"  # All CSV files recursively

# Use:
CONTEXT_PATTERN="data/2024-01/*.csv"  # Specific month
```

**Use explicit files:**

```bash
# Instead of broad pattern
CONTEXT_FILES=("data/summary.csv")  # Just the summary
```

**Use workflow dependencies:**

```bash
# Instead of including all raw data
# Create summarization workflow first
wfw run 01-summarize  # Processes all data → summary
wfw run 02-analyze --depends-on 01-summarize  # Uses summary only
```

### Split Large Tasks

Break large tasks into smaller workflows:

```bash
# Instead of one huge workflow with all context
# Split into stages:
wfw run 01-gather-data   # Process raw data
wfw run 02-analyze       # Analyze (depends on 01)
wfw run 03-visualize     # Visualize (depends on 02)
wfw run 04-writeup       # Write (depends on all)
```

Each stage has manageable context.

## Token Limits

### API Limits

Different models have different context windows:

| Model | Input Token Limit |
|-------|------------------|
| Claude Haiku 4.5 | 200K tokens |
| Claude Sonnet 4.5 | 200K tokens |
| Claude Opus 4.5 | 200K tokens |

### Practical Limits

While the limit is 200K tokens:

- **Cost** increases linearly with tokens
- **Response quality** may decrease with excessive context
- **Latency** increases with more tokens

**Recommended:** Keep input under 50K tokens for best results and reasonable cost.

## Output Tokens

WireFlow does not estimate output tokens (they depend on task complexity and model behavior).

### Controlling Output Length

Limit response size with `MAX_TOKENS`:

```bash
MAX_TOKENS=4096          # In config
wfw run analysis --max-tokens 4096   # Or via CLI
```

**Default:** 8192 tokens. Output token costs are typically higher than input costs - see [Anthropic pricing](https://anthropic.com/pricing) for current rates.

## Monitoring Actual Usage

Workflow displays actual token counts after API calls:

```
API Response received (6,245 input tokens, 1,832 output tokens)
```

Compare with estimates to gauge accuracy:

- **Estimated:** 6,150 input tokens
- **Actual:** 6,245 input tokens
- **Accuracy:** ~98.5%

## Cost Optimization Strategies

### Use Appropriate Model

| Task Type | Recommended Model | Cost |
|-----------|------------------|------|
| Simple queries | Haiku | Lowest |
| General tasks | Sonnet | Balanced |
| Complex reasoning | Opus | Highest |

Don't use Opus for tasks Haiku can handle.

### Optimize Context

- Remove unnecessary files
- Use summaries instead of raw data
- Split large tasks into stages

### Batch Operations

Instead of many small API calls, combine into larger workflows:

```bash
# Inefficient: Many small calls
for file in data/*.csv; do
  wfw task -i "Summarize" -cx "$file"
done

# Better: One call with all files
wfw run summarize-all -cx "data/*.csv"
```

### Cache Intermediate Results

Use workflow dependencies to avoid reprocessing:

```bash
# Once:
wfw run expensive-analysis

# Multiple times (no reprocessing):
wfw run report-1 --depends-on expensive-analysis
wfw run report-2 --depends-on expensive-analysis
wfw run report-3 --depends-on expensive-analysis
```

## Troubleshooting

### Estimate Shows Zero

Check that:

- Task file exists and has content
- Context files exist and match patterns
- Dependencies have outputs

```bash
# Verify task
cat .workflow/analysis/task.txt

# Verify context
ls data/*.csv

# Verify dependencies
ls .workflow/dependency/output/
```

### Estimate Much Higher Than Expected

- Check what's included in context
- Look for unexpectedly large files
- Verify glob patterns aren't too broad

```bash
wfw run analysis --count-tokens  # See detailed breakdown
```

### API Call Exceeds Limit

If estimated tokens > 200K:

- Split into multiple workflows
- Reduce context size
- Use summarization

## Examples

### Small Task

```
System: 800 tokens
Task: 50 tokens
Context: 1,200 tokens (2 files)

Total: ~2,050 tokens
Cost: ~$0.006 (Sonnet)
```

### Medium Task

```
System: 1,200 tokens
Task: 200 tokens
Project: 300 tokens
Context: 8,500 tokens (3 dependencies, 5 files)

Total: ~10,200 tokens
Cost: ~$0.031 (Sonnet)
```

### Large Task

```
System: 1,500 tokens
Task: 300 tokens
Project: 500 tokens
Context: 45,000 tokens (10 dependencies, 20 data files)

Total: ~47,300 tokens
Cost: ~$0.142 (Sonnet)
```

### Optimization

**Before:**

```
Context: 45,000 tokens (20 data files)
Cost: ~$0.142
```

**After (using intermediate summarization):**

```
Workflow 1: Summarize all data
  Context: 45,000 tokens
  Cost: ~$0.142

Workflow 2: Final analysis
  Context: 3,000 tokens (summary only)
  Cost: ~$0.009

Total: $0.151 (similar, but reusable summary)
```

If running final analysis 10 times:

- **Before:** 10 × $0.142 = $1.42
- **After:** $0.142 + (10 × $0.009) = $0.232

**Savings:** $1.19 (83% reduction)

## See Also

- [Execution Guide](../user-guide/execution.md) - Using --count-tokens
- [Context Aggregation](context-aggregation.md) - Managing context
- [Configuration Guide](../user-guide/configuration.md) - Setting MAX_TOKENS

---

Continue to [Streaming Modes](streaming.md) →
