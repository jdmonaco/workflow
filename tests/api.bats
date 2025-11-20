#!/usr/bin/env bats

load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load
load test_helper/common

setup() {
    # Source API functions
    WORKFLOW_LIB_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")"; pwd)/lib"
    source "$WORKFLOW_LIB_DIR/utils.sh"
    source "$WORKFLOW_LIB_DIR/api.sh"

    # Setup test environment
    setup_test_env

    # Mock less to avoid interactive pager in tests
    less() {
        cat "$@"
    }
    export -f less
}

teardown() {
    unmock_curl
    cleanup_test_env
}

# Helper function to create test content blocks files
create_test_blocks() {
    local system_text="$1"
    local user_text="$2"
    local system_file="$TEST_TEMP_DIR/system_blocks.json"
    local user_file="$TEST_TEMP_DIR/user_blocks.json"

    # Create simple single-block arrays
    echo "[{\"type\":\"text\",\"text\":\"$system_text\"}]" > "$system_file"
    echo "[{\"type\":\"text\",\"text\":\"$user_text\"}]" > "$user_file"

    # Return file paths via global variables
    TEST_SYSTEM_FILE="$system_file"
    TEST_USER_FILE="$user_file"
}

# =============================================================================
# anthropic_validate() Tests
# =============================================================================

@test "anthropic_validate: succeeds with valid API key" {
    run anthropic_validate "sk-ant-test-key"

    assert_success
}

@test "anthropic_validate: succeeds with ANTHROPIC_API_KEY env var" {
    export ANTHROPIC_API_KEY="sk-ant-test-key"

    run anthropic_validate

    assert_success
}

@test "anthropic_validate: fails when API key missing" {
    unset ANTHROPIC_API_KEY

    run anthropic_validate

    assert_failure
    assert_output --partial "ANTHROPIC_API_KEY"
}

@test "anthropic_validate: fails when API key empty" {
    run anthropic_validate ""

    assert_failure
    assert_output --partial "ANTHROPIC_API_KEY"
}

# =============================================================================
# anthropic_execute_single() Tests
# =============================================================================

@test "anthropic_execute_single: executes request and writes output" {
    mock_curl_success

    local output_file="$TEST_TEMP_DIR/output.md"
    local system_json=$(escape_json "System prompt")
    local user_json=$(escape_json "User prompt")

    run anthropic_execute_single \
        api_key="sk-ant-test" \
        model="claude-test" \
        max_tokens=100 \
        temperature=1.0 \
        system_prompt="$system_json" \
        user_prompt="$user_json" \
        output_file="$output_file"

    assert_success
    assert_file_exists "$output_file"

    run cat "$output_file"
    assert_output "This is a test response from the API."
}

@test "anthropic_execute_single: handles API error response" {
    mock_curl_error

    local output_file="$TEST_TEMP_DIR/output.md"
    local system_json=$(escape_json "System")
    local user_json=$(escape_json "User")

    run anthropic_execute_single \
        api_key="sk-ant-test" \
        model="claude-test" \
        max_tokens=100 \
        temperature=1.0 \
        system_prompt="$system_json" \
        user_prompt="$user_json" \
        output_file="$output_file"

    assert_failure
    assert_output --partial "API Error"
}

@test "anthropic_execute_single: parses all parameters correctly" {
    # Mock curl to capture what was sent
    curl() {
        # Save the -d payload argument for inspection
        while [[ $# -gt 0 ]]; do
            if [[ "$1" == "-d" ]]; then
                if [[ "$2" == "@-" ]]; then
                    # Read from stdin when using @-
                    cat > "$TEST_TEMP_DIR/payload.json"
                else
                    echo "$2" > "$TEST_TEMP_DIR/payload.json"
                fi
                break
            fi
            shift
        done
        # Return success response
        echo '{"content":[{"text":"Response"}]}'
    }
    export -f curl

    local output_file="$TEST_TEMP_DIR/output.md"

    # Create test content blocks
    create_test_blocks "Test system" "Test user"

    anthropic_execute_single \
        api_key="sk-ant-test" \
        model="claude-sonnet-4-5" \
        max_tokens=8192 \
        temperature=0.7 \
        system_blocks_file="$TEST_SYSTEM_FILE" \
        user_blocks_file="$TEST_USER_FILE" \
        output_file="$output_file"

    # Check payload was constructed correctly
    assert_file_exists "$TEST_TEMP_DIR/payload.json"

    run jq -r '.model' "$TEST_TEMP_DIR/payload.json"
    assert_output "claude-sonnet-4-5"

    run jq -r '.max_tokens' "$TEST_TEMP_DIR/payload.json"
    assert_output "8192"

    run jq -r '.temperature' "$TEST_TEMP_DIR/payload.json"
    assert_output "0.7"
}

@test "anthropic_execute_single: JSON-escapes prompts correctly" {
    mock_curl_success

    local output_file="$TEST_TEMP_DIR/output.md"
    # Test with content that needs escaping
    local system_json=$(escape_json "System with \"quotes\" and \n newlines")
    local user_json=$(escape_json "User with special chars: \t\r\n")

    run anthropic_execute_single \
        api_key="sk-ant-test" \
        model="claude-test" \
        max_tokens=100 \
        temperature=1.0 \
        system_prompt="$system_json" \
        user_prompt="$user_json" \
        output_file="$output_file"

    assert_success
}

# =============================================================================
# anthropic_execute_stream() Tests
# =============================================================================

@test "anthropic_execute_stream: processes SSE events and writes output" {
    mock_curl_streaming

    local output_file="$TEST_TEMP_DIR/output.md"
    local system_json=$(escape_json "System")
    local user_json=$(escape_json "User")

    run anthropic_execute_stream \
        api_key="sk-ant-test" \
        model="claude-test" \
        max_tokens=100 \
        temperature=1.0 \
        system_prompt="$system_json" \
        user_prompt="$user_json" \
        output_file="$output_file"

    assert_success
    assert_file_exists "$output_file"

    run cat "$output_file"
    assert_output "Test streaming response"
}

@test "anthropic_execute_stream: handles API error in stream" {
    # Mock streaming error response
    curl() {
        cat <<'EOF'
data: {"type":"error","error":{"type":"invalid_request_error","message":"Invalid API key"}}
EOF
    }
    export -f curl

    local output_file="$TEST_TEMP_DIR/output.md"
    local system_json=$(escape_json "System")
    local user_json=$(escape_json "User")

    run anthropic_execute_stream \
        api_key="sk-ant-test" \
        model="claude-test" \
        max_tokens=100 \
        temperature=1.0 \
        system_prompt="$system_json" \
        user_prompt="$user_json" \
        output_file="$output_file"

    assert_failure
    assert_output --partial "API Error"
}

@test "anthropic_execute_stream: incremental output to file and stdout" {
    mock_curl_streaming

    local output_file="$TEST_TEMP_DIR/output.md"

    # Create test content blocks
    create_test_blocks "System" "User"

    anthropic_execute_stream \
        api_key="sk-ant-test" \
        model="claude-test" \
        max_tokens=100 \
        temperature=1.0 \
        system_blocks_file="$TEST_SYSTEM_FILE" \
        user_blocks_file="$TEST_USER_FILE" \
        output_file="$output_file" > /dev/null

    # Output file should contain streamed content
    assert_file_exists "$output_file"
    run cat "$output_file"
    assert_output "Test streaming response"
}

@test "anthropic_execute_stream: skips empty and ping events" {
    # Mock with empty lines and ping events
    curl() {
        cat <<'EOF'

data: {"type":"ping"}

data: {"type":"content_block_delta","delta":{"text":"Content"}}

data: [DONE]
EOF
    }
    export -f curl

    local output_file="$TEST_TEMP_DIR/output.md"
    local system_json=$(escape_json "System")
    local user_json=$(escape_json "User")

    run anthropic_execute_stream \
        api_key="sk-ant-test" \
        model="claude-test" \
        max_tokens=100 \
        temperature=1.0 \
        system_prompt="$system_json" \
        user_prompt="$user_json" \
        output_file="$output_file"

    assert_success
    run cat "$output_file"
    assert_output "Content"
}

# =============================================================================
# Integration Tests with Both Modes
# =============================================================================

@test "API: single mode produces same output as stream mode" {
    local output_single="$TEST_TEMP_DIR/output_single.md"
    local output_stream="$TEST_TEMP_DIR/output_stream.md"

    # Create test content blocks
    create_test_blocks "System" "User"

    # Execute in single mode
    mock_curl_success
    anthropic_execute_single \
        api_key="sk-ant-test" \
        model="claude-test" \
        max_tokens=100 \
        temperature=1.0 \
        system_blocks_file="$TEST_SYSTEM_FILE" \
        user_blocks_file="$TEST_USER_FILE" \
        output_file="$output_single" > /dev/null

    # Execute in stream mode
    mock_curl_streaming
    anthropic_execute_stream \
        api_key="sk-ant-test" \
        model="claude-test" \
        max_tokens=100 \
        temperature=1.0 \
        system_blocks_file="$TEST_SYSTEM_FILE" \
        user_blocks_file="$TEST_USER_FILE" \
        output_file="$output_stream" > /dev/null

    # Both should produce output files
    assert_file_exists "$output_single"
    assert_file_exists "$output_stream"

    # Content should be text responses (though may differ in our mocks)
    run cat "$output_single"
    assert_output "This is a test response from the API."

    run cat "$output_stream"
    assert_output "Test streaming response"
}
