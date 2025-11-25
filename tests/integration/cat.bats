#!/usr/bin/env /opt/homebrew/bin/bash
# Integration tests for 'wfw cat' command
# Tests output display

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

    # Initialize a project and workflow
    "${SCRIPT_DIR}/wireflow.sh" init . >/dev/null 2>&1
    "${SCRIPT_DIR}/wireflow.sh" new test-workflow >/dev/null 2>&1
}

teardown() {
    cd "${BATS_TEST_DIRNAME}"
    teardown_test_environment
}

# ============================================================================
# Cat command tests
# ============================================================================

@test "cat: displays workflow output" {
    # Create mock output file
    mkdir -p .workflow/output
    echo "Test output content" > .workflow/output/test-workflow.md

    run "${SCRIPT_DIR}/wireflow.sh" cat test-workflow
    assert_success
    assert_output "Test output content"
}

@test "cat: error for missing workflow" {
    run "${SCRIPT_DIR}/wireflow.sh" cat nonexistent-workflow
    assert_failure
    assert_output --partial "output" || assert_output --partial "not found"
}

@test "cat: error for no output" {
    # Workflow exists but no output
    run "${SCRIPT_DIR}/wireflow.sh" cat test-workflow
    assert_failure
    assert_output --partial "output" || assert_output --partial "run"
}
