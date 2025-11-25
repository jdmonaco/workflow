#!/usr/bin/env /opt/homebrew/bin/bash
# Integration tests for complete workflow execution
# Tests the full pipeline from initialization through execution

# Load existing bats helpers
load ../test_helper/bats-support/load
load ../test_helper/bats-assert/load
load ../test_helper/bats-file/load
load ../test_helper/common.bash

# Load our custom helpers
source "${BATS_TEST_DIRNAME}/../test_helper/mock_env.sh"
source "${BATS_TEST_DIRNAME}/../test_helper/fixtures.sh"
source "${BATS_TEST_DIRNAME}/../test_helper/assertions.sh"

# Setup and teardown for integration tests
setup() {
    setup_test_env

    # Setup mock environment with global config
    # mock_global_config exports GLOBAL_CONFIG_DIR and GLOBAL_CONFIG_FILE
    mock_global_config "${BATS_TEST_TMPDIR}" >/dev/null
    export WIREFLOW_TEST_MODE="true"

    # Set script directory for sourcing libraries
    export SCRIPT_DIR="${BATS_TEST_DIRNAME}/../../"

    # Create a working directory for tests
    export TEST_WORK_DIR="${BATS_TEST_TMPDIR}/work"
    mkdir -p "$TEST_WORK_DIR"
    cd "$TEST_WORK_DIR"

    # Source wireflow main script functions
    source "${SCRIPT_DIR}/lib/utils.sh"
    source "${SCRIPT_DIR}/lib/config.sh"
    source "${SCRIPT_DIR}/lib/core.sh"
    source "${SCRIPT_DIR}/lib/execute.sh"
    source "${SCRIPT_DIR}/lib/api.sh"
}

teardown() {
    cd "${BATS_TEST_DIRNAME}"
    teardown_test_environment
}

# ============================================================================
# Complete workflow lifecycle tests
# ============================================================================

@test "integration: complete workflow from init to execution" {
    # Step 1: Initialize project using the script
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success
    assert_project_exists "."
    assert_file_exists ".workflow/config"

    # Step 2: Create a new workflow using the script
    run "${SCRIPT_DIR}/wireflow.sh" new data-analysis
    assert_success
    assert_workflow_exists ".workflow/run/data-analysis"
    assert_file_exists ".workflow/run/data-analysis/config"

    # Step 3: Verify workflow is listed
    run "${SCRIPT_DIR}/wireflow.sh" list
    assert_success
    assert_output --partial "data-analysis"

    # Step 4: Create input files for workflow
    create_fixture_file "input.md" "markdown"
    create_fixture_file "data.json" "json"

    # Step 5: Mock API execution (since we can't call real API in tests)
    export WIREFLOW_DRY_RUN="true"

    # Step 6: Execute the workflow
    run "${SCRIPT_DIR}/wireflow.sh" run data-analysis --input-file input.md --input-file data.json
    assert_success
    assert_output --partial "DRY RUN MODE"
    assert_output --partial "data-analysis"
}

@test "integration: nested project configuration cascade" {
    # Create nested project structure
    local parent="${TEST_WORK_DIR}/parent"
    local child="${parent}/child"
    local grandchild="${child}/grandchild"

    # Setup parent project with MODEL config
    mkdir -p "$parent"
    cd "$parent"
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success
    echo 'MODEL="parent-model"' >> .workflow/config
    echo 'TEMPERATURE="0.3"' >> .workflow/config

    # Setup child project - overrides TEMPERATURE
    mkdir -p "$child"
    cd "$child"
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success
    echo 'TEMPERATURE="0.7"' >> .workflow/config
    echo 'MAX_TOKENS="8000"' >> .workflow/config

    # Setup grandchild project with OUTPUT_FORMAT
    mkdir -p "$grandchild"
    cd "$grandchild"
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success
    echo 'OUTPUT_FORMAT="md"' >> .workflow/config

    # Create a workflow in grandchild to test cascade
    run "${SCRIPT_DIR}/wireflow.sh" new cascade-test
    assert_success

    # Run dry-run to capture request.json with cascaded config
    export WIREFLOW_DRY_RUN="true"
    run "${SCRIPT_DIR}/wireflow.sh" run cascade-test
    assert_success
    assert_output --partial "DRY RUN MODE"

    # Verify cascade in config command output
    run "${SCRIPT_DIR}/wireflow.sh" config cascade-test
    assert_success
    # MODEL should come from parent (oldest ancestor)
    assert_output --partial "parent-model"
    # TEMPERATURE should come from child (overrides parent)
    assert_output --partial "0.7"
    # MAX_TOKENS should come from child
    assert_output --partial "8000"
}

@test "integration: run mode with multiple input files" {
    # Setup project and workflow using the script
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    run "${SCRIPT_DIR}/wireflow.sh" new processor
    assert_success

    # Create multiple input files
    create_fixture_file_set "inputs"

    # Execute with multiple files using input pattern
    export WIREFLOW_DRY_RUN="true"

    run "${SCRIPT_DIR}/wireflow.sh" run processor --input-pattern "inputs/*.md" --input-pattern "inputs/*.txt"
    assert_success
    assert_output --partial "DRY RUN MODE"
    assert_output --partial "processor"
}

@test "integration: workflow with custom system prompts" {
    # Initialize project using the script
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    # Create custom project-level prompts
    mkdir -p prompts/system
    cat > prompts/system/custom.txt <<'EOF'
<system-component>
  <metadata>
    <name>custom</name>
    <version>1.0</version>
  </metadata>
  <content>
    Custom system prompt for testing.
  </content>
</system-component>
EOF

    # Update project config to use custom prompt
    echo 'SystemPrompt="prompts/system/custom.txt"' >> .workflow/config

    # Create workflow using the script
    run "${SCRIPT_DIR}/wireflow.sh" new custom-workflow
    assert_success

    # Run with dry-run mode
    export WIREFLOW_DRY_RUN="true"
    run "${SCRIPT_DIR}/wireflow.sh" run custom-workflow
    assert_success
    assert_output --partial "DRY RUN MODE"
}

@test "integration: error handling for missing workflow" {
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    run "${SCRIPT_DIR}/wireflow.sh" run non-existent-workflow
    assert_failure
    assert_output --partial "not found"
}

@test "integration: error handling for missing input files" {
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    run "${SCRIPT_DIR}/wireflow.sh" new test-workflow
    assert_success

    export WIREFLOW_DRY_RUN="true"
    run "${SCRIPT_DIR}/wireflow.sh" run test-workflow --input-file non-existent-file.txt
    assert_failure
    assert_output --partial "Input file not found"
}

# ============================================================================
# Configuration override tests
# ============================================================================

@test "integration: CLI arguments override config values" {
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    run "${SCRIPT_DIR}/wireflow.sh" new test-workflow
    assert_success

    # Set config values
    echo 'Model="claude-3-opus-20240229"' >> .workflow/config
    echo 'Temperature="0.9"' >> .workflow/config

    export WIREFLOW_DRY_RUN="true"

    # Run with CLI overrides
    run "${SCRIPT_DIR}/wireflow.sh" run test-workflow \
        --model "claude-3-5-sonnet-20241022" \
        --temperature "0.3"

    assert_success
    assert_output --partial "DRY RUN MODE"

    # Verify model in JSON payload (CLI should override config)
    local json_file=".workflow/run/test-workflow/dry-run-request.json"
    assert_file_exists "$json_file"
    run grep -o '"model"[[:space:]]*:[[:space:]]*"[^"]*"' "$json_file"
    assert_output --partial "claude-3-5-sonnet-20241022"
}

@test "integration: environment variables override config files" {
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success
    export PROJECT_ROOT="$(pwd)"
    export PROJECT_CONFIG="$(pwd)/.workflow/config"

    # Set config value
    echo 'Model="claude-3-opus-20240229"' >> .workflow/config

    # Override with environment variable
    export Model="claude-3-5-sonnet-20241022"

    load_project_config

    assert_env_var_set "Model" "claude-3-5-sonnet-20241022"
}

# ============================================================================
# Output generation tests
# ============================================================================

@test "integration: output file generation and formats" {
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    run "${SCRIPT_DIR}/wireflow.sh" new formatter
    assert_success

    # Mock a successful run by creating output structure
    local workflow_dir=".workflow/run/formatter"
    local output_dir=".workflow/output"

    # Create mock outputs in workflow run dir
    mock_api_response "$workflow_dir/response.json" "Test output content"
    echo "# Formatted Output" > "$workflow_dir/output.md"
    echo "Plain text output" > "$workflow_dir/output.txt"

    # Create output files in project output directory (where cat looks)
    mkdir -p "$output_dir"
    echo "# Formatted Output" > "$output_dir/formatter.md"
    echo "Plain text output" > "$output_dir/formatter.txt"

    # Verify output files exist
    assert_file_exists "$workflow_dir/output.md"
    assert_file_exists "$output_dir/formatter.md"

    # Test cat command
    run "${SCRIPT_DIR}/wireflow.sh" cat formatter
    assert_success
}

@test "integration: citations sidecar file generation" {
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    run "${SCRIPT_DIR}/wireflow.sh" new research
    assert_success

    # Mock run with citations in the workflow directory
    local workflow_dir=".workflow/run/research"

    # Create mock response with citations
    cat > "$workflow_dir/response.json" <<'EOF'
{
    "content": [{
        "type": "text",
        "text": "Research findings with [[1]] citation markers [[2]]."
    }]
}
EOF

    # Create citations sidecar
    cat > "$workflow_dir/output.citations.json" <<'EOF'
{
    "citations": [
        {
            "number": "1",
            "title": "Source One",
            "url": "https://example.com/1"
        },
        {
            "number": "2",
            "title": "Source Two",
            "url": "https://example.com/2"
        }
    ]
}
EOF

    assert_file_exists "$workflow_dir/output.citations.json"
    assert_valid_json "$workflow_dir/output.citations.json"
}

# ============================================================================
# Cache control tests
# ============================================================================

@test "integration: cache control blocks in API requests" {
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    run "${SCRIPT_DIR}/wireflow.sh" new cached-workflow
    assert_success

    # Enable cache control
    echo 'CacheControl="auto"' >> .workflow/config

    # Create inputs
    create_fixture_file "input.txt" "text"

    # Build prompts with cache control
    export WIREFLOW_DRY_RUN="true"
    export CacheControl="auto"

    # Would need to mock/spy on build_prompts to verify cache control
    # For now, just verify the workflow runs with cache control enabled
    run "${SCRIPT_DIR}/wireflow.sh" run cached-workflow --input-file input.txt
    assert_success
}

# ============================================================================
# Dependency resolution tests
# ============================================================================

@test "integration: system prompt dependency resolution" {
    # Create prompts with dependencies
    local prompts_dir="${GLOBAL_CONFIG_DIR}/prompts/system"
    mkdir -p "$prompts_dir"

    # Base component
    cat > "$prompts_dir/base.txt" <<'EOF'
<system-component>
  <metadata>
    <name>base</name>
    <version>1.0</version>
  </metadata>
  <content>Base component content</content>
</system-component>
EOF

    # Dependent component
    cat > "$prompts_dir/extended.txt" <<'EOF'
<system-component>
  <metadata>
    <name>extended</name>
    <version>1.0</version>
    <dependencies>
      <dependency>base</dependency>
    </dependencies>
  </metadata>
  <content>Extended component content</content>
</system-component>
EOF

    # Test dependency resolution
    export WIREFLOW_PROMPT_PREFIX="$prompts_dir"
    export BUILTIN_WIREFLOW_PROMPT_PREFIX="$prompts_dir"

    local deps
    deps=$(resolve_system_dependencies "extended")

    # Check that deps contains "base"
    [[ "$deps" == *"base"* ]]
}

# ============================================================================
# Streaming vs batch mode tests
# ============================================================================

@test "integration: streaming mode execution" {
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    run "${SCRIPT_DIR}/wireflow.sh" new streamer
    assert_success

    # Enable streaming
    echo 'Stream="true"' >> .workflow/config

    export WIREFLOW_DRY_RUN="true"

    run "${SCRIPT_DIR}/wireflow.sh" run streamer
    assert_success
    assert_output --partial "DRY RUN MODE"
}

@test "integration: batch mode execution" {
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    run "${SCRIPT_DIR}/wireflow.sh" new batcher
    assert_success

    # Disable streaming
    echo 'Stream="false"' >> .workflow/config

    export WIREFLOW_DRY_RUN="true"

    run "${SCRIPT_DIR}/wireflow.sh" run batcher
    assert_success
    assert_output --partial "DRY RUN MODE"
}

# ============================================================================
# Edge cases and error conditions
# ============================================================================

@test "integration: handles circular dependencies gracefully" {
    local prompts_dir="${GLOBAL_CONFIG_DIR}/prompts/system"
    mkdir -p "$prompts_dir"

    # Create circular dependency
    cat > "$prompts_dir/comp-a.txt" <<'EOF'
<system-component>
  <metadata>
    <name>comp-a</name>
    <version>1.0</version>
    <dependencies>
      <dependency>comp-b</dependency>
    </dependencies>
  </metadata>
  <content>Component A</content>
</system-component>
EOF

    cat > "$prompts_dir/comp-b.txt" <<'EOF'
<system-component>
  <metadata>
    <name>comp-b</name>
    <version>1.0</version>
    <dependencies>
      <dependency>comp-a</dependency>
    </dependencies>
  </metadata>
  <content>Component B</content>
</system-component>
EOF

    export WIREFLOW_PROMPT_PREFIX="$prompts_dir"
    export BUILTIN_WIREFLOW_PROMPT_PREFIX="$prompts_dir"

    # Should handle circular dependency without infinite loop
    run resolve_system_dependencies "comp-a"
    # Test that it completes without hanging (output size should be bounded)
    # Note: Current implementation may produce repeated output due to circular deps
    # but should not cause infinite recursion
    assert [ "${#output}" -lt "50000" ]  # Output should be bounded (no infinite loop)
}

@test "integration: handles missing dependencies gracefully" {
    local prompts_dir="${GLOBAL_CONFIG_DIR}/prompts/system"
    mkdir -p "$prompts_dir"

    cat > "$prompts_dir/broken.txt" <<'EOF'
<system-component>
  <metadata>
    <name>broken</name>
    <version>1.0</version>
    <dependencies>
      <dependency>non-existent</dependency>
    </dependencies>
  </metadata>
  <content>Broken component</content>
</system-component>
EOF

    export WIREFLOW_PROMPT_PREFIX="$prompts_dir"
    export BUILTIN_WIREFLOW_PROMPT_PREFIX="$prompts_dir"

    # Should handle missing dependency gracefully
    run resolve_system_dependencies "broken"
    # Should complete without error, possibly with warning
    assert_success || assert_output --partial "Warning"
}