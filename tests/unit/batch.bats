#!/usr/bin/env bats

# Unit tests for lib/batch.sh functions
# Tests batch state management and request building

load ../test_helper/bats-support/load
load ../test_helper/bats-assert/load
load ../test_helper/bats-file/load
load ../test_helper/common

setup() {
    setup_test_env

    # Source batch functions directly for unit testing
    WORKFLOW_LIB_DIR="$(cd "$BATS_TEST_DIRNAME/../.."; pwd)/lib"
    source "$WORKFLOW_LIB_DIR/utils.sh"
    source "$WORKFLOW_LIB_DIR/config.sh"
    source "$WORKFLOW_LIB_DIR/batch.sh"

    # Initialize required globals
    WORKFLOW_NAME="test-workflow"
    OUTPUT_FORMAT="md"
    MAX_TOKENS=4096
    TEMPERATURE=1.0
}

teardown() {
    cleanup_test_env
}

# =============================================================================
# save_batch_state() tests
# =============================================================================

@test "save_batch_state: creates valid state file" {
    local workflow_dir="$TEST_TEMP_DIR/workflow"
    mkdir -p "$workflow_dir"

    # Set up required globals
    BATCH_INPUT_MAP='[{"custom_id": "wfw-file1-0", "path": "/path/to/file1.txt"}]'

    save_batch_state "$workflow_dir" "msgbatch_123" "in_progress" 5

    assert_file_exists "$workflow_dir/batch-state.json"

    # Verify JSON structure
    run jq -r '.batch_id' "$workflow_dir/batch-state.json"
    assert_output "msgbatch_123"

    run jq -r '.status' "$workflow_dir/batch-state.json"
    assert_output "in_progress"

    run jq -r '.request_count' "$workflow_dir/batch-state.json"
    assert_output "5"
}

@test "save_batch_state: includes input map" {
    local workflow_dir="$TEST_TEMP_DIR/workflow"
    mkdir -p "$workflow_dir"

    BATCH_INPUT_MAP='[{"custom_id": "wfw-doc1-0", "path": "/tmp/doc1.txt"}, {"custom_id": "wfw-doc2-1", "path": "/tmp/doc2.txt"}]'

    save_batch_state "$workflow_dir" "msgbatch_456" "in_progress" 2

    run jq '.input_map | length' "$workflow_dir/batch-state.json"
    assert_output "2"

    run jq -r '.input_map[0].custom_id' "$workflow_dir/batch-state.json"
    assert_output "wfw-doc1-0"
}

# =============================================================================
# load_batch_state() tests
# =============================================================================

@test "load_batch_state: loads state correctly" {
    local workflow_dir="$TEST_TEMP_DIR/workflow"
    mkdir -p "$workflow_dir"

    cat > "$workflow_dir/batch-state.json" <<'EOF'
{
    "batch_id": "msgbatch_789",
    "status": "ended",
    "request_count": 10,
    "completed_count": 8,
    "failed_count": 2,
    "created_at": "2025-01-15T10:00:00Z",
    "last_checked": "2025-01-15T11:00:00Z"
}
EOF

    # Call directly (not via run) to preserve variable assignments
    load_batch_state "$workflow_dir"
    local result=$?

    assert_equal "$result" "0"
    assert_equal "$BATCH_STATE_ID" "msgbatch_789"
    assert_equal "$BATCH_STATE_STATUS" "ended"
    assert_equal "$BATCH_STATE_COUNT" "10"
    assert_equal "$BATCH_STATE_COMPLETED" "8"
    assert_equal "$BATCH_STATE_FAILED" "2"
}

@test "load_batch_state: returns failure for missing file" {
    local workflow_dir="$TEST_TEMP_DIR/no-batch"
    mkdir -p "$workflow_dir"

    run load_batch_state "$workflow_dir"
    assert_failure
}

# =============================================================================
# update_batch_state() tests
# =============================================================================

@test "update_batch_state: updates status and counts" {
    local workflow_dir="$TEST_TEMP_DIR/workflow"
    mkdir -p "$workflow_dir"

    # Create initial state
    cat > "$workflow_dir/batch-state.json" <<'EOF'
{
    "batch_id": "msgbatch_update",
    "status": "in_progress",
    "request_count": 5,
    "completed_count": 0,
    "failed_count": 0,
    "last_checked": "2025-01-15T10:00:00Z"
}
EOF

    # Simulate API response
    local batch_response='{
        "processing_status": "ended",
        "request_counts": {
            "succeeded": 4,
            "errored": 1
        }
    }'

    update_batch_state "$workflow_dir" "$batch_response"

    run jq -r '.status' "$workflow_dir/batch-state.json"
    assert_output "ended"

    run jq -r '.completed_count' "$workflow_dir/batch-state.json"
    assert_output "4"

    run jq -r '.failed_count' "$workflow_dir/batch-state.json"
    assert_output "1"
}

# =============================================================================
# get_batch_display_status() tests
# =============================================================================

@test "get_batch_display_status: shows in_progress status" {
    local workflow_dir="$TEST_TEMP_DIR/workflow"
    mkdir -p "$workflow_dir"

    cat > "$workflow_dir/batch-state.json" <<'EOF'
{
    "status": "in_progress",
    "completed_count": 3,
    "request_count": 10
}
EOF

    run get_batch_display_status "$workflow_dir"
    assert_output "[batch: in_progress 3/10]"
}

@test "get_batch_display_status: shows ended status with timestamp" {
    local workflow_dir="$TEST_TEMP_DIR/workflow"
    mkdir -p "$workflow_dir"

    cat > "$workflow_dir/batch-state.json" <<'EOF'
{
    "status": "ended",
    "completed_count": 10,
    "request_count": 10,
    "last_checked": "2025-01-15T14:30:00Z"
}
EOF

    run get_batch_display_status "$workflow_dir"
    assert_success
    assert_output --partial "[batch: completed"
}

@test "get_batch_display_status: returns empty for no state" {
    local workflow_dir="$TEST_TEMP_DIR/no-batch"
    mkdir -p "$workflow_dir"

    run get_batch_display_status "$workflow_dir"
    assert_success
    assert_output ""
}

# =============================================================================
# build_batch_requests() tests
# =============================================================================

@test "build_batch_requests: fails without input files" {
    local workflow_dir="$TEST_TEMP_DIR/workflow"
    mkdir -p "$workflow_dir"

    # Empty input arrays
    CLI_INPUT_FILES=()
    CLI_INPUT_PATTERN=""
    INPUT_FILES=()
    INPUT_PATTERN=""
    SYSTEM_BLOCKS=('{"type":"text","text":"system"}')
    TASK_BLOCK='{"type":"text","text":"task"}'

    run build_batch_requests "task" "" "$workflow_dir"
    assert_failure
    assert_output --partial "requires at least one input file"
}

@test "build_batch_requests: creates requests for input files" {
    local workflow_dir="$TEST_TEMP_DIR/workflow"
    mkdir -p "$workflow_dir"

    # Create test input files
    mkdir -p "$TEST_TEMP_DIR/inputs"
    echo "Content 1" > "$TEST_TEMP_DIR/inputs/file1.txt"
    echo "Content 2" > "$TEST_TEMP_DIR/inputs/file2.txt"

    CLI_INPUT_FILES=("$TEST_TEMP_DIR/inputs/file1.txt" "$TEST_TEMP_DIR/inputs/file2.txt")
    CLI_INPUT_PATTERN=""
    INPUT_FILES=()
    INPUT_PATTERN=""
    SYSTEM_BLOCKS=('{"type":"text","text":"system prompt"}')
    CONTEXT_BLOCKS=()
    CONTEXT_PDF_BLOCKS=()
    DEPENDENCY_BLOCKS=()
    IMAGE_BLOCKS=()
    TASK_BLOCK='{"type":"text","text":"analyze this"}'

    # Set model directly for testing
    MODEL="claude-sonnet-4-5"
    PROFILE="balanced"

    run build_batch_requests "task" "" "$workflow_dir"
    assert_success
    assert_output --partial "Found 2 input file(s)"
    assert_output --partial "Built 2 batch request(s)"

    # Verify requests file was created
    assert_file_exists "$workflow_dir/batch-requests.json"

    # Verify request count
    run jq '. | length' "$workflow_dir/batch-requests.json"
    assert_output "2"
}

@test "build_batch_requests: generates unique custom_ids" {
    local workflow_dir="$TEST_TEMP_DIR/workflow"
    mkdir -p "$workflow_dir"

    mkdir -p "$TEST_TEMP_DIR/inputs"
    echo "Content 1" > "$TEST_TEMP_DIR/inputs/file1.txt"
    echo "Content 2" > "$TEST_TEMP_DIR/inputs/file2.txt"

    CLI_INPUT_FILES=("$TEST_TEMP_DIR/inputs/file1.txt" "$TEST_TEMP_DIR/inputs/file2.txt")
    CLI_INPUT_PATTERN=""
    INPUT_FILES=()
    INPUT_PATTERN=""
    SYSTEM_BLOCKS=('{"type":"text","text":"system"}')
    CONTEXT_BLOCKS=()
    CONTEXT_PDF_BLOCKS=()
    DEPENDENCY_BLOCKS=()
    IMAGE_BLOCKS=()
    TASK_BLOCK='{"type":"text","text":"task"}'

    # Set model directly for testing
    MODEL="claude-sonnet-4-5"
    PROFILE="balanced"

    build_batch_requests "task" "" "$workflow_dir"

    # Extract custom_ids
    local id1 id2
    id1=$(jq -r '.[0].custom_id' "$workflow_dir/batch-requests.json")
    id2=$(jq -r '.[1].custom_id' "$workflow_dir/batch-requests.json")

    # They should be different
    assert_not_equal "$id1" "$id2"

    # They should follow the naming pattern
    assert_regex "$id1" "^wfw-file1"
    assert_regex "$id2" "^wfw-file2"
}

@test "build_batch_requests: includes shared context blocks" {
    local workflow_dir="$TEST_TEMP_DIR/workflow"
    mkdir -p "$workflow_dir"

    mkdir -p "$TEST_TEMP_DIR/inputs"
    echo "Input content" > "$TEST_TEMP_DIR/inputs/input.txt"

    CLI_INPUT_FILES=("$TEST_TEMP_DIR/inputs/input.txt")
    CLI_INPUT_PATTERN=""
    INPUT_FILES=()
    INPUT_PATTERN=""
    SYSTEM_BLOCKS=('{"type":"text","text":"system prompt"}')
    CONTEXT_BLOCKS=('{"type":"text","text":"context block"}')
    CONTEXT_PDF_BLOCKS=()
    DEPENDENCY_BLOCKS=()
    IMAGE_BLOCKS=()
    TASK_BLOCK='{"type":"text","text":"task prompt"}'

    # Set model directly for testing
    MODEL="claude-sonnet-4-5"
    PROFILE="balanced"

    build_batch_requests "task" "" "$workflow_dir"

    # Verify the request includes context block
    run jq '.[0].params.messages[0].content | map(select(.text | contains("context block"))) | length' "$workflow_dir/batch-requests.json"
    assert_output "1"
}
