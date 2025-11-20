#!/usr/bin/env bats

# =============================================================================
# Task Templates Tests
# =============================================================================
# Tests for built-in task templates system including creation, listing,
# preview, editing, and usage with workflow new command

load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load
load test_helper/common

# =============================================================================
# Setup and Teardown
# =============================================================================

setup() {
    setup_test_env
}

teardown() {
    cleanup_test_env
}

# =============================================================================
# Task Template Creation Tests
# =============================================================================

@test "tasks: global config creates task directory" {
    # Ensure global config
    bash "$WORKFLOW_SCRIPT" --version > /dev/null

    # Check task directory was created
    assert_dir_exists "$GLOBAL_CONFIG_DIR/tasks"
}

@test "tasks: built-in templates are created on first use" {
    # Trigger global config creation
    bash "$WORKFLOW_SCRIPT" --version > /dev/null

    # Check all 8 templates exist
    assert_file_exists "$GLOBAL_CONFIG_DIR/tasks/summarize.txt"
    assert_file_exists "$GLOBAL_CONFIG_DIR/tasks/extract.txt"
    assert_file_exists "$GLOBAL_CONFIG_DIR/tasks/analyze.txt"
    assert_file_exists "$GLOBAL_CONFIG_DIR/tasks/review.txt"
    assert_file_exists "$GLOBAL_CONFIG_DIR/tasks/compare.txt"
    assert_file_exists "$GLOBAL_CONFIG_DIR/tasks/outline.txt"
    assert_file_exists "$GLOBAL_CONFIG_DIR/tasks/explain.txt"
    assert_file_exists "$GLOBAL_CONFIG_DIR/tasks/critique.txt"
}

@test "tasks: templates follow XML skeleton format" {
    # Trigger global config creation
    bash "$WORKFLOW_SCRIPT" --version > /dev/null

    # Check template has XML structure
    run grep "<description>" "$GLOBAL_CONFIG_DIR/tasks/summarize.txt"
    assert_success

    run grep "<guidance>" "$GLOBAL_CONFIG_DIR/tasks/summarize.txt"
    assert_success

    run grep "<instructions>" "$GLOBAL_CONFIG_DIR/tasks/summarize.txt"
    assert_success

    run grep "<output-format>" "$GLOBAL_CONFIG_DIR/tasks/summarize.txt"
    assert_success
}

# =============================================================================
# Task List Tests
# =============================================================================

@test "tasks: workflow tasks lists templates" {
    # Trigger global config creation
    bash "$WORKFLOW_SCRIPT" --version > /dev/null

    run bash "$WORKFLOW_SCRIPT" tasks
    assert_success
    assert_output --partial "Available task templates:"
    assert_output --partial "summarize"
    assert_output --partial "analyze"
    assert_output --partial "critique"
}

# =============================================================================
# Task Show Tests
# =============================================================================

@test "tasks: workflow tasks show displays template" {
    # Trigger global config creation
    bash "$WORKFLOW_SCRIPT" --version > /dev/null

    run bash "$WORKFLOW_SCRIPT" tasks show summarize
    assert_success
    assert_output --partial "Task template: summarize"
    assert_output --partial "<description>"
}

@test "tasks: workflow tasks show fails for nonexistent template" {
    # Trigger global config creation
    bash "$WORKFLOW_SCRIPT" --version > /dev/null

    run bash "$WORKFLOW_SCRIPT" tasks show nonexistent
    assert_failure
    assert_output --partial "Error: Task template not found"
}

# =============================================================================
# Task Edit Tests
# =============================================================================

@test "tasks: workflow tasks edit opens template in editor" {
    # Trigger global config creation
    bash "$WORKFLOW_SCRIPT" --version > /dev/null

    # Note: Can't fully test editor opening, but verify command doesn't error
    # Editor is mocked to 'echo' in test environment
    run bash "$WORKFLOW_SCRIPT" tasks edit summarize
    assert_success
}

# =============================================================================
# Workflow New with Template Tests
# =============================================================================

@test "tasks: workflow new --task uses template" {
    # Initialize project
    bash "$WORKFLOW_SCRIPT" init . > /dev/null 2>&1

    # Ensure templates exist
    bash "$WORKFLOW_SCRIPT" --version > /dev/null

    # Create workflow with template
    run bash "$WORKFLOW_SCRIPT" new test-workflow --task summarize
    assert_success
    assert_output --partial "Created workflow:

    # Verify task.txt contains template content
    run grep "Create concise summary" ".workflow/test-workflow/task.txt"
    assert_success
}

@test "tasks: workflow new --task fails for nonexistent template" {
    # Initialize project
    bash "$WORKFLOW_SCRIPT" init . > /dev/null 2>&1

    # Try to create with nonexistent template
    run bash "$WORKFLOW_SCRIPT" new test-workflow --task nonexistent
    assert_failure
    assert_output --partial "Error: Task template not found"
}

@test "tasks: workflow new without --task uses default skeleton" {
    # Initialize project
    bash "$WORKFLOW_SCRIPT" init . > /dev/null 2>&1

    # Create workflow without template
    run bash "$WORKFLOW_SCRIPT" new test-workflow
    assert_success
    assert_output --partial "Created workflow: test-workflow"

    # Verify task.txt contains default skeleton
    run grep "Brief 1-2 sentence overview" ".workflow/test-workflow/task.txt"
    assert_success
}

# =============================================================================
# Integration Tests
# =============================================================================

@test "tasks: WIREFLOW_TASK_PREFIX enabled by default in global config" {
    # Trigger global config creation
    bash "$WORKFLOW_SCRIPT" --version > /dev/null

    # Check config has WIREFLOW_TASK_PREFIX uncommented
    run grep "^WIREFLOW_TASK_PREFIX=" "$GLOBAL_CONFIG_DIR/config"
    assert_success
    assert_output --partial ".config/wireflow/tasks"
}
