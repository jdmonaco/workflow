# Execution Layer

Technical reference for WireFlow's execution modes, output delivery, and token management.

## Execution Modes

WireFlow provides three execution modes with different persistence and context models:

| Mode | Command | Persistence | Context | Use Case |
|------|---------|-------------|---------|----------|
| **Run** | `wfw run` | Full (workflow directory) | Full cascade | Persistent workflows |
| **Task** | `wfw task` | None (stdout) | Global + project (if available) | One-off queries |
| **Batch** | `wfw batch` | Full (multiple outputs) | Full cascade | Bulk processing |

### Run Mode

Full workflow execution with persistent context and outputs.

**Implementation:** `lib/run.sh` + `lib/execute.sh`

**Characteristics:**

- Configuration cascade: global → project → workflow → CLI
- Output saved to `.workflow/run/<name>/output.<format>`
- Hardlink created at `.workflow/output/<name>.<format>`
- Backups created on re-run
- Dependencies supported (`--depends-on`)
- Default: buffered output

**Flow:**

```
1. Load config cascade
2. Aggregate context (patterns, files, dependencies)
3. Build system prompt
4. Build user content blocks
5. Execute API request
6. Write output + hardlink
```

### Task Mode

Lightweight execution without workflow directories.

**Implementation:** `lib/task.sh`

**Characteristics:**

- Configuration: global + project/ancestor (if in project directory), no workflow config
- Output to stdout (or file with `-ex`)
- No persistence, no backups
- No dependencies
- Default: streaming output

**Flow:**

```
1. Load global config
2. Find project root (non-fatal if not found)
3. Load ancestor + project configs (if in project)
4. Aggregate context (CLI only)
5. Build minimal system prompt
6. Build user content blocks
7. Execute API request
8. Stream to stdout
```

### Batch Mode

Bulk processing via Message Batches API.

**Implementation:** `lib/batch.sh`

**Characteristics:**

- Each input file = separate API request
- Context shared across all requests
- 50% cost reduction via Batches API
- Up to 24-hour processing time
- Results written to `.workflow/output/<name>/`

**Flow:**

```
1. Load config cascade
2. Build requests (one per input file)
3. Submit batch to API
4. Poll for completion
5. Retrieve and write results
```

## Output Delivery

### Streaming vs Buffered

| Feature | Streaming | Buffered |
|---------|-----------|----------|
| Output timing | Real-time | After completion |
| Interruption | Ctrl+C preserves partial | Ctrl+C loses all |
| Display | Terminal (stdout) | Pager (`less`) |
| File writing | Incremental | Atomic |
| Default (run) | No (`--stream` to enable) | Yes |
| Default (task) | Yes (`--no-stream` to disable) | No |

### Streaming Mode

**Implementation:** `lib/api.sh:anthropic_execute_stream()`

Uses chunked transfer encoding with SSE (Server-Sent Events):

```bash
curl -Ns ... \
    -H "Accept: text/event-stream" \
    -d @- < "$request_json"
```

**Processing:**

```bash
while IFS= read -r line; do
    # Parse SSE event
    if [[ "$line" == data:* ]]; then
        json="${line#data: }"
        # Extract delta text
        delta=$(echo "$json" | jq -r '.delta.text // empty')
        # Write to file + stdout
        printf '%s' "$delta" >> "$output_file"
        printf '%s' "$delta"
    fi
done
```

### Buffered Mode

**Implementation:** `lib/api.sh:anthropic_execute_single()`

Single request, complete response:

```bash
response=$(curl ... -d @- < "$request_json")
content=$(echo "$response" | jq -r '.content[0].text')
echo "$content" > "$output_file"
```

### Configuration

```bash
# Global default
STREAM_MODE=true  # or false

# CLI override
wfw run analysis --stream      # Enable streaming
wfw task ... --no-stream       # Disable streaming
```

## Token Management

### Estimation Algorithm

WireFlow uses character-based estimation:

```bash
estimated_tokens=$(( char_count / 4 ))
```

Reasonable approximation for English text.

### Token Count API

Exact counts via `/v1/messages/count_tokens`:

```bash
# lib/api.sh:count_tokens()
curl -X POST "https://api.anthropic.com/v1/messages/count_tokens" \
    -H "anthropic-version: 2023-06-01" \
    -d @- < "$request_json"
```

### Cost Calculation

```bash
cost = (input_tokens / 1_000_000) × cost_per_million
```

**Current pricing (input tokens):**

| Model | Cost/1M tokens |
|-------|----------------|
| Haiku | $1.00 |
| Sonnet | $3.00 |
| Opus | $15.00 |

### Dry Run Mode

Estimate without API call:

```bash
wfw run analysis --count-tokens
```

Shows breakdown by component:

- System prompts
- Task description
- Project description
- Context files (per-file breakdown)
- Dependencies
- Total estimate
- Exact API count (if key available)

### Implementation

```bash
# lib/execute.sh
estimate_tokens() {
    local text="$1"
    local chars=${#text}
    echo $(( chars / 4 ))
}

show_token_breakdown() {
    echo "System prompts: ~$system_tokens tokens"
    echo "Task: ~$task_tokens tokens"
    echo "Context: ~$context_tokens tokens"
    for file in "${context_files[@]}"; do
        echo "  - $file ($(estimate_tokens "$(cat "$file")") tokens)"
    done
    echo "Total: ~$total_tokens tokens"
    echo "Estimated cost: \$$cost"
}
```

## Extended Thinking

### Thinking Mode

Enables Claude to reason before responding.

**Configuration:**

```bash
ENABLE_THINKING=true
THINKING_BUDGET=10240  # Token budget for thinking
```

**CLI:**

```bash
wfw run analysis --enable-thinking --thinking-budget 20000
```

**Implementation:**

```bash
# lib/execute.sh
if [[ "$ENABLE_THINKING" == "true" ]]; then
    thinking_params=$(jq -n \
        --argjson budget "$THINKING_BUDGET" \
        '{type: "enabled", budget_tokens: $budget}')
fi
```

### Effort Levels

Opus 4.5 only. Controls reasoning depth:

| Level | Behavior |
|-------|----------|
| `low` | Quick, minimal reasoning |
| `medium` | Balanced reasoning |
| `high` | Deep, thorough reasoning |

**Configuration:**

```bash
EFFORT=medium
```

**CLI:**

```bash
wfw run analysis --effort high
```

## Error Handling

### Interrupt Handling

**Streaming mode:** Partial output preserved

```bash
trap 'cleanup_on_interrupt' INT
cleanup_on_interrupt() {
    # Finalize partial output
    echo "" >> "$output_file"
    exit 130
}
```

**Buffered mode:** Output lost on interrupt

### API Errors

Common errors and handling:

| Error | Cause | Action |
|-------|-------|--------|
| 401 | Invalid API key | Check ANTHROPIC_API_KEY |
| 429 | Rate limit | Retry with backoff |
| 500 | Server error | Retry |
| Context length | Too many tokens | Reduce context |

### Implementation

```bash
# lib/api.sh
handle_api_error() {
    local status="$1"
    local response="$2"

    case "$status" in
        401) error "Invalid API key" ;;
        429) error "Rate limited - try again later" ;;
        500) error "Server error - retrying..." ;;
        *) error "API error: $(echo "$response" | jq -r '.error.message')" ;;
    esac
}
```

## Mode Comparison

| Feature | Run | Task | Batch |
|---------|-----|------|-------|
| Config cascade | Full | Global + project | Full |
| Dependencies | Yes | No | Yes |
| Output persistence | Yes | No (stdout) | Yes |
| Streaming | Optional | Default | No |
| Cost | Standard | Standard | 50% discount |
| Latency | Real-time | Real-time | Up to 24h |

## See Also

- [API Layer](api.md) - Request building and response handling
- [Content & I/O](content.md) - Context aggregation and output formats
- [Configuration](configuration.md) - Config cascade
- [Architecture](architecture.md) - System design overview
