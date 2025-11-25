#!/usr/bin/env /opt/homebrew/bin/bash
# Integration tests for 'wfw new' command
# Tests workflow creation

# Load existing bats helpers
load ../test_helper/bats-support/load
load ../test_helper/bats-assert/load
load ../test_helper/bats-file/load
load ../test_helper/common.bash

# Load our custom helpers
source "${BATS_TEST_DIRNAME}/../test_helper/mock_env.sh"

# Setup test environment
setup() {
    setup_test_env
    mock_global_config "${BATS_TEST_TMPDIR}" >/dev/null
    export SCRIPT_DIR="${BATS_TEST_DIRNAME}/../../"
    export TEST_WORK_DIR="${BATS_TEST_TMPDIR}/work"
    mkdir -p "$TEST_WORK_DIR"
    cd "$TEST_WORK_DIR"

    # Initialize a project first
    "${SCRIPT_DIR}/wireflow.sh" init . >/dev/null 2>&1
}

teardown() {
    cd "${BATS_TEST_DIRNAME}"
    teardown_test_environment
}

# ============================================================================
# New command tests
# ============================================================================

@test "new: creates workflow directory" {
    run "${SCRIPT_DIR}/wireflow.sh" new test-workflow
    assert_success

    assert_dir_exists ".workflow/run/test-workflow"
}

@test "new: generates task.txt skeleton" {
    run "${SCRIPT_DIR}/wireflow.sh" new my-workflow
    assert_success

    assert_file_exists ".workflow/run/my-workflow/task.txt"
    run cat ".workflow/run/my-workflow/task.txt"
    assert_output --partial "<user-task>"
}

@test "new: generates workflow config" {
    run "${SCRIPT_DIR}/wireflow.sh" new config-test
    assert_success

    assert_file_exists ".workflow/run/config-test/config"
    run cat ".workflow/run/config-test/config"
    assert_output --partial "Configuration"
}

@test "new: error outside project" {
    # Move to directory without project
    cd "${BATS_TEST_TMPDIR}"
    mkdir -p no-project
    cd no-project

    run "${SCRIPT_DIR}/wireflow.sh" new test-workflow
    assert_failure
    assert_output --partial "project" || assert_output --partial ".workflow"
}
