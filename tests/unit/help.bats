#!/usr/bin/env /opt/homebrew/bin/bash
# Unit tests for lib/help.sh
# Tests help output functions

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
    export SCRIPT_NAME="wfw"

    # Set required env vars for help output
    export WIREFLOW_PROMPT_PREFIX="${BATS_TEST_TMPDIR}/prompts"
    export WIREFLOW_TASK_PREFIX="${BATS_TEST_TMPDIR}/tasks"
    export GLOBAL_CONFIG_FILE="${BATS_TEST_TMPDIR}/config"
    mkdir -p "$WIREFLOW_PROMPT_PREFIX" "$WIREFLOW_TASK_PREFIX"

    source "${WIREFLOW_LIB_DIR}/utils.sh"
    source "${WIREFLOW_LIB_DIR}/help.sh"
}

teardown() {
    teardown_test_environment
}

# ============================================================================
# Main help tests
# ============================================================================

@test "show_help: contains all subcommands" {
    run show_help
    assert_success
    # Check for all documented subcommands in canonical order
    assert_output --partial "init"
    assert_output --partial "new"
    assert_output --partial "edit"
    assert_output --partial "config"
    assert_output --partial "run"
    assert_output --partial "task"
    assert_output --partial "cat"
    assert_output --partial "open"
    assert_output --partial "list"
    assert_output --partial "help"
}

@test "show_help: shows environment variables" {
    run show_help
    assert_success
    assert_output --partial "ANTHROPIC_API_KEY"
    assert_output --partial "WIREFLOW_PROMPT_PREFIX"
    assert_output --partial "WIREFLOW_TASK_PREFIX"
}

# ============================================================================
# Quick help tests (spot check)
# ============================================================================

@test "show_quick_help_init: shows usage" {
    run show_quick_help_init
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "init"
}

@test "show_quick_help_run: shows usage" {
    run show_quick_help_run
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "run"
}

@test "show_quick_help_task: shows usage" {
    run show_quick_help_task
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "task"
    assert_output --partial "--inline"
}
