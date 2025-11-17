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
    assert_output --partial "Usage: workflow <subcommand>"
    assert_output --partial "init"
    assert_output --partial "new"
    assert_output --partial "edit"
    assert_output --partial "cat"
    assert_output --partial "list"
    assert_output --partial "config"
    assert_output --partial "run"
    assert_output --partial "task"
}

@test "help: --help flag shows main help" {
    run bash "$WORKFLOW_SCRIPT" --help

    assert_success
    assert_output --partial "Usage: workflow"
}

@test "help: -h flag shows main help" {
    run bash "$WORKFLOW_SCRIPT" -h

    assert_success
    assert_output --partial "Usage: workflow"
}

# =============================================================================
# Subcommand-Specific Help Tests
# =============================================================================

@test "help: 'workflow help init' shows init help" {
    run bash "$WORKFLOW_SCRIPT" help init

    assert_success
    assert_output --partial "usage: workflow init"
    assert_output --partial "<directory>"
    assert_output --partial "Initialize a workflow project"
}

@test "help: 'workflow help new' shows new help" {
    run bash "$WORKFLOW_SCRIPT" help new

    assert_success
    assert_output --partial "usage: workflow new"
    assert_output --partial "<name>"
    assert_output --partial "Create a new workflow"
}

@test "help: 'workflow help edit' shows edit help" {
    run bash "$WORKFLOW_SCRIPT" help edit

    assert_success
    assert_output --partial "usage: workflow edit"
    assert_output --partial "Edit workflow or project files"
}

@test "help: 'workflow help cat' shows cat help" {
    run bash "$WORKFLOW_SCRIPT" help cat

    assert_success
    assert_output --partial "Usage: workflow"
    assert_output --partial "cat"
    assert_output --partial "Display workflow output"
}

@test "help: 'workflow help list' shows list help" {
    run bash "$WORKFLOW_SCRIPT" help list

    assert_success
    assert_output --partial "usage: workflow list"
    assert_output --partial "List all workflows"
}

@test "help: 'workflow help config' shows config help" {
    run bash "$WORKFLOW_SCRIPT" help config

    assert_success
    assert_output --partial "usage: workflow config"
    assert_output --partial "configuration"
}

@test "help: 'workflow help run' shows run help" {
    run bash "$WORKFLOW_SCRIPT" help run

    assert_success
    assert_output --partial "usage: workflow run"
    assert_output --partial "Context Options"
    assert_output --partial "--depends-on"
}

@test "help: 'workflow help task' shows task help" {
    run bash "$WORKFLOW_SCRIPT" help task

    assert_success
    assert_output --partial "usage: workflow task"
    assert_output --partial "--inline"
    assert_output --partial "one-off task"
}

@test "help: 'workflow help invalid' shows error and main help" {
    run bash "$WORKFLOW_SCRIPT" help invalid

    assert_failure
    assert_output --partial "Unknown subcommand: invalid"
    assert_output --partial "Usage: workflow"
}

# =============================================================================
# Subcommand -h Flag Tests
# =============================================================================

@test "help: 'workflow init -h' shows init help" {
    run bash "$WORKFLOW_SCRIPT" init -h

    assert_success
    assert_output --partial "usage: workflow init"
}

@test "help: 'workflow new -h' shows new help" {
    run bash "$WORKFLOW_SCRIPT" new -h

    assert_success
    assert_output --partial "usage: workflow new"
}

@test "help: 'workflow edit -h' shows edit help" {
    run bash "$WORKFLOW_SCRIPT" edit -h

    assert_success
    assert_output --partial "usage: workflow edit"
}

@test "help: 'workflow cat -h' shows cat help" {
    run bash "$WORKFLOW_SCRIPT" cat -h

    assert_success
    assert_output --partial "Usage: workflow"
    assert_output --partial "cat"
}

@test "help: 'workflow list -h' shows list help" {
    run bash "$WORKFLOW_SCRIPT" list -h

    assert_success
    assert_output --partial "usage: workflow list"
}

@test "help: 'workflow config -h' shows config help" {
    run bash "$WORKFLOW_SCRIPT" config -h

    assert_success
    assert_output --partial "usage: workflow config"
}

@test "help: 'workflow run -h' shows run help" {
    run bash "$WORKFLOW_SCRIPT" run -h

    assert_success
    assert_output --partial "usage: workflow run"
}

@test "help: 'workflow task -h' shows task help" {
    run bash "$WORKFLOW_SCRIPT" task -h

    assert_success
    assert_output --partial "usage: workflow task"
}
