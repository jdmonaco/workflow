#!/usr/bin/env /opt/homebrew/bin/bash
# Unit tests for lib/core.sh
# Tests task file resolution and description extraction

# Load existing bats helpers
load ../test_helper/bats-support/load
load ../test_helper/bats-assert/load
load ../test_helper/bats-file/load
load ../test_helper/common.bash

# Load our custom helpers
source "${BATS_TEST_DIRNAME}/../test_helper/mock_env.sh"
source "${BATS_TEST_DIRNAME}/../test_helper/fixtures.sh"

# Source the libraries being tested
setup() {
    setup_test_env
    setup_test_environment
    export WIREFLOW_LIB_DIR="${BATS_TEST_DIRNAME}/../../lib"
    source "${WIREFLOW_LIB_DIR}/utils.sh"
    source "${WIREFLOW_LIB_DIR}/config.sh"
    source "${WIREFLOW_LIB_DIR}/edit.sh"
    source "${WIREFLOW_LIB_DIR}/core.sh"

    # Setup mock task directories
    export WIREFLOW_TASK_PREFIX="${BATS_TEST_TMPDIR}/tasks/custom"
    export BUILTIN_WIREFLOW_TASK_PREFIX="${BATS_TEST_TMPDIR}/tasks/builtin"
    mkdir -p "$WIREFLOW_TASK_PREFIX"
    mkdir -p "$BUILTIN_WIREFLOW_TASK_PREFIX"
}

teardown() {
    teardown_test_environment
}

# ============================================================================
# resolve_task_file tests
# ============================================================================

@test "resolve_task_file: finds task in custom location" {
    # Create custom task
    cat > "$WIREFLOW_TASK_PREFIX/my-task.txt" <<'EOF'
<description>Custom task description</description>
Custom task content
EOF

    run resolve_task_file "my-task"
    assert_success
    assert_output "$WIREFLOW_TASK_PREFIX/my-task.txt"
}

@test "resolve_task_file: falls back to builtin location" {
    # Create only builtin task (not custom)
    cat > "$BUILTIN_WIREFLOW_TASK_PREFIX/builtin-task.txt" <<'EOF'
<description>Builtin task description</description>
Builtin task content
EOF

    run resolve_task_file "builtin-task"
    assert_success
    assert_output "$BUILTIN_WIREFLOW_TASK_PREFIX/builtin-task.txt"
}

@test "resolve_task_file: prefers custom over builtin" {
    # Create task in both locations
    cat > "$WIREFLOW_TASK_PREFIX/shared-task.txt" <<'EOF'
<description>Custom version</description>
EOF
    cat > "$BUILTIN_WIREFLOW_TASK_PREFIX/shared-task.txt" <<'EOF'
<description>Builtin version</description>
EOF

    run resolve_task_file "shared-task"
    assert_success
    # Should return custom location, not builtin
    assert_output "$WIREFLOW_TASK_PREFIX/shared-task.txt"
}

@test "resolve_task_file: returns failure for missing task" {
    run resolve_task_file "nonexistent-task"
    assert_failure
    assert_output ""
}

@test "resolve_task_file: ignores empty files" {
    # Create empty task file
    touch "$WIREFLOW_TASK_PREFIX/empty-task.txt"

    run resolve_task_file "empty-task"
    assert_failure
}

# ============================================================================
# extract_task_description tests
# ============================================================================

@test "extract_task_description: extracts from description tags" {
    local task_file="${BATS_TEST_TMPDIR}/task.txt"
    cat > "$task_file" <<'EOF'
<user-task>
  <description>
    This is the task description
  </description>
  <content>Task content here</content>
</user-task>
EOF

    run extract_task_description "$task_file"
    assert_success
    assert_output "This is the task description"
}

@test "extract_task_description: truncates long descriptions" {
    local task_file="${BATS_TEST_TMPDIR}/task.txt"
    cat > "$task_file" <<'EOF'
<description>
This is a very long task description that exceeds sixty-four characters and should be truncated with an ellipsis
</description>
EOF

    run extract_task_description "$task_file"
    assert_success
    # Should be truncated to 64 chars + "..."
    assert [ ${#output} -le 70 ]
    assert_output --partial "..."
}

@test "extract_task_description: falls back to first non-empty line" {
    local task_file="${BATS_TEST_TMPDIR}/task.txt"
    cat > "$task_file" <<'EOF'

# Simple Task Title
This is the content of the task
EOF

    run extract_task_description "$task_file"
    assert_success
    # Should extract the first non-empty line (without #)
    assert_output "Simple Task Title"
}

@test "extract_task_description: handles missing description" {
    local task_file="${BATS_TEST_TMPDIR}/task.txt"
    cat > "$task_file" <<'EOF'
<user-task>
  <content>Just content, no description tags</content>
</user-task>
EOF

    run extract_task_description "$task_file"
    assert_success
    # Should return something (first non-empty line fallback)
    assert [ -n "$output" ]
}
