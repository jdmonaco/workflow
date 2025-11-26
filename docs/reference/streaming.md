# Streaming Modes

Reference for streaming and buffered execution modes in Workflow.

## Overview

Workflow supports two execution modes:

- **Streaming mode:** Real-time output as generated
- **Buffered mode:** Complete response at once

## Mode Comparison

| Feature | Streaming | Buffered |
|---------|-----------|----------|
| **Output timing** | Real-time | After completion |
| **Interruption** | Ctrl+C preserves partial output | Ctrl+C loses all output |
| **Display** | Terminal (stdout) | Pager (`less`) |
| **File writing** | Incremental | Atomic |
| **Best for** | Interactive use | Scripts, automation |
| **Default in run** | No (must specify `--stream`) | Yes |
| **Default in task** | Yes | No (must specify `--no-stream`) |

## Streaming Mode

### Enabling Streaming

**Workflow mode:**

```bash
wfw run analysis --stream
```

**Task mode (default):**

```bash
wfw task -i "Summarize" -cx notes.md
# Streaming is automatic
```

### Behavior

- Output appears in real-time as Claude generates it
- Updates terminal continuously
- Can interrupt with Ctrl+C
- Partial output is preserved

### Example Output

```bash
$ workflow run analysis --stream

Building context...
Sending Messages API request...

# Analysis Report

The data shows several interesting patterns:

1. **Temporal trends**: Activity increases
   steadily from January through March, then
   plateaus in April-June...

2. **Distribution**: Values are normally
   distributed with mean=45.2, std=8.7...
^C
```

Press Ctrl+C → Partial output saved.

### Use Cases

- ✅ **Use streaming for:**

- Interactive development
- Watching progress on long responses
- Iterative refinement
- Exploratory work
- Learning what the model generates

## Buffered Mode

### Enabling Buffered Mode

**Workflow mode (default):**

```bash
wfw run analysis  # No --stream flag
```

**Task mode:**

```bash
wfw task -i "Summarize" -cx notes.md --no-stream
```

### Behavior

- Waits for complete response
- No output until finished
- Opens in pager (`less`) when done
- All-or-nothing (interrupt loses output)

### Example Output

```bash
$ workflow run analysis

Building context...
Sending Messages API request...
[... waiting ...]
Response saved to: .workflow/analysis/output.md

[Opens in less with complete response]
```

### Use Cases

- ✅ **Use buffered mode for:**

- Automated scripts
- Consistent file writes
- Non-interactive execution
- Large responses (more reliable)
- Production workflows

## Configuration

### Set Default Mode

**In global config:**

```bash
# ~/.config/wireflow/config
STREAM_MODE=true  # or false
```

**In project config:**

```bash
# .workflow/config
STREAM_MODE=true
```

**In workflow config:**

```bash
# .workflow/analysis/config
STREAM_MODE=false  # Override to buffered
```

### CLI Override

CLI flags always override config:

```bash
# Force streaming (even if config says buffered)
wfw run analysis --stream

# Force buffered (even if config says streaming)
wfw task summarize -cx notes.md --no-stream
```

## Technical Details

### Streaming Implementation

Uses Server-Sent Events (SSE) from Anthropic API:

1. Request sent with `stream=true`
2. Server sends `content_block_delta` events
3. Each delta appended to output in real-time
4. Terminal updated continuously

### File Writing

**Streaming:**

- Opens file at start
- Appends each delta
- Flushes periodically
- Partial output preserved on interrupt

**Buffered:**

- Buffers entire response
- Writes once when complete
- Atomic operation
- Clean interrupt (no partial files)

### Output Display

**Streaming:**

- Writes to stdout (terminal)
- Simultaneously writes to file
- No pager

**Buffered:**

- Saves to file only
- Opens file in `less` when complete
- Pager allows scrolling, searching

## Advanced Usage

### Redirect Streaming Output

```bash
# Send to file and terminal
wfw run analysis --stream | tee custom-output.md

# Send to file only (no terminal)
wfw run analysis --stream > custom-output.md

# Send to pipeline
wfw run extract --format json --stream | jq '.results[]'
```

### Buffered with Custom Display

```bash
# Save without opening pager
wfw run analysis > output.md

# Custom pager
wfw run analysis | bat  # or cat, most, etc.
```

### Silent Execution

```bash
# No output display (buffered)
wfw run analysis 2>/dev/null

# No output display (streaming)
wfw run analysis --stream > /dev/null
```

## Mode Selection Guide

### Choose Streaming When:

- **Developing:** Iterating on tasks, want immediate feedback
- **Long responses:** Want to see progress, not wait blindly
- **Interactive:** Working at terminal, adjusting on the fly
- **Debugging:** Need to see what's being generated

### Choose Buffered When:

- **Scripting:** Running automated workflows
- **Reliability:** Want atomic file writes
- **Consistency:** Need predictable behavior
- **Large responses:** More reliable for very long outputs
- **Non-interactive:** Running in background, cron jobs

## Interrupting Execution

### Streaming Mode

Press **Ctrl+C**:

```
^C
Streaming interrupted. Partial output saved.
```

Partial output is in the file:

```bash
cat .workflow/analysis/output.md
# Shows everything generated before interrupt
```

### Buffered Mode

Press **Ctrl+C**:

```
^C
Request interrupted. No output saved.
```

Nothing written to file (all-or-nothing).

## Troubleshooting

### Streaming Not Working

**Check API connectivity:**

```bash
# Streaming requires working API connection
curl -I https://api.anthropic.com
```

**Check terminal:**

```bash
# Must be a TTY for streaming display
# This won't stream properly:
wfw run analysis --stream < /dev/null
```

**Verify flag:**

```bash
# Ensure --stream is specified (workflow mode)
wfw run analysis --stream
```

### Buffered Mode Hangs

If buffered mode appears to hang:

- Long response generation (wait or interrupt)
- Network issues (check connectivity)
- API rate limiting (check Anthropic console)

Add `--stream` to see progress:

```bash
wfw run analysis --stream  # See what's happening
```

### Output Not Displayed

**Buffered mode:**

- Check pager settings: `echo $PAGER`
- Try different pager: `wfw run analysis | less`

**Streaming mode:**

- Verify output to terminal: `wfw run analysis --stream 2>&1 | less`

### Partial Output Not Saved

Streaming saves incrementally, but check:

```bash
# Verify file exists
ls .workflow/analysis/output.md

# Check size
ls -lh .workflow/analysis/output.md
```

If file is empty, interrupt may have occurred before first flush.

## Performance Considerations

### Streaming

**Advantages:**

- Immediate feedback
- Can interrupt and preserve work
- Better user experience

**Disadvantages:**

- Slight overhead from SSE
- Terminal refresh overhead
- Can't pipeline until complete

### Buffered

**Advantages:**

- Simpler implementation
- More reliable for very long outputs
- Atomic file writes
- Better for automation

**Disadvantages:**

- No progress indication
- Wasted time if interrupted
- Must wait for completion

## Examples

### Interactive Development

```bash
# Edit task
nano .workflow/analysis/task.txt

# Run with streaming
wfw run analysis --stream

# See results immediately
# Adjust task if needed
# Re-run with streaming
```

### Automated Pipeline

```bash
#!/bin/bash
# pipeline.sh - Run analysis pipeline

# Use buffered mode (default) for reliability
wfw run 01-import
wfw run 02-clean --depends-on 01-import
wfw run 03-analyze --depends-on 02-clean
wfw run 04-report --depends-on 03-analyze

echo "Pipeline complete!"
```

### Conditional Streaming

```bash
# Stream if interactive, buffered if scripted
if [ -t 1 ]; then
    wfw run analysis --stream
else
    wfw run analysis
fi
```

### Progress Indication with Buffered Mode

```bash
# Show spinner while buffered mode runs
wfw run expensive-analysis &
PID=$!

while kill -0 $PID 2>/dev/null; do
    echo -n "."
    sleep 1
done

echo " Done!"
```

## See Also

- [Execution Guide](../user-guide/execution.md) - Execution modes
- [CLI Reference](cli-reference.md) - Streaming flags
- [Configuration Guide](../user-guide/configuration.md) - Setting STREAM_MODE

---

All reference pages complete! Continue to [Troubleshooting](../troubleshooting.md) →
