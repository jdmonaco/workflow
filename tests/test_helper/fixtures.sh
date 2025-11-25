#!/usr/bin/env /opt/homebrew/bin/bash
# Test Fixtures for WireFlow Tests
# Provides sample data and content for testing various features

# Sample markdown content
export FIXTURE_MARKDOWN_CONTENT='# Test Document

This is a test document with various markdown elements.

## Section 1

Some paragraph text with **bold** and *italic* formatting.

- List item 1
- List item 2
  - Nested item

## Section 2

```python
def hello():
    print("Hello, World!")
```

> A blockquote with some text.

[Link text](https://example.com)'

# Sample code content
export FIXTURE_CODE_CONTENT='#!/usr/bin/env python3

import sys
import json

def process_data(input_data):
    """Process input data and return results."""
    try:
        data = json.loads(input_data)
        return {"status": "success", "data": data}
    except json.JSONDecodeError as e:
        return {"status": "error", "message": str(e)}

if __name__ == "__main__":
    result = process_data(sys.stdin.read())
    print(json.dumps(result))'

# Sample JSON content
export FIXTURE_JSON_CONTENT='{
  "name": "Test Project",
  "version": "1.0.0",
  "description": "A test project for wireflow",
  "config": {
    "model": "claude-3-5-sonnet-20241022",
    "temperature": 0.7,
    "max_tokens": 4096
  },
  "tasks": [
    {"id": 1, "name": "Task 1", "status": "completed"},
    {"id": 2, "name": "Task 2", "status": "pending"}
  ]
}'

# Sample XML task content
export FIXTURE_TASK_XML='<user-task>
  <metadata>
    <name>test-task</name>
    <version>1.0</version>
    <description>Test task for fixtures</description>
  </metadata>
  <content>
    <description>
      Analyze the provided content and generate a summary.
    </description>
    <instructions>
      - Read through all content carefully
      - Identify key themes and topics
      - Create a concise summary
      - Highlight important findings
    </instructions>
    <output-format>
      Provide a structured summary with sections for:
      1. Overview
      2. Key Findings
      3. Recommendations
    </output-format>
  </content>
</user-task>'

# Sample system prompt XML
export FIXTURE_SYSTEM_XML='<system-component>
  <metadata>
    <name>test-component</name>
    <version>1.0</version>
    <dependencies>
      <dependency>core/user</dependency>
      <dependency>core/role</dependency>
    </dependencies>
  </metadata>
  <content>
    <role>You are a helpful AI assistant specialized in testing.</role>
    <capabilities>
      - Process various file formats
      - Generate structured output
      - Follow specific instructions
    </capabilities>
  </content>
</system-component>'

# Sample configuration content
export FIXTURE_CONFIG_CONTENT='# WireFlow Configuration
Project="Test Project"
Model="claude-3-5-sonnet-20241022"
Temperature="0.7"
MaxTokens="4096"
SystemPrompt="prompts/system/meta.txt"
TaskFile=""
Stream="true"
ApiKey="${ANTHROPIC_API_KEY}"
ContextWindow="200000"
OutputTokens="8192"
CacheControl="auto"'

# Sample API response (success)
export FIXTURE_API_RESPONSE_SUCCESS='{
  "id": "msg_01XYZ",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "This is a successful API response for testing purposes."
    }
  ],
  "model": "claude-3-5-sonnet-20241022",
  "stop_reason": "end_turn",
  "stop_sequence": null,
  "usage": {
    "input_tokens": 150,
    "output_tokens": 75,
    "cache_creation_input_tokens": 0,
    "cache_read_input_tokens": 50
  }
}'

# Sample API response (error)
export FIXTURE_API_RESPONSE_ERROR='{
  "type": "error",
  "error": {
    "type": "invalid_request_error",
    "message": "Invalid API key provided"
  }
}'

# Sample streaming API response chunks
export FIXTURE_STREAM_CHUNKS=(
'data: {"type":"message_start","message":{"id":"msg_01ABC","type":"message","role":"assistant","content":[],"model":"claude-3-5-sonnet-20241022","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":100,"output_tokens":0}}}'
'data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}'
'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"This is "}}'
'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"streaming "}}'
'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"output."}}'
'data: {"type":"content_block_stop","index":0}'
'data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":5}}'
'data: {"type":"message_stop"}'
)

# Sample file paths for testing
export FIXTURE_TEST_FILES=(
    "document.md"
    "script.py"
    "config.json"
    "image.png"
    "data.csv"
    "archive.tar.gz"
    "README.txt"
)

# Sample workflow names
export FIXTURE_WORKFLOW_NAMES=(
    "test-workflow"
    "data-analysis"
    "code-review"
    "documentation"
    "research-task"
)

# Sample run timestamps
export FIXTURE_RUN_TIMESTAMPS=(
    "20240101_120000"
    "20240102_143000"
    "20240103_091500"
    "20240104_163045"
    "20240105_110230"
)

# Function to generate mock file with specific content type
# Args:
#   $1 - File path
#   $2 - Content type (markdown, code, json, text, etc.)
create_fixture_file() {
    local file_path="${1:?File path required}"
    local content_type="${2:-text}"

    mkdir -p "$(dirname "$file_path")"

    case "$content_type" in
        markdown|md)
            echo "$FIXTURE_MARKDOWN_CONTENT" > "$file_path"
            ;;
        code|python|py)
            echo "$FIXTURE_CODE_CONTENT" > "$file_path"
            ;;
        json)
            echo "$FIXTURE_JSON_CONTENT" > "$file_path"
            ;;
        xml|task)
            echo "$FIXTURE_TASK_XML" > "$file_path"
            ;;
        config)
            echo "$FIXTURE_CONFIG_CONTENT" > "$file_path"
            ;;
        *)
            echo "Test content for $content_type file" > "$file_path"
            ;;
    esac
}

# Function to create a set of test files
# Args:
#   $1 - Directory path
create_fixture_file_set() {
    local dir="${1:?Directory required}"

    mkdir -p "$dir"

    create_fixture_file "$dir/README.md" "markdown"
    create_fixture_file "$dir/script.py" "code"
    create_fixture_file "$dir/config.json" "json"
    create_fixture_file "$dir/task.xml" "xml"
    create_fixture_file "$dir/notes.txt" "text"
}

# Function to generate mock API payload
# Args:
#   $1 - Prompt text
#   $2 - Model (optional)
#   $3 - Temperature (optional)
generate_api_payload() {
    local prompt="${1:?Prompt required}"
    local model="${2:-claude-3-5-sonnet-20241022}"
    local temperature="${3:-0.7}"

    cat <<EOF
{
  "model": "$model",
  "messages": [
    {
      "role": "user",
      "content": "$prompt"
    }
  ],
  "max_tokens": 4096,
  "temperature": $temperature,
  "stream": false
}
EOF
}

# Function to generate mock token count response
# Args:
#   $1 - Input text
#   $2 - Token count (optional, defaults to word count * 1.3)
generate_token_count() {
    local input="${1:?Input required}"
    local tokens="${2:-}"

    if [[ -z "$tokens" ]]; then
        # Rough estimate: 1.3 tokens per word
        local word_count=$(echo "$input" | wc -w)
        tokens=$((word_count * 13 / 10))
    fi

    cat <<EOF
{
  "token_count": $tokens,
  "model": "claude-3-5-sonnet-20241022"
}
EOF
}

# Export functions
export -f create_fixture_file
export -f create_fixture_file_set
export -f generate_api_payload
export -f generate_token_count