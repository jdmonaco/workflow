#!/usr/bin/env bash

# Common test utilities for wireflow.sh tests

# Source wireflow.sh functions for unit testing
# This sources the script in a way that defines functions but doesn't execute main logic
source_workflow_functions() {
    local script_path="$1"

    # Source with set +e temporarily to avoid issues
    set +e
    # Use eval to source only function definitions
    eval "$(grep -E '^(sanitize|find_project_root|list_workflows|extract_parent_config)\(\)' -A 200 "$script_path" | sed '/^[a-z_]*() {/,/^}/!d')"
    set -e
}

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
    export WIREFLOW_PROMPT_PREFIX="$TEST_TEMP_DIR/prompts"
    export EDITOR="echo"  # Don't actually open vim in tests

    # Unset WIREFLOW_TASK_PREFIX to avoid picking up user's personal templates
    unset WIREFLOW_TASK_PREFIX

    # Mock global config directory (isolate from user's real config)
    export HOME="$TEST_TEMP_DIR/home"
    export XDG_CONFIG_HOME="$TEST_TEMP_DIR/home/.config"
    export GLOBAL_CONFIG_DIR="$XDG_CONFIG_HOME/wireflow"
    mkdir -p "$HOME"

    # Create mock system prompts
    mkdir -p "$WIREFLOW_PROMPT_PREFIX"
    echo "This is the base system prompt for testing." > "$WIREFLOW_PROMPT_PREFIX/base.txt"
    echo "This is a NeuroAI prompt for testing." > "$WIREFLOW_PROMPT_PREFIX/NeuroAI.txt"

    # Path to wireflow.sh (assuming tests/ is next to wireflow.sh)
    export WORKFLOW_SCRIPT="$(cd "$(dirname "$BATS_TEST_DIRNAME")"; pwd)/wireflow.sh"

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
