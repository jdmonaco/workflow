#!/usr/bin/env bats

load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load
load test_helper/common

setup() {
    setup_test_env
}

teardown() {
    cleanup_test_env
}

# =============================================================================
# Main Help Tests
# =============================================================================

@test "help: main help shows all subcommands" {
    run bash "$WORKFLOW_SCRIPT" help

    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "init"
    assert_output --partial "new"
    assert_output --partial "edit"
    assert_output --partial "cat"
    assert_output --partial "open"
    assert_output --partial "list"
    assert_output --partial "config"
    assert_output --partial "run"
    assert_output --partial "task"
}

@test "help: --help flag shows main help" {
    run bash "$WORKFLOW_SCRIPT" --help

    assert_success
    assert_output --partial "Usage:"
}

@test "help: -h flag shows main help" {
    run bash "$WORKFLOW_SCRIPT" -h

    assert_success
    assert_output --partial "Usage:"
}

# =============================================================================
# Subcommand-Specific Help Tests
# =============================================================================

@test "help: 'workflow help init' shows init help" {
    run bash "$WORKFLOW_SCRIPT" help init

    assert_success
    assert_output --partial "Usage: wireflow.sh init"
    assert_output --partial "<directory>"
    assert_output --partial "Initialize a workflow project"
}

@test "help: 'workflow help new' shows new help" {
    run bash "$WORKFLOW_SCRIPT" help new

    assert_success
    assert_output --partial "Usage: wireflow.sh new"
    assert_output --partial "<name>"
    assert_output --partial "Create a new workflow"
}

@test "help: --version flag shows version" {
    run bash "$WORKFLOW_SCRIPT" --version

    assert_success
    assert_output --partial "workflow version"
    assert_output --partial "0.3.0"
}

@test "help: -v flag shows version" {
    run bash "$WORKFLOW_SCRIPT" -v

    assert_success
    assert_output --partial "workflow version"
    assert_output --partial "0.3.0"
}

@test "help: main help shows version" {
    run bash "$WORKFLOW_SCRIPT" --help

    assert_success
    assert_output --partial "Version: 0.3.0"
}

@test "help: 'workflow help edit' shows edit help" {
    run bash "$WORKFLOW_SCRIPT" help edit

    assert_success
    assert_output --partial "Usage: wireflow.sh edit"
    assert_output --partial "Edit workflow or project files"
}

@test "help: 'workflow help cat' shows cat help" {
    run bash "$WORKFLOW_SCRIPT" help cat

    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "cat"
    assert_output --partial "Display workflow output"
}

@test "help: 'workflow help open' shows open help" {
    run bash "$WORKFLOW_SCRIPT" help open

    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "open"
    assert_output --partial "default application"
}

@test "help: 'workflow help list' shows list help" {
    run bash "$WORKFLOW_SCRIPT" help list

    assert_success
    assert_output --partial "Usage: wireflow.sh list"
    assert_output --partial "List all workflows"
}

@test "help: 'workflow help config' shows config help" {
    run bash "$WORKFLOW_SCRIPT" help config

    assert_success
    assert_output --partial "Usage: wireflow.sh config"
    assert_output --partial "configuration"
}

@test "help: 'workflow help run' shows run help" {
    run bash "$WORKFLOW_SCRIPT" help run

    assert_success
    assert_output --partial "Usage: wireflow.sh run"
    assert_output --partial "Context Options"
    assert_output --partial "--depends-on"
}

@test "help: 'workflow help task' shows task help" {
    run bash "$WORKFLOW_SCRIPT" help task

    assert_success
    assert_output --partial "Usage: wireflow.sh task"
    assert_output --partial "--inline"
    assert_output --partial "one-off task"
}

@test "help: 'workflow help invalid' shows error and main help" {
    run bash "$WORKFLOW_SCRIPT" help invalid

    assert_failure
    assert_output --partial "Unknown subcommand: invalid"
    assert_output --partial "Usage:"
}

# =============================================================================
# Subcommand -h Flag Tests
# =============================================================================

@test "help: 'workflow init -h' shows init help" {
    run bash "$WORKFLOW_SCRIPT" init -h

    assert_success
    assert_output --partial "Usage: wireflow.sh init"
}

@test "help: 'workflow new -h' shows new help" {
    run bash "$WORKFLOW_SCRIPT" new -h

    assert_success
    assert_output --partial "Usage: wireflow.sh new"
}

@test "help: 'workflow edit -h' shows edit help" {
    run bash "$WORKFLOW_SCRIPT" edit -h

    assert_success
    assert_output --partial "Usage: wireflow.sh edit"
}

@test "help: 'workflow cat -h' shows cat help" {
    run bash "$WORKFLOW_SCRIPT" cat -h

    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "cat"
}

@test "help: 'workflow open -h' shows open help" {
    run bash "$WORKFLOW_SCRIPT" open -h

    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "open"
}

@test "help: 'workflow list -h' shows list help" {
    run bash "$WORKFLOW_SCRIPT" list -h

    assert_success
    assert_output --partial "Usage: wireflow.sh list"
}

@test "help: 'workflow config -h' shows config help" {
    run bash "$WORKFLOW_SCRIPT" config -h

    assert_success
    assert_output --partial "Usage: wireflow.sh config"
}

@test "help: 'workflow run -h' shows run help" {
    run bash "$WORKFLOW_SCRIPT" run -h

    assert_success
    assert_output --partial "Usage: wireflow.sh run"
}

@test "help: 'workflow task -h' shows task help" {
    run bash "$WORKFLOW_SCRIPT" task -h

    assert_success
    assert_output --partial "Usage: wireflow.sh task"
}
