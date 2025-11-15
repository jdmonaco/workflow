#!/usr/bin/env bash

# Common test utilities for workflow.sh tests

# Setup test environment with temp directories and mocked dependencies
setup_test_env() {
    # Create isolated temp directory
    export TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_PROJECT="$TEST_TEMP_DIR/project"
    mkdir -p "$TEST_PROJECT"

    # Save original directory
    export ORIGINAL_DIR="$PWD"

    # Mock environment variables
    export ANTHROPIC_API_KEY="sk-ant-test-12345"
    export WORKFLOW_PROMPT_PREFIX="$TEST_TEMP_DIR/prompts"
    export EDITOR="echo"  # Don't actually open vim in tests

    # Create mock system prompts
    mkdir -p "$WORKFLOW_PROMPT_PREFIX/System"
    echo "This is the Root system prompt for testing." > "$WORKFLOW_PROMPT_PREFIX/System/Root.txt"
    echo "This is a NeuroAI prompt for testing." > "$WORKFLOW_PROMPT_PREFIX/System/NeuroAI.txt"

    # Path to workflow.sh (assuming tests/ is next to workflow.sh)
    export WORKFLOW_SCRIPT="$(cd "$(dirname "$BATS_TEST_DIRNAME")"; pwd)/workflow.sh"

    # Change to test project
    cd "$TEST_PROJECT"
}

# Cleanup test environment
cleanup_test_env() {
    cd "$ORIGINAL_DIR"
    rm -rf "$TEST_TEMP_DIR"
}

# Mock curl to return success response
mock_curl_success() {
    curl() {
        echo '{"content":[{"text":"This is a test response from the API."}],"usage":{"input_tokens":100,"output_tokens":50}}'
    }
    export -f curl
}

# Mock curl to return streaming response
mock_curl_streaming() {
    curl() {
        cat <<'EOF'
data: {"type":"message_start","message":{"id":"msg_123","type":"message"}}
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Test "}}
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"streaming "}}
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"response"}}
data: {"type":"content_block_stop","index":0}
data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":3}}
data: {"type":"message_stop"}
EOF
    }
    export -f curl
}

# Mock curl to return error
mock_curl_error() {
    curl() {
        echo '{"type":"error","error":{"type":"invalid_request_error","message":"Invalid API key"}}'
    }
    export -f curl
}

# Unmock curl
unmock_curl() {
    unset -f curl
}

# Helper to check if file contains string
file_contains() {
    local file="$1"
    local search="$2"
    grep -q "$search" "$file"
}

# Helper to count files matching pattern
count_files() {
    local pattern="$1"
    ls -1 $pattern 2>/dev/null | wc -l | tr -d ' '
}
