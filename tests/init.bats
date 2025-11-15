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

@test "init: creates .workflow directory with all required files" {
    run bash "$WORKFLOW_SCRIPT" init .

    assert_success
    assert_dir_exists ".workflow"
    assert_dir_exists ".workflow/prompts"
    assert_dir_exists ".workflow/output"
    assert_file_exists ".workflow/config"
    assert_file_exists ".workflow/project.txt"
}

@test "init: creates config with default values" {
    bash "$WORKFLOW_SCRIPT" init .

    assert_file_exists ".workflow/config"

    # Source config and check defaults
    source .workflow/config
    assert_equal "$MODEL" "claude-sonnet-4-5"
    assert_equal "$TEMPERATURE" "1.0"
    assert_equal "$MAX_TOKENS" "4096"
    assert_equal "$OUTPUT_FORMAT" "md"
    assert_equal "${SYSTEM_PROMPTS[0]}" "Root"
}

@test "init: fails when project already initialized" {
    # First init succeeds
    bash "$WORKFLOW_SCRIPT" init .

    # Second init fails
    run bash "$WORKFLOW_SCRIPT" init .

    assert_failure
    assert_output --partial "already initialized"
}

@test "init: can initialize in specified directory" {
    mkdir subdir

    run bash "$WORKFLOW_SCRIPT" init subdir

    assert_success
    assert_dir_exists "subdir/.workflow"
}

@test "init: nested project detects parent and inherits config" {
    # Create parent project
    bash "$WORKFLOW_SCRIPT" init .

    # Modify parent config
    cat >> .workflow/config <<'EOF'
MODEL="claude-opus-4"
TEMPERATURE=0.5
SYSTEM_PROMPTS=(Root NeuroAI)
EOF

    # Create nested project (respond 'y' to prompt)
    mkdir nested
    cd nested

    run bash -c "echo 'y' | bash '$WORKFLOW_SCRIPT' init ."

    assert_success
    assert_output --partial "Initializing nested project"
    assert_output --partial "Inheriting configuration"
    assert_output --partial "claude-opus-4"
    assert_output --partial "0.5"

    # Verify inherited config
    source .workflow/config
    assert_equal "$MODEL" "claude-opus-4"
    assert_equal "$TEMPERATURE" "0.5"
    assert_equal "${SYSTEM_PROMPTS[0]}" "Root"
    assert_equal "${SYSTEM_PROMPTS[1]}" "NeuroAI"
}

@test "init: nested project can decline inheritance" {
    # Create parent
    bash "$WORKFLOW_SCRIPT" init .

    # Create nested, respond 'n' to prompt
    mkdir nested
    cd nested

    run bash -c "echo 'n' | bash '$WORKFLOW_SCRIPT' init ."

    # Should exit without creating project
    assert_success
    [[ ! -d ".workflow" ]]
}
