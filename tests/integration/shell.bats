#!/usr/bin/env /opt/homebrew/bin/bash
# Integration tests for 'wfw shell' command
# Tests shell integration installation, doctor, and uninstall

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
# Shell install tests
# ============================================================================

@test "shell: install creates wfw symlink" {
    run "${SCRIPT_DIR}/wireflow.sh" shell install
    assert_success

    # Check that wfw symlink was created
    local bin_dir="${HOME}/.local/bin"
    assert_file_exists "$bin_dir/wfw"
    assert [ -L "$bin_dir/wfw" ]  # Is a symlink

    # Verify it points to wireflow.sh
    local target
    target=$(readlink "$bin_dir/wfw")
    assert [ -n "$target" ]
    assert_output --partial "Installed:"
}

@test "shell: install creates completions symlink" {
    run "${SCRIPT_DIR}/wireflow.sh" shell install
    assert_success

    # Check completions directory
    local comp_dir="${HOME}/.local/share/bash-completion/completions"
    assert_file_exists "$comp_dir/wfw"
    assert [ -L "$comp_dir/wfw" ]  # Is a symlink
}

@test "shell: install creates prompt helper symlink" {
    run "${SCRIPT_DIR}/wireflow.sh" shell install
    assert_success

    # Check prompt helper
    local share_dir="${HOME}/.local/share/wireflow"
    assert_file_exists "$share_dir/wfw-prompt.sh"
    assert [ -L "$share_dir/wfw-prompt.sh" ]  # Is a symlink
}

@test "shell: install is idempotent" {
    # First install
    run "${SCRIPT_DIR}/wireflow.sh" shell install
    assert_success

    # Second install should succeed with "Already installed" messages
    run "${SCRIPT_DIR}/wireflow.sh" shell install
    assert_success
    assert_output --partial "Already installed"
}

# ============================================================================
# Shell doctor tests
# ============================================================================

@test "shell: doctor succeeds and reinstalls symlinks" {
    # First install
    run "${SCRIPT_DIR}/wireflow.sh" shell install
    assert_success

    # Doctor should succeed
    run "${SCRIPT_DIR}/wireflow.sh" shell doctor
    assert_success
    assert_output --partial "Installed:"
}

@test "shell: doctor checks completion loading status" {
    run "${SCRIPT_DIR}/wireflow.sh" shell doctor
    assert_success

    # Should mention completions status (either loaded or not loaded warning)
    assert_output --partial "Completions"
}

@test "shell: doctor checks prompt status" {
    run "${SCRIPT_DIR}/wireflow.sh" shell doctor
    assert_success

    # Should mention prompt status
    assert_output --partial "Prompt:"
}

# ============================================================================
# Shell uninstall tests
# ============================================================================

@test "shell: uninstall removes symlinks" {
    # Install first
    run "${SCRIPT_DIR}/wireflow.sh" shell install
    assert_success

    # Uninstall
    run "${SCRIPT_DIR}/wireflow.sh" shell uninstall
    assert_success
    assert_output --partial "Removed:"

    # Verify symlinks are gone
    local bin_dir="${HOME}/.local/bin"
    assert [ ! -e "$bin_dir/wfw" ]
}

@test "shell: uninstall with nothing installed shows 'Not installed'" {
    # Don't install first, just try to uninstall
    run "${SCRIPT_DIR}/wireflow.sh" shell uninstall
    assert_success
    assert_output --partial "Not installed:"
}

@test "shell: uninstall checks shell config files" {
    run "${SCRIPT_DIR}/wireflow.sh" shell uninstall
    assert_success
    assert_output --partial "Checking shell config files"
}

# ============================================================================
# Shell help and error tests
# ============================================================================

@test "shell: no action shows help" {
    run "${SCRIPT_DIR}/wireflow.sh" shell
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "shell"
}

@test "shell: -h shows quick help" {
    run "${SCRIPT_DIR}/wireflow.sh" shell -h
    assert_success
    assert_output --partial "Usage:"
}

@test "shell: unknown action shows error" {
    run "${SCRIPT_DIR}/wireflow.sh" shell invalid-action
    assert_failure
    assert_output --partial "Error: Unknown shell action"
}

@test "shell: help shell shows detailed help" {
    run "${SCRIPT_DIR}/wireflow.sh" help shell
    assert_success
    assert_output --partial "install"
    assert_output --partial "doctor"
    assert_output --partial "uninstall"
}
