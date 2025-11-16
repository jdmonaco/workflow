#!/usr/bin/env bats

load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load
load test_helper/common

setup() {
    setup_test_env

    # Create task directory and sample tasks
    export WORKFLOW_TASK_PREFIX="$TEST_TEMP_DIR/tasks"
    mkdir -p "$WORKFLOW_TASK_PREFIX"
    echo "Summarize the key findings from the research." > "$WORKFLOW_TASK_PREFIX/summarize.txt"
    echo "Extract action items and deadlines." > "$WORKFLOW_TASK_PREFIX/extract-actions.txt"

    # Mock curl for API responses
    mock_curl_streaming
}

teardown() {
    unmock_curl
    cleanup_test_env
}

@test "task: executes named task from file" {
    run bash "$WORKFLOW_SCRIPT" task summarize

    assert_success
    assert_output --partial "Loaded task: summarize"
    assert_output --partial "Test streaming response"
}

@test "task: executes inline task with --inline flag" {
    run bash "$WORKFLOW_SCRIPT" task --inline "Analyze the data patterns"

    assert_success
    assert_output --partial "Using inline task"
    assert_output --partial "Test streaming response"
}

@test "task: executes inline task with -i short flag" {
    run bash "$WORKFLOW_SCRIPT" task -i "Extract key points"

    assert_success
    assert_output --partial "Using inline task"
    assert_output --partial "Test streaming response"
}

@test "task: fails when neither NAME nor --inline provided" {
    run bash "$WORKFLOW_SCRIPT" task

    assert_failure
    assert_output --partial "Must specify either task NAME or --inline TEXT"
}

@test "task: fails when both NAME and --inline provided" {
    run bash "$WORKFLOW_SCRIPT" task summarize --inline "Also this"

    assert_failure
    assert_output --partial "Cannot specify both task NAME and --inline TEXT"
}

@test "task: fails when WORKFLOW_TASK_PREFIX not set (named task)" {
    unset WORKFLOW_TASK_PREFIX

    run bash "$WORKFLOW_SCRIPT" task summarize

    assert_failure
    assert_output --partial "WORKFLOW_TASK_PREFIX environment variable is not set"
}

@test "task: inline task works without WORKFLOW_TASK_PREFIX" {
    unset WORKFLOW_TASK_PREFIX

    run bash "$WORKFLOW_SCRIPT" task -i "Do something"

    assert_success
    assert_output --partial "Using inline task"
}

@test "task: fails when task file not found" {
    run bash "$WORKFLOW_SCRIPT" task nonexistent

    assert_failure
    assert_output --partial "Task file not found"
    assert_output --partial "nonexistent.txt"
}

@test "task: works with --context-file" {
    echo "Test context data" > context.txt

    run bash "$WORKFLOW_SCRIPT" task -i "Process this" --context-file context.txt

    assert_success
    assert_output --partial "Adding explicit files from CLI"
}

@test "task: works with --context-pattern" {
    mkdir -p data
    echo "Data 1" > data/file1.txt
    echo "Data 2" > data/file2.txt

    run bash "$WORKFLOW_SCRIPT" task -i "Analyze data" --context-pattern "data/*.txt"

    assert_success
    assert_output --partial "Adding files from CLI pattern"
}

@test "task: works with --output-file" {
    run bash "$WORKFLOW_SCRIPT" task -i "Generate report" --output-file report.md

    assert_success
    assert_file_exists "report.md"
    assert_output --partial "Response saved to: report.md"
}

@test "task: streams to stdout without --output-file" {
    run bash "$WORKFLOW_SCRIPT" task -i "Quick task"

    assert_success
    assert_output --partial "Test streaming response"
    # Should not create any output files in current directory
    run ls -la *.md 2>/dev/null
    assert_failure
}

@test "task: works with project context when in project" {
    # Initialize a project
    bash "$WORKFLOW_SCRIPT" init . > /dev/null 2>&1

    # Add project description
    echo "This is a test project." > .workflow/project.txt

    # Set project config
    cat > .workflow/config <<'EOF'
MODEL="claude-opus-4"
TEMPERATURE=0.7
EOF

    run bash "$WORKFLOW_SCRIPT" task -i "Test task"

    assert_success
    assert_output --partial "Using project context"
    # Should use project config values (would need API mocking to fully verify)
}

@test "task: works in standalone mode outside project" {
    # Move to temp dir without project
    cd "$TEST_TEMP_DIR"

    run bash "$WORKFLOW_SCRIPT" task -i "Standalone task"

    assert_success
    assert_output --partial "Running in standalone mode"
    assert_output --partial "Test streaming response"
}

@test "task: respects --system-prompts override" {
    # Create additional prompt file
    echo "NeuroAI specialized prompt" > "$WORKFLOW_PROMPT_PREFIX/NeuroAI.txt"

    run bash "$WORKFLOW_SCRIPT" task -i "Test" --system-prompts "base,NeuroAI"

    assert_success
    assert_output --partial "Building system prompt from: base NeuroAI"
}

@test "task: respects --model override" {
    run bash "$WORKFLOW_SCRIPT" task -i "Test" --model claude-haiku-4 --dry-run

    assert_success
    # Would need to check API call payload to fully verify
}

@test "task: respects --max-tokens override" {
    run bash "$WORKFLOW_SCRIPT" task -i "Test" --max-tokens 16384 --dry-run

    assert_success
}

@test "task: dry-run mode estimates tokens without API call" {
    run bash "$WORKFLOW_SCRIPT" task -i "Test task" --dry-run

    assert_success
    assert_output --partial "Estimated system tokens:"
    assert_output --partial "Estimated task tokens:"
    assert_output --partial "Estimated total input tokens:"
    assert_output --partial "Dry-run mode: Stopping before API call"
}

@test "task: --no-stream uses single-batch mode" {
    mock_curl_success

    run bash "$WORKFLOW_SCRIPT" task -i "Test" --no-stream --output-file output.md

    assert_success
    assert_file_exists "output.md"
}

@test "task: backs up existing output file" {
    # Create existing output file
    echo "Old content" > output.md

    run bash "$WORKFLOW_SCRIPT" task -i "Test" --output-file output.md

    assert_success
    # Should have created backup
    run ls -1 output-*.md
    assert_success
    assert_output --partial "output-"
}

@test "task: handles JSON output format" {
    run bash "$WORKFLOW_SCRIPT" task -i "Generate JSON" --output-format json --output-file data.json

    assert_success
    assert_file_exists "data.json"
    assert_output --partial "Response saved to: data.json"
}

@test "task: warns when no context provided" {
    run bash "$WORKFLOW_SCRIPT" task -i "Test without context"

    assert_success
    assert_output --partial "Warning: No context provided"
}

@test "task: fails when ANTHROPIC_API_KEY not set" {
    unset ANTHROPIC_API_KEY

    run bash "$WORKFLOW_SCRIPT" task -i "Test"

    assert_failure
    assert_output --partial "ANTHROPIC_API_KEY"
}

@test "task: fails when WORKFLOW_PROMPT_PREFIX not set" {
    unset WORKFLOW_PROMPT_PREFIX

    run bash "$WORKFLOW_SCRIPT" task -i "Test"

    assert_failure
    assert_output --partial "WORKFLOW_PROMPT_PREFIX"
}
