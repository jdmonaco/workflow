#!/usr/bin/env /opt/homebrew/bin/bash
# Integration tests for 'wfw config' command
# Tests configuration display

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
# Config command tests
# ============================================================================

@test "config: shows effective configuration" {
    run "${SCRIPT_DIR}/wireflow.sh" config
    assert_success
    # Should show config output
    assert_output --partial "Project" || assert_output --partial "config"
}

@test "config: shows workflow-specific config" {
    # Create a workflow first
    "${SCRIPT_DIR}/wireflow.sh" new test-workflow >/dev/null 2>&1

    run "${SCRIPT_DIR}/wireflow.sh" config test-workflow
    assert_success
    assert_output --partial "test-workflow" || assert_output --partial "Workflow"
}

@test "config: cascade from parent project" {
    # Set a value in project config
    echo 'MODEL="claude-opus-4"' >> .workflow/config

    run "${SCRIPT_DIR}/wireflow.sh" config
    assert_success
    # Should show the model setting
    assert_output --partial "MODEL" || assert_output --partial "claude"
}

@test "config: error outside project" {
    cd "${BATS_TEST_TMPDIR}"
    mkdir -p no-project
    cd no-project

    run "${SCRIPT_DIR}/wireflow.sh" config
    assert_failure
    assert_output --partial "project" || assert_output --partial ".workflow"
}
