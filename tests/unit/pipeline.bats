#!/usr/bin/env bats

# Unit tests for lib/pipeline.sh functions
# Tests execution logging, staleness detection, and dependency resolution

load ../test_helper/bats-support/load
load ../test_helper/bats-assert/load
load ../test_helper/bats-file/load
load ../test_helper/common.bash

setup() {
    setup_test_env

    # Source required libraries
    WORKFLOW_LIB_DIR="$(cd "$BATS_TEST_DIRNAME/../.." ; pwd)/lib"
    source "$WORKFLOW_LIB_DIR/utils.sh"
    source "$WORKFLOW_LIB_DIR/config.sh"
    source "$WORKFLOW_LIB_DIR/pipeline.sh"

    # Initialize required globals
    PROJECT_ROOT="$TEST_TEMP_DIR"
    RUN_DIR="$TEST_TEMP_DIR/.workflow/run"
    OUTPUT_DIR="$TEST_TEMP_DIR/.workflow/output"
    mkdir -p "$RUN_DIR" "$OUTPUT_DIR"

    # Initialize config arrays (normally done in wireflow.sh)
    CONFIG_KEYS=(
        "PROFILE" "MODEL" "TEMPERATURE" "MAX_TOKENS"
        "ENABLE_THINKING" "THINKING_BUDGET" "EFFORT"
        "ENABLE_CITATIONS" "OUTPUT_FORMAT" "SYSTEM_PROMPTS"
    )
    USER_ENV_KEYS=("WIREFLOW_PROMPT_PREFIX" "WIREFLOW_TASK_PREFIX" "ANTHROPIC_API_KEY")
    PROJECT_KEYS=("CONTEXT")
    WORKFLOW_KEYS=("DEPENDS_ON" "INPUT" "EXPORT_PATH" "BATCH_MODE")

    declare -gA CONFIG_SOURCE_MAP=()
    declare -gA USER_ENV_SOURCE_MAP=()
    declare -gA PROJECT_SOURCE_MAP=()
    declare -gA WORKFLOW_SOURCE_MAP=()

    for key in "${CONFIG_KEYS[@]}"; do
        CONFIG_SOURCE_MAP[$key]="builtin"
    done
    for key in "${USER_ENV_KEYS[@]}"; do
        USER_ENV_SOURCE_MAP[$key]="builtin"
    done
    for key in "${PROJECT_KEYS[@]}"; do
        PROJECT_SOURCE_MAP[$key]="unset"
    done
    for key in "${WORKFLOW_KEYS[@]}"; do
        WORKFLOW_SOURCE_MAP[$key]="unset"
    done

    # Set default config values
    PROFILE="balanced"
    MODEL="claude-sonnet-4-5"
    TEMPERATURE="1.0"
    MAX_TOKENS="16000"
    ENABLE_THINKING="false"
    THINKING_BUDGET="10000"
    EFFORT="high"
    ENABLE_CITATIONS="false"
    OUTPUT_FORMAT="md"
    SYSTEM_PROMPTS=(base)
    WIREFLOW_PROMPT_PREFIX="/tmp/prompts"
    WIREFLOW_TASK_PREFIX="/tmp/tasks"
    ANTHROPIC_API_KEY=""

    CONTEXT=()
    DEPENDS_ON=()
    INPUT=()
}

teardown() {
    cleanup_test_env
}

# =============================================================================
# compute_execution_hash() tests
# =============================================================================

@test "compute_execution_hash: generates consistent hash" {
    local workflow_name="test-workflow"
    local workflow_dir="$RUN_DIR/$workflow_name"
    mkdir -p "$workflow_dir"
    echo "Test task" > "$workflow_dir/task.txt"

    local hash1 hash2
    hash1=$(compute_execution_hash "$workflow_name" "$workflow_dir" "$PROJECT_ROOT")
    hash2=$(compute_execution_hash "$workflow_name" "$workflow_dir" "$PROJECT_ROOT")

    assert_equal "$hash1" "$hash2"
    # Hash should be 16 characters (truncated SHA256)
    assert_equal "${#hash1}" "16"
}

@test "compute_execution_hash: changes with config change" {
    local workflow_name="test-workflow"
    local workflow_dir="$RUN_DIR/$workflow_name"
    mkdir -p "$workflow_dir"
    echo "Test task" > "$workflow_dir/task.txt"

    MODEL="claude-sonnet-4-5"
    local hash1
    hash1=$(compute_execution_hash "$workflow_name" "$workflow_dir" "$PROJECT_ROOT")

    MODEL="claude-opus-4-5"
    local hash2
    hash2=$(compute_execution_hash "$workflow_name" "$workflow_dir" "$PROJECT_ROOT")

    assert_not_equal "$hash1" "$hash2"
}

@test "compute_execution_hash: changes with task file change" {
    local workflow_name="test-workflow"
    local workflow_dir="$RUN_DIR/$workflow_name"
    mkdir -p "$workflow_dir"
    echo "Task version 1" > "$workflow_dir/task.txt"

    local hash1
    hash1=$(compute_execution_hash "$workflow_name" "$workflow_dir" "$PROJECT_ROOT")

    echo "Task version 2" > "$workflow_dir/task.txt"
    local hash2
    hash2=$(compute_execution_hash "$workflow_name" "$workflow_dir" "$PROJECT_ROOT")

    assert_not_equal "$hash1" "$hash2"
}

@test "compute_execution_hash: includes context file hashes" {
    local workflow_name="test-workflow"
    local workflow_dir="$RUN_DIR/$workflow_name"
    mkdir -p "$workflow_dir"
    echo "Test task" > "$workflow_dir/task.txt"

    # Create context file
    echo "Context content v1" > "$PROJECT_ROOT/context.txt"
    CONTEXT=("context.txt")

    local hash1
    hash1=$(compute_execution_hash "$workflow_name" "$workflow_dir" "$PROJECT_ROOT")

    # Modify context file
    echo "Context content v2" > "$PROJECT_ROOT/context.txt"
    local hash2
    hash2=$(compute_execution_hash "$workflow_name" "$workflow_dir" "$PROJECT_ROOT")

    assert_not_equal "$hash1" "$hash2"
}

# =============================================================================
# is_execution_stale() tests
# =============================================================================

@test "is_execution_stale: returns stale for missing execution log" {
    local workflow_name="test-workflow"
    local workflow_dir="$RUN_DIR/$workflow_name"
    mkdir -p "$workflow_dir"

    # No execution.json = stale
    run is_execution_stale "$workflow_name"
    assert_success  # 0 = stale
}

@test "is_execution_stale: returns stale for missing output file" {
    local workflow_name="test-workflow"
    local workflow_dir="$RUN_DIR/$workflow_name"
    mkdir -p "$workflow_dir"
    echo "Test task" > "$workflow_dir/task.txt"

    # Create execution log with non-existent output
    cat > "$workflow_dir/execution.json" <<EOF
{
    "version": 1,
    "workflow": "$workflow_name",
    "executed_at": "2024-01-01T00:00:00Z",
    "execution_hash": "abc123",
    "output": {"path": ".workflow/run/$workflow_name/output.md"}
}
EOF

    run is_execution_stale "$workflow_name"
    assert_success  # 0 = stale
}

@test "is_execution_stale: returns fresh for valid unchanged state" {
    local workflow_name="test-workflow"
    local workflow_dir="$RUN_DIR/$workflow_name"
    mkdir -p "$workflow_dir"
    echo "Test task" > "$workflow_dir/task.txt"

    # Create output file
    echo "Output content" > "$workflow_dir/output.md"

    # Compute current hash
    WORKFLOW_NAME="$workflow_name"
    local current_hash
    current_hash=$(compute_execution_hash "$workflow_name" "$workflow_dir" "$PROJECT_ROOT")

    # Get current timestamp and file mtime
    local now task_mtime
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    task_mtime=$(stat -f%m "$workflow_dir/task.txt")

    # Create execution log with matching hash
    cat > "$workflow_dir/execution.json" <<EOF
{
    "version": 1,
    "workflow": "$workflow_name",
    "executed_at": "$now",
    "execution_hash": "$current_hash",
    "context": [],
    "input": [],
    "depends_on": [],
    "output": {"path": ".workflow/run/$workflow_name/output.md"}
}
EOF

    run is_execution_stale "$workflow_name"
    assert_failure  # 1 = fresh
}

# =============================================================================
# resolve_dependency_order() tests
# =============================================================================

@test "resolve_dependency_order: returns single workflow with no deps" {
    local workflow_name="test-workflow"
    local workflow_dir="$RUN_DIR/$workflow_name"
    mkdir -p "$workflow_dir"

    # Create config with no DEPENDS_ON
    cat > "$workflow_dir/config" <<'EOF'
DEPENDS_ON=()
EOF

    run resolve_dependency_order "$workflow_name"
    assert_success
    assert_output "$workflow_name"
}

@test "resolve_dependency_order: returns correct order for chain" {
    # Create workflow A (no deps)
    mkdir -p "$RUN_DIR/workflow-a"
    cat > "$RUN_DIR/workflow-a/config" <<'EOF'
DEPENDS_ON=()
EOF

    # Create workflow B (depends on A)
    mkdir -p "$RUN_DIR/workflow-b"
    cat > "$RUN_DIR/workflow-b/config" <<'EOF'
DEPENDS_ON=(workflow-a)
EOF

    # Create workflow C (depends on B)
    mkdir -p "$RUN_DIR/workflow-c"
    cat > "$RUN_DIR/workflow-c/config" <<'EOF'
DEPENDS_ON=(workflow-b)
EOF

    run resolve_dependency_order "workflow-c"
    assert_success
    # Order should be: a, b, c (dependencies first)
    assert_line --index 0 "workflow-a"
    assert_line --index 1 "workflow-b"
    assert_line --index 2 "workflow-c"
}

@test "resolve_dependency_order: detects circular dependency" {
    # Create workflow A (depends on B)
    mkdir -p "$RUN_DIR/workflow-a"
    cat > "$RUN_DIR/workflow-a/config" <<'EOF'
DEPENDS_ON=(workflow-b)
EOF

    # Create workflow B (depends on A)
    mkdir -p "$RUN_DIR/workflow-b"
    cat > "$RUN_DIR/workflow-b/config" <<'EOF'
DEPENDS_ON=(workflow-a)
EOF

    run resolve_dependency_order "workflow-a"
    assert_failure
    assert_output --partial "Circular dependency detected"
}

@test "resolve_dependency_order: errors on missing dependency" {
    mkdir -p "$RUN_DIR/workflow-a"
    cat > "$RUN_DIR/workflow-a/config" <<'EOF'
DEPENDS_ON=(nonexistent-workflow)
EOF

    run resolve_dependency_order "workflow-a"
    assert_failure
    assert_output --partial "Dependency workflow not found"
}

# =============================================================================
# extract_depends_on() tests
# =============================================================================

@test "extract_depends_on: extracts empty array" {
    local config_file="$TEST_TEMP_DIR/config"
    cat > "$config_file" <<'EOF'
DEPENDS_ON=()
EOF

    run extract_depends_on "$config_file"
    assert_success
    assert_output ""
}

@test "extract_depends_on: extracts single dependency" {
    local config_file="$TEST_TEMP_DIR/config"
    cat > "$config_file" <<'EOF'
DEPENDS_ON=(workflow-a)
EOF

    run extract_depends_on "$config_file"
    assert_success
    assert_output "workflow-a"
}

@test "extract_depends_on: extracts multiple dependencies" {
    local config_file="$TEST_TEMP_DIR/config"
    cat > "$config_file" <<'EOF'
DEPENDS_ON=(workflow-a workflow-b workflow-c)
EOF

    run extract_depends_on "$config_file"
    assert_success
    assert_line --index 0 "workflow-a"
    assert_line --index 1 "workflow-b"
    assert_line --index 2 "workflow-c"
}

# =============================================================================
# get_execution_status() tests
# =============================================================================

@test "get_execution_status: shows pending for no execution log" {
    local workflow_name="test-workflow"
    mkdir -p "$RUN_DIR/$workflow_name"

    run get_execution_status "$workflow_name"
    assert_success
    assert_output "[pending]"
}

# =============================================================================
# get_execution_timestamp() tests
# =============================================================================

@test "get_execution_timestamp: shows not run for missing log" {
    local workflow_name="test-workflow"
    mkdir -p "$RUN_DIR/$workflow_name"

    run get_execution_timestamp "$workflow_name"
    assert_success
    assert_output "(not run)"
}

@test "get_execution_timestamp: extracts timestamp from log" {
    local workflow_name="test-workflow"
    local workflow_dir="$RUN_DIR/$workflow_name"
    mkdir -p "$workflow_dir"

    cat > "$workflow_dir/execution.json" <<EOF
{
    "version": 1,
    "executed_at": "2024-11-28T14:30:00Z"
}
EOF

    run get_execution_timestamp "$workflow_name"
    assert_success
    assert_output --partial "2024-11-28"
}

# =============================================================================
# write_execution_log() tests
# =============================================================================

@test "write_execution_log: creates valid JSON" {
    local workflow_name="test-workflow"
    local workflow_dir="$RUN_DIR/$workflow_name"
    mkdir -p "$workflow_dir"
    echo "Test task" > "$workflow_dir/task.txt"
    echo "Output content" > "$workflow_dir/output.md"

    WORKFLOW_NAME="$workflow_name"
    write_execution_log "$workflow_name" "$workflow_dir" "$workflow_dir/output.md" "$PROJECT_ROOT"

    assert_file_exists "$workflow_dir/execution.json"

    # Validate JSON structure
    run jq -r '.version' "$workflow_dir/execution.json"
    assert_output "1"

    run jq -r '.workflow' "$workflow_dir/execution.json"
    assert_output "$workflow_name"

    run jq -r '.execution_hash' "$workflow_dir/execution.json"
    assert_success
    # Hash should be 16 characters
    [ "${#output}" -eq 16 ]
}

@test "write_execution_log: includes config values" {
    local workflow_name="test-workflow"
    local workflow_dir="$RUN_DIR/$workflow_name"
    mkdir -p "$workflow_dir"
    echo "Test task" > "$workflow_dir/task.txt"
    echo "Output" > "$workflow_dir/output.md"

    MODEL="claude-opus-4-5"
    TEMPERATURE="0.5"
    WORKFLOW_NAME="$workflow_name"

    write_execution_log "$workflow_name" "$workflow_dir" "$workflow_dir/output.md" "$PROJECT_ROOT"

    run jq -r '.config.model' "$workflow_dir/execution.json"
    assert_output "claude-opus-4-5"

    run jq -r '.config.temperature' "$workflow_dir/execution.json"
    assert_output "0.5"
}

@test "write_execution_log: includes context file metadata" {
    local workflow_name="test-workflow"
    local workflow_dir="$RUN_DIR/$workflow_name"
    mkdir -p "$workflow_dir"
    echo "Test task" > "$workflow_dir/task.txt"
    echo "Output" > "$workflow_dir/output.md"

    # Create context file
    echo "Context content" > "$PROJECT_ROOT/context.txt"
    CONTEXT=("context.txt")
    WORKFLOW_NAME="$workflow_name"

    write_execution_log "$workflow_name" "$workflow_dir" "$workflow_dir/output.md" "$PROJECT_ROOT"

    run jq -r '.context | length' "$workflow_dir/execution.json"
    assert_output "1"

    run jq -r '.context[0].path' "$workflow_dir/execution.json"
    assert_output "context.txt"

    run jq -r '.context[0].hash' "$workflow_dir/execution.json"
    assert_success
    assert_output --partial "sha256:"
}
