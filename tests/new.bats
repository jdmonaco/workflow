#!/usr/bin/env bats

load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load
load test_helper/common

setup() {
    setup_test_env

    # Initialize a project for all tests
    bash "$WORKFLOW_SCRIPT" init .
}

teardown() {
    cleanup_test_env
}

@test "new: creates workflow directory with required files" {
    run bash "$WORKFLOW_SCRIPT" new test-workflow

    assert_success
    assert_dir_exists ".workflow/test-workflow"
    assert_file_exists ".workflow/test-workflow/task.txt"
    assert_file_exists ".workflow/test-workflow/config"
}

@test "new: creates valid template config" {
    bash "$WORKFLOW_SCRIPT" new test-workflow

    assert_file_exists ".workflow/test-workflow/config"

    # Check config has expected template content
    run cat .workflow/test-workflow/config
    assert_output --partial "# Workflow-specific configuration"
    assert_output --partial "INPUT_PATTERN"
    assert_output --partial "INPUT_FILES"
    assert_output --partial "CONTEXT_PATTERN"
    assert_output --partial "CONTEXT_FILES"
    assert_output --partial "DEPENDS_ON"
    assert_output --partial "Paths in INPUT_* and CONTEXT_* are relative to project root"
}

@test "new: creates task.txt with skeleton" {
    bash "$WORKFLOW_SCRIPT" new test-workflow

    assert_file_exists ".workflow/test-workflow/task.txt"

    # Should contain XML skeleton (not empty)
    [[ -s ".workflow/test-workflow/task.txt" ]]
}

@test "new: fails when workflow name not provided" {
    run bash "$WORKFLOW_SCRIPT" new

    assert_failure
    assert_output --partial "Workflow name required"
}

@test "new: fails when workflow already exists" {
    # Create workflow first time
    bash "$WORKFLOW_SCRIPT" new test-workflow

    # Try to create again
    run bash "$WORKFLOW_SCRIPT" new test-workflow

    assert_failure
    assert_output --partial "already exists"
}

@test "new: fails when not in workflow project" {
    # Move outside project
    cd "$TEST_TEMP_DIR"

    run bash "$WORKFLOW_SCRIPT" new test-workflow

    assert_failure
    assert_output --partial "Not in workflow project"
}

@test "new: works from subdirectory within project" {
    # Create a subdirectory and work from there
    mkdir subdir
    cd subdir

    run bash "$WORKFLOW_SCRIPT" new test-workflow

    assert_success
    assert_dir_exists "../.workflow/test-workflow"
}

@test "new: workflow name with numbers and dashes" {
    run bash "$WORKFLOW_SCRIPT" new 01-my-workflow

    assert_success
    assert_dir_exists ".workflow/01-my-workflow"
}

@test "new: task.txt created with XML skeleton" {
    run bash "$WORKFLOW_SCRIPT" new test-workflow

    assert_success
    assert_file_exists ".workflow/test-workflow/task.txt"

    # Verify XML skeleton sections exist
    run cat ".workflow/test-workflow/task.txt"
    assert_output --partial "<description>"
    assert_output --partial "</description>"
    assert_output --partial "<guidance>"
    assert_output --partial "</guidance>"
    assert_output --partial "<instructions>"
    assert_output --partial "</instructions>"
    assert_output --partial "<output-format>"
    assert_output --partial "</output-format>"
}

@test "new: task.txt skeleton has placeholder text" {
    run bash "$WORKFLOW_SCRIPT" new test-workflow

    assert_success

    # Verify placeholder guidance text exists
    run cat ".workflow/test-workflow/task.txt"
    assert_output --partial "Brief 1-2 sentence overview"
    assert_output --partial "High-level strategic guidance"
    assert_output --partial "Detailed step-by-step instructions"
    assert_output --partial "Specific formatting requirements"
}

@test "new: task.txt skeleton has proper empty lines" {
    run bash "$WORKFLOW_SCRIPT" new test-workflow

    assert_success

    # Verify empty lines between sections (count should be 3)
    local empty_line_count
    empty_line_count=$(grep -c "^$" ".workflow/test-workflow/task.txt" || true)
    [[ "$empty_line_count" -eq 3 ]]
}
