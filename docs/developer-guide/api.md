# API Layer

Technical reference for WireFlow's Anthropic API interaction, including request building, response handling, and advanced features.

## Overview

WireFlow uses the Anthropic Messages API for all Claude interactions.

**Implementation:** `lib/api.sh`

**Endpoints:**
- `/v1/messages` - Standard requests (streaming/buffered)
- `/v1/messages/count_tokens` - Token counting
- `/v1/messages/batches` - Batch processing

## Request Architecture

### JSON-First Design

Content blocks are constructed as JSON, avoiding bash string parsing issues:

```bash
# Build blocks incrementally
build_content_block "$file" "$category" >> "$blocks_file"

# Assemble final request
jq -n --slurpfile system "$system_file" \
      --slurpfile content "$content_file" \
      '{
        model: $model,
        max_tokens: $max_tokens,
        system: $system,
        messages: [{role: "user", content: $content}]
      }'
```

### Content Block Structure

**System blocks:**
```json
[
  {"type": "text", "text": "[meta prompt]"},
  {"type": "text", "text": "[system prompts]", "cache_control": {"type": "ephemeral"}},
  {"type": "text", "text": "[project description]", "cache_control": {"type": "ephemeral"}},
  {"type": "text", "text": "Today's date: YYYY-MM-DD"}
]
```

**User content blocks:**
```json
[
  {"type": "document", "source": {"type": "base64", "media_type": "application/pdf", "data": "..."}},
  {"type": "text", "text": "<metadata type=\"context\">...</metadata>\n\n[content]"},
  {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": "..."}},
  {"type": "text", "text": "[task prompt]"}
]
```

### Parameter Passing

Large payloads passed via files to avoid bash arg limits:

```bash
# Individual image blocks
printf '%s' "$base64_data" | jq -Rs '{
    type: "image",
    source: {type: "base64", media_type: $media, data: .}
}'

# Array assembly via --slurpfile
jq --slurpfile blocks "$blocks_file" '$blocks[0]'

# API request via stdin
curl -d @- < "$request_json"
```

## Request Functions

### Standard Request

**Streaming:**
```bash
# lib/api.sh:anthropic_execute_stream()
anthropic_execute_stream() {
    # Uses associative array for parameters
    # Builds JSON payload with jq
    # Sends request with curl -Ns (no-buffer, silent)

    echo "$json_payload" | curl -Ns https://api.anthropic.com/v1/messages \
        "${curl_headers[@]}" \
        -d @- | while IFS= read -r line; do
            # SSE parsing inline
        done
}
```

**Buffered:**
```bash
# lib/api.sh:anthropic_execute_single()
anthropic_execute_single() {
    # Uses associative array for parameters
    # Builds JSON payload with jq

    response=$(echo "$json_payload" | curl -s https://api.anthropic.com/v1/messages \
        "${curl_headers[@]}" \
        -d @-)
}
```

### Token Counting

```bash
# lib/api.sh:anthropic_count_tokens()
anthropic_count_tokens() {
    # Uses associative array for parameters
    # Builds minimal request payload

    response=$(echo "$json_payload" | curl -s https://api.anthropic.com/v1/messages/count_tokens \
        "${curl_headers[@]}" \
        -d @-)

    echo "$response" | jq -r '.input_tokens'
}
```

### Batch Requests

```bash
# lib/api.sh:anthropic_create_batch()
anthropic_create_batch() {
    # Uses associative array for parameters
    # Builds batch request payload with requests array

    response=$(echo "$json_payload" | curl -s https://api.anthropic.com/v1/messages/batches \
        "${curl_headers[@]}" \
        -d @-)
}
```

**Additional batch functions in `lib/api.sh`:**
- `anthropic_get_batch()` - Get batch status
- `anthropic_get_batch_results()` - Retrieve completed results
- `anthropic_list_batches()` - List all batches
- `anthropic_cancel_batch()` - Cancel pending batch

## Response Handling

### SSE Processing

Streaming responses use Server-Sent Events. SSE parsing is inline within `anthropic_execute_stream()`:

```bash
# Inline in anthropic_execute_stream()
while IFS= read -r line; do
    case "$line" in
        "event: content_block_delta"|"event: thinking_delta")
            # Next line contains delta
            ;;
        data:*)
            local json="${line#data: }"
            local delta=$(echo "$json" | jq -r '.delta.text // empty')
            if [[ -n "$delta" ]]; then
                printf '%s' "$delta" >> "$output_file"
                printf '%s' "$delta"
            fi
            ;;
        "event: message_stop")
            break
            ;;
    esac
done
```

**Note:** Thinking deltas are displayed with ANSI formatting (dim text) to distinguish from final response.

### Buffered Response

Response processing is inline within `anthropic_execute_single()`:

```bash
# Inline in anthropic_execute_single()
# Check for errors
if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
    local error_msg=$(echo "$response" | jq -r '.error.message')
    error "API error: $error_msg"
    return 1
fi

# Extract content (handles both text and thinking blocks)
local content=$(echo "$response" | jq -r '.content[] | select(.type == "text") | .text')
echo "$content" > "$output_file"
```

### Batch Results

```bash
# lib/api.sh:anthropic_get_batch_results()
anthropic_get_batch_results() {
    # Get results URL from batch status
    local results_url=$(anthropic_get_batch "$batch_id" | jq -r '.results_url')

    # Download and process JSONL results
    curl -sS "$results_url" | while IFS= read -r line; do
        local custom_id=$(echo "$line" | jq -r '.custom_id')
        local content=$(echo "$line" | jq -r '.result.message.content[0].text')
        echo "$content" > "$output_dir/$custom_id.md"
    done
}
```

## Prompt Caching

### Cache Control

Breakpoints marked with `cache_control`:

```json
{
  "type": "text",
  "text": "[content]",
  "cache_control": {"type": "ephemeral"}
}
```

### Breakpoint Strategy

Maximum 4 breakpoints per request:

**System array:**
1. After system prompts (most stable)
2. After project description

**User array:**
1. After last PDF (if present)
2. After last text/image block (before task)

### Cache Benefits

- 90% cost reduction on cache hits
- 5-minute default TTL (extendable to 1 hour)
- Minimum 1024 tokens per cached block

## Citations Support

### Enabling Citations

```bash
ENABLE_CITATIONS=true
```

### Document Blocks

Context/input files use document type for citation support:

```json
{
  "type": "document",
  "source": {
    "type": "text",
    "media_type": "text/plain",
    "data": "[file content]"
  },
  "title": "filename.md",
  "context": "<metadata type=\"context\" source=\"/path/to/file\"></metadata>",
  "citations": {"enabled": true}
}
```

### PDF Documents

```json
{
  "type": "document",
  "source": {
    "type": "base64",
    "media_type": "application/pdf",
    "data": "[base64 data]"
  },
  "title": "document.pdf",
  "citations": {"enabled": true}
}
```

### Document Index Map

WireFlow tracks document indices for citation resolution:

```bash
# Saved to .workflow/run/<name>/document-map.json
{
  "0": {"type": "context", "source": "/path/to/file1.md"},
  "1": {"type": "context", "source": "/path/to/file2.pdf"},
  "2": {"type": "input", "source": "/path/to/data.csv"}
}
```

## Extended Thinking

### Request Parameters

```json
{
  "model": "claude-opus-4-5-20251101",
  "thinking": {
    "type": "enabled",
    "budget_tokens": 10240
  },
  "messages": [...]
}
```

### Response Structure

```json
{
  "content": [
    {
      "type": "thinking",
      "thinking": "[reasoning process]"
    },
    {
      "type": "text",
      "text": "[final response]"
    }
  ]
}
```

### Effort Parameter (Opus 4.5)

Effort uses `output_config` (separate from thinking):

```json
{
  "model": "claude-opus-4-5-20251101",
  "output_config": {
    "effort": "high"
  },
  "thinking": {
    "type": "enabled",
    "budget_tokens": 10240
  }
}
```

**Note:** When effort is not "high", a beta header is required: `anthropic-beta: effort-2025-11-24`

## Error Handling

### HTTP Status Codes

| Code | Meaning | Action |
|------|---------|--------|
| 200 | Success | Process response |
| 401 | Unauthorized | Check API key |
| 429 | Rate limited | Retry with backoff |
| 500 | Server error | Retry |
| 529 | Overloaded | Retry later |

### Error Response Format

```json
{
  "type": "error",
  "error": {
    "type": "invalid_request_error",
    "message": "Description of the error"
  }
}
```

### Implementation

```bash
handle_api_response() {
    local status="$1"
    local response="$2"

    if [[ "$status" != "200" ]]; then
        local error_type=$(echo "$response" | jq -r '.error.type // "unknown"')
        local error_msg=$(echo "$response" | jq -r '.error.message // "Unknown error"')

        case "$error_type" in
            "authentication_error")
                error "Invalid API key"
                ;;
            "rate_limit_error")
                warn "Rate limited, retrying..."
                sleep 5
                return 1  # Signal retry
                ;;
            *)
                error "API error ($error_type): $error_msg"
                ;;
        esac
    fi
}
```

## Debug Output

### Request Files

Saved in workflow directory when `--dry-run`:

| File | Contents |
|------|----------|
| `system-blocks.json` | System prompt blocks |
| `user-blocks.json` | User content blocks |
| `request.json` | Complete API request |

### Inspection

```bash
wfw run analysis --dry-run

# View request
cat .workflow/run/analysis/request.json | jq .

# View system blocks
cat .workflow/run/analysis/system-blocks.json | jq .
```

## See Also

- [Execution](execution.md) - Execution modes and token management
- [Content & I/O](content.md) - Content block building
- [Configuration](configuration.md) - API configuration options
- [Architecture](architecture.md) - System design overview
