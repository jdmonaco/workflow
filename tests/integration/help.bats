#!/usr/bin/env /opt/homebrew/bin/bash
# Integration tests for 'wfw help' and '--version' commands
# Tests help and version output

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
}

teardown() {
    teardown_test_environment
}

# ============================================================================
# Help and version tests
# ============================================================================

@test "help: shows main help" {
    run "${SCRIPT_DIR}/wireflow.sh" help
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "subcommand"
}

@test "--version: shows version" {
    run "${SCRIPT_DIR}/wireflow.sh" --version
    assert_success
    # Should show version number
    assert_output --partial "WireFlow" || assert_output --regexp "[0-9]+\.[0-9]+"
}

@test "help <cmd>: shows command help" {
    run "${SCRIPT_DIR}/wireflow.sh" help run
    assert_success
    assert_output --partial "run"
    assert_output --partial "Usage" || assert_output --partial "Options"
}
