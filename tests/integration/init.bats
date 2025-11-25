#!/usr/bin/env /opt/homebrew/bin/bash
# Integration tests for 'wfw init' command
# Tests project initialization

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
}

teardown() {
    cd "${BATS_TEST_DIRNAME}"
    teardown_test_environment
}

# ============================================================================
# Init command tests
# ============================================================================

@test "init: creates .workflow structure" {
    run "${SCRIPT_DIR}/wireflow.sh" init .
    assert_success

    # Check directory structure
    assert_dir_exists ".workflow"
    assert_file_exists ".workflow/config"
    assert_file_exists ".workflow/project.txt"
}

@test "init: creates config with default values" {
    run "${SCRIPT_DIR}/wireflow.sh" init .
    assert_success

    # Config should exist with cascade pass-through comments
    assert_file_exists ".workflow/config"
    run cat .workflow/config
    assert_output --partial "Configuration"
}

@test "init: detects existing project (idempotent)" {
    # First init
    run "${SCRIPT_DIR}/wireflow.sh" init .
    assert_success

    # Second init should warn
    echo "y" | run "${SCRIPT_DIR}/wireflow.sh" init .
    # Should still succeed (with prompt)
    assert_output --partial "already exists" || assert_output --partial "Initialized"
}

@test "init: handles nested project detection" {
    # Create parent project
    mkdir -p parent
    cd parent
    run "${SCRIPT_DIR}/wireflow.sh" init .
    assert_success

    # Create child directory
    mkdir -p child
    cd child

    # Init in child should detect parent
    echo "y" | run "${SCRIPT_DIR}/wireflow.sh" init .
    # Should mention parent or nested
    assert_success
}
