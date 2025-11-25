#!/usr/bin/env /opt/homebrew/bin/bash
# Unit tests for lib/edit.sh
# Tests editor detection functions

# Load existing bats helpers
load ../test_helper/bats-support/load
load ../test_helper/bats-assert/load
load ../test_helper/bats-file/load
load ../test_helper/common.bash

# Load our custom helpers
source "${BATS_TEST_DIRNAME}/../test_helper/mock_env.sh"
source "${BATS_TEST_DIRNAME}/../test_helper/fixtures.sh"

# Source the library being tested
setup() {
    setup_test_env
    setup_test_environment
    export WIREFLOW_LIB_DIR="${BATS_TEST_DIRNAME}/../../lib"
    source "${WIREFLOW_LIB_DIR}/edit.sh"
}

teardown() {
    teardown_test_environment
}

# ============================================================================
# is_vim_like tests
# ============================================================================

@test "is_vim_like: recognizes vim" {
    run is_vim_like "vim"
    assert_success
}

@test "is_vim_like: recognizes nvim" {
    run is_vim_like "nvim"
    assert_success
}

@test "is_vim_like: rejects nano" {
    run is_vim_like "nano"
    assert_failure
}

@test "is_vim_like: rejects emacs" {
    run is_vim_like "emacs"
    assert_failure
}

# ============================================================================
# supports_multiple_files tests
# ============================================================================

@test "supports_multiple_files: vim supports multiple" {
    run supports_multiple_files "vim"
    assert_success
}

@test "supports_multiple_files: emacs supports multiple" {
    run supports_multiple_files "emacs"
    assert_success
}

@test "supports_multiple_files: code supports multiple" {
    run supports_multiple_files "code"
    assert_success
}

@test "supports_multiple_files: nano does not support multiple" {
    run supports_multiple_files "nano"
    assert_failure
}
