#!/usr/bin/env /opt/homebrew/bin/bash
# Integration tests for 'wfw task' command
# Tests task-mode execution and task dependency resolution

# Load existing bats helpers
load ../test_helper/bats-support/load
load ../test_helper/bats-assert/load
load ../test_helper/bats-file/load
load ../test_helper/common.bash

# Load our custom helpers
source "${BATS_TEST_DIRNAME}/../test_helper/mock_env.sh"
source "${BATS_TEST_DIRNAME}/../test_helper/fixtures.sh"

# Setup test environment
setup() {
    setup_test_env
    mock_global_config "${BATS_TEST_TMPDIR}" >/dev/null
    export WIREFLOW_TEST_MODE="true"
    export SCRIPT_DIR="${BATS_TEST_DIRNAME}/../../"
    export TEST_WORK_DIR="${BATS_TEST_TMPDIR}/work"
    mkdir -p "$TEST_WORK_DIR"
    cd "$TEST_WORK_DIR"

    # Source wireflow libraries for direct function testing
    source "${SCRIPT_DIR}/lib/utils.sh"
    source "${SCRIPT_DIR}/lib/config.sh"
    source "${SCRIPT_DIR}/lib/execute.sh"
}

teardown() {
    cd "${BATS_TEST_DIRNAME}"
    teardown_test_environment
}

# ============================================================================
# Task execution tests
# ============================================================================

@test "task: execution with template selection" {
    # Initialize project using the script
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    # Create mock task templates
    local task_dir="${GLOBAL_CONFIG_DIR}/prompts/tasks"
    mkdir -p "$task_dir"
    create_fixture_file "$task_dir/analysis.txt" "task"
    create_fixture_file "$task_dir/general.txt" "task"

    # Set task prefix for wireflow to find the mock templates
    export WIREFLOW_TASK_PREFIX="$task_dir"

    # Create test input
    create_fixture_file "document.md" "markdown"

    # Execute task mode with template selection
    export WIREFLOW_DRY_RUN="true"

    run "${SCRIPT_DIR}/wireflow.sh" task analysis --input-file document.md
    assert_success
    assert_output --partial "DRY RUN MODE"
}

@test "task: runs in standalone mode without project" {
    # Move to directory without project
    cd "${BATS_TEST_TMPDIR}"
    mkdir -p no-project
    cd no-project

    export WIREFLOW_DRY_RUN="true"

    # Task mode can run without project initialization (standalone mode)
    run "${SCRIPT_DIR}/wireflow.sh" task analysis
    assert_success
    assert_output --partial "standalone mode"
}

@test "task: error with missing task template" {
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    export WIREFLOW_DRY_RUN="true"

    run "${SCRIPT_DIR}/wireflow.sh" task non-existent-task
    assert_failure
    assert_output --partial "not found" || assert_output --partial "Task"
}

# ============================================================================
# Task dependency resolution tests
# ============================================================================

@test "task: dependency resolution" {
    # Create tasks with dependencies
    local tasks_dir="${GLOBAL_CONFIG_DIR}/prompts/tasks"
    mkdir -p "$tasks_dir"

    # Base task
    cat > "$tasks_dir/base-task.txt" <<'EOF'
<user-task>
  <metadata>
    <name>base-task</name>
    <version>1.0</version>
  </metadata>
  <content>Base task content</content>
</user-task>
EOF

    # Dependent task
    cat > "$tasks_dir/complex-task.txt" <<'EOF'
<user-task>
  <metadata>
    <name>complex-task</name>
    <version>1.0</version>
    <dependencies>
      <dependency>base-task</dependency>
    </dependencies>
  </metadata>
  <content>Complex task content</content>
</user-task>
EOF

    # Test task dependency resolution
    export WIREFLOW_TASK_PREFIX="$tasks_dir"
    export BUILTIN_WIREFLOW_TASK_PREFIX="$tasks_dir"

    local deps
    deps=$(resolve_task_dependencies "complex-task")

    # Check that deps contains "base-task"
    [[ "$deps" == *"base-task"* ]]
}

@test "task: handles circular dependencies gracefully" {
    local tasks_dir="${GLOBAL_CONFIG_DIR}/prompts/tasks"
    mkdir -p "$tasks_dir"

    # Create circular dependency
    cat > "$tasks_dir/task-x.txt" <<'EOF'
<user-task>
  <metadata>
    <name>task-x</name>
    <version>1.0</version>
    <dependencies>
      <dependency>task-y</dependency>
    </dependencies>
  </metadata>
  <content>Task X</content>
</user-task>
EOF

    cat > "$tasks_dir/task-y.txt" <<'EOF'
<user-task>
  <metadata>
    <name>task-y</name>
    <version>1.0</version>
    <dependencies>
      <dependency>task-x</dependency>
    </dependencies>
  </metadata>
  <content>Task Y</content>
</user-task>
EOF

    export WIREFLOW_TASK_PREFIX="$tasks_dir"
    export BUILTIN_WIREFLOW_TASK_PREFIX="$tasks_dir"

    # Should handle circular dependency without infinite loop
    run resolve_task_dependencies "task-x"
    # Test that it completes without hanging (output size should be bounded)
    assert [ "${#output}" -lt "5000" ]
}
