#!/usr/bin/env /opt/homebrew/bin/bash
# Integration tests for 'wfw list' command
# Tests workflow listing

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

    # Initialize a project
    "${SCRIPT_DIR}/wireflow.sh" init . >/dev/null 2>&1
}

teardown() {
    cd "${BATS_TEST_DIRNAME}"
    teardown_test_environment
}

# ============================================================================
# List command tests
# ============================================================================

@test "list: shows all workflows" {
    # Create workflows
    "${SCRIPT_DIR}/wireflow.sh" new workflow-a >/dev/null 2>&1
    "${SCRIPT_DIR}/wireflow.sh" new workflow-b >/dev/null 2>&1

    run "${SCRIPT_DIR}/wireflow.sh" list
    assert_success
    assert_output --partial "workflow-a"
    assert_output --partial "workflow-b"
}

@test "list: shows empty for new project" {
    run "${SCRIPT_DIR}/wireflow.sh" list
    assert_success
    # Should indicate no workflows
    assert_output --partial "no workflows" || assert_output --partial "Workflows"
}

@test "list: error outside project" {
    cd "${BATS_TEST_TMPDIR}"
    mkdir -p no-project
    cd no-project

    run "${SCRIPT_DIR}/wireflow.sh" list
    assert_failure
    assert_output --partial "project" || assert_output --partial ".workflow"
}
