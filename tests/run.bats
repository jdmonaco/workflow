#!/usr/bin/env bats

load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load
load test_helper/common

setup() {
    setup_test_env

    # Initialize a project for all tests
    bash "$WORKFLOW_SCRIPT" init . > /dev/null 2>&1

    # Create a test workflow
    bash "$WORKFLOW_SCRIPT" new test-workflow > /dev/null 2>&1

    # Write a simple task
    echo "Analyze the test data." > .workflow/test-workflow/task.txt

    # Mock curl by default for most tests
    mock_curl_success
}

teardown() {
    unmock_curl
    cleanup_test_env
}

# =============================================================================
# Basic Execution Tests
# =============================================================================

@test "run: executes workflow and creates output file" {
    run bash "$WORKFLOW_SCRIPT" run test-workflow

    assert_success
    assert_file_exists ".workflow/test-workflow/output.md"
}

@test "run: creates context file" {
    run bash "$WORKFLOW_SCRIPT" run test-workflow

    assert_success
    # JSON files are now created instead of XML
    assert_file_exists ".workflow/test-workflow/user-blocks.json"
}

@test "run: creates hardlink in output directory" {
    bash "$WORKFLOW_SCRIPT" run test-workflow

    assert_file_exists ".workflow/output/test-workflow.md"

    # Verify hardlink (same inode on macOS)
    local output_inode=$(stat -f "%i" ".workflow/test-workflow/output.md")
    local link_inode=$(stat -f "%i" ".workflow/output/test-workflow.md")

    assert_equal "$output_inode" "$link_inode"
}

@test "run: output file contains API response" {
    bash "$WORKFLOW_SCRIPT" run test-workflow

    assert_file_exists ".workflow/test-workflow/output.md"

    # Check content from mocked response
    run cat .workflow/test-workflow/output.md
    assert_output "This is a test response from the API."
}

@test "run: backs up previous output with timestamp" {
    # Run once
    bash "$WORKFLOW_SCRIPT" run test-workflow

    # Modify output to differentiate
    echo "MODIFIED" >> .workflow/test-workflow/output.md

    # Run again
    bash "$WORKFLOW_SCRIPT" run test-workflow

    # Check backup was created (filename has timestamp pattern)
    local backup_count=$(count_files ".workflow/test-workflow/output-*.md")
    [[ "$backup_count" -ge 1 ]]
}

@test "run: fails when workflow doesn't exist" {
    run bash "$WORKFLOW_SCRIPT" run nonexistent-workflow

    assert_failure
    assert_output --partial "not found"
}

@test "run: fails when outside workflow project" {
    cd "$TEST_TEMP_DIR"

    run bash "$WORKFLOW_SCRIPT" run test-workflow

    assert_failure
    assert_output --partial "Not in workflow project"
}

@test "run: works from subdirectory within project" {
    mkdir subdir
    cd subdir

    run bash "$WORKFLOW_SCRIPT" run test-workflow

    assert_success
    assert_file_exists "../.workflow/test-workflow/output.md"
}

# =============================================================================
# Context Aggregation Tests
# =============================================================================

@test "run: aggregates context from CONTEXT_PATTERN (relative to project root)" {
    # Create reference files in project root
    mkdir -p References
    echo "Reference 1 content" > References/ref1.md
    echo "Reference 2 content" > References/ref2.md

    # Configure workflow to use pattern (path relative to project root)
    echo 'CONTEXT_PATTERN="References/*.md"' >> .workflow/test-workflow/config

    run bash "$WORKFLOW_SCRIPT" run test-workflow

    # Verify command succeeded - content is now in JSON blocks
    assert_success
}

@test "run: CONTEXT_PATTERN works from subdirectory" {
    # Create reference files
    mkdir -p References
    echo "Reference content" > References/ref.md

    # Configure pattern relative to project root
    echo 'CONTEXT_PATTERN="References/*.md"' >> .workflow/test-workflow/config

    # Run from subdirectory
    mkdir subdir
    cd subdir

    run bash "$WORKFLOW_SCRIPT" run test-workflow

    # Should still find References/*.md relative to project root
    assert_success
}

@test "run: aggregates context from CONTEXT_FILES (relative to project root)" {
    # Create explicit files
    mkdir -p data
    echo "Data file 1" > data/data1.md
    echo "Data file 2" > data/data2.md

    # Configure workflow with explicit files (paths relative to project root)
    cat >> .workflow/test-workflow/config <<'EOF'
CONTEXT_FILES=(
    "data/data1.md"
    "data/data2.md"
)
EOF

    run bash "$WORKFLOW_SCRIPT" run test-workflow

    assert_success
}

@test "run: aggregates context from DEPENDS_ON" {
    # Create first workflow and run it
    bash "$WORKFLOW_SCRIPT" new workflow-01 > /dev/null 2>&1
    echo "First workflow task" > .workflow/workflow-01/task.txt
    bash "$WORKFLOW_SCRIPT" run workflow-01

    # Create second workflow that depends on first
    bash "$WORKFLOW_SCRIPT" new workflow-02 > /dev/null 2>&1
    echo "Second workflow task" > .workflow/workflow-02/task.txt
    echo 'DEPENDS_ON=("workflow-01")' >> .workflow/workflow-02/config

    run bash "$WORKFLOW_SCRIPT" run workflow-02

    # Check that dependency processing succeeded
    assert_success
}

@test "run: CLI --context-file is relative to PWD" {
    # Create file in project root
    echo "Root level file" > root-file.md

    # Run from project root with relative path
    run bash "$WORKFLOW_SCRIPT" run test-workflow --context-file root-file.md

    # Should find the file
    assert_success
}

@test "run: CLI --context-file from subdirectory is relative to subdirectory" {
    # Create file in subdirectory
    mkdir subdir
    echo "Subdir file content" > subdir/local.md

    # Run from subdirectory
    cd subdir

    run bash "$WORKFLOW_SCRIPT" run test-workflow --context-file local.md

    # Should find subdir/local.md
    assert_success
}

@test "run: CLI --context-pattern is relative to PWD" {
    # Create files in subdirectory
    mkdir subdir
    echo "File 1" > subdir/file1.md
    echo "File 2" > subdir/file2.md

    # Run from subdirectory with pattern
    cd subdir

    run bash "$WORKFLOW_SCRIPT" run test-workflow --context-pattern "*.md"

    # Should find files in subdir
    assert_success
}

@test "run: combines multiple context sources" {
    # Setup first workflow as dependency
    bash "$WORKFLOW_SCRIPT" new workflow-dep > /dev/null 2>&1
    echo "Dependency task" > .workflow/workflow-dep/task.txt
    bash "$WORKFLOW_SCRIPT" run workflow-dep

    # Create pattern files
    mkdir References
    echo "Reference content" > References/ref.md

    # Create explicit files
    mkdir data
    echo "Data content" > data/data.md

    # Create CLI file
    echo "CLI content" > cli-file.md

    # Configure workflow with multiple sources
    cat >> .workflow/test-workflow/config <<'EOF'
DEPENDS_ON=("workflow-dep")
CONTEXT_PATTERN="References/*.md"
CONTEXT_FILES=("data/data.md")
EOF

    run bash "$WORKFLOW_SCRIPT" run test-workflow --context-file cli-file.md

    # All sources should be processed successfully
    assert_success
}

# =============================================================================
# Dry-Run and Streaming Mode Tests
# =============================================================================

@test "run: count-tokens mode shows token estimation without API call" {
    # Mock curl to handle count_tokens endpoint but fail on Messages endpoint
    curl() {
        local url=""
        while [[ $# -gt 0 ]]; do
            if [[ "$1" =~ ^https:// ]]; then
                url="$1"
            fi
            shift
        done

        # Allow count_tokens API, block Messages API
        if [[ "$url" == *"/count_tokens" ]]; then
            echo '{"input_tokens": 5000}'
        elif [[ "$url" == *"/messages" ]]; then
            echo "ERROR: Messages API should not be called in count-tokens mode" >&2
            return 1
        fi
    }
    export -f curl

    run bash "$WORKFLOW_SCRIPT" run test-workflow --count-tokens

    assert_success
    assert_output --partial "Estimated system tokens"
    assert_output --partial "Estimated task tokens"
    assert_output --partial "Estimated total input tokens (heuristic)"
    assert_output --partial "Exact total input tokens (from API)"

    # No output file should be created
    [[ ! -f ".workflow/test-workflow/output.md" ]]
}

@test "run: dry-run mode saves prompts to files" {
    run bash "$WORKFLOW_SCRIPT" run test-workflow --dry-run

    assert_success
    assert_output --partial "Dry-run mode: Prompts and JSON payload saved for inspection"
    assert_output --partial "System prompt (XML):"
    assert_output --partial "User prompt (XML):"
    assert_output --partial "API request (JSON):"
    assert_output --partial "Content blocks (JSON):"
    assert_output --partial "dry-run-system.txt"
    assert_output --partial "dry-run-user.txt"
    assert_output --partial "dry-run-request.json"
    assert_output --partial "dry-run-blocks.json"

    # Verify files were created
    assert_file_exists ".workflow/test-workflow/dry-run-system.txt"
    assert_file_exists ".workflow/test-workflow/dry-run-user.txt"
    assert_file_exists ".workflow/test-workflow/dry-run-request.json"
    assert_file_exists ".workflow/test-workflow/dry-run-blocks.json"

    # No output file should be created
    [[ ! -f ".workflow/test-workflow/output.md" ]]
}

@test "run: streaming mode processes SSE responses" {
    mock_curl_streaming

    run bash "$WORKFLOW_SCRIPT" run test-workflow --stream

    assert_success
    assert_file_exists ".workflow/test-workflow/output.md"

    run cat .workflow/test-workflow/output.md
    assert_output "Test streaming response"
}

# =============================================================================
# Output Format Tests
# =============================================================================

@test "run: handles JSON output format from config" {
    echo 'OUTPUT_FORMAT="json"' >> .workflow/test-workflow/config

    bash "$WORKFLOW_SCRIPT" run test-workflow

    assert_file_exists ".workflow/test-workflow/output.json"
    assert_file_exists ".workflow/output/test-workflow.json"

    # Hardlink should also use .json extension
    local output_inode=$(stat -f "%i" ".workflow/test-workflow/output.json")
    local link_inode=$(stat -f "%i" ".workflow/output/test-workflow.json")
    assert_equal "$output_inode" "$link_inode"
}

@test "run: handles txt output format from CLI flag" {
    bash "$WORKFLOW_SCRIPT" run test-workflow --output-format txt

    assert_file_exists ".workflow/test-workflow/output.txt"
    assert_file_exists ".workflow/output/test-workflow.txt"
}

@test "run: new workflow creates task.txt with output-format skeleton" {
    # Create a fresh workflow to verify skeleton is created by new_workflow()
    bash "$WORKFLOW_SCRIPT" new skeleton-test > /dev/null 2>&1

    # Verify task.txt was created with all skeleton sections
    run cat .workflow/skeleton-test/task.txt
    assert_output --partial "<description>"
    assert_output --partial "<guidance>"
    assert_output --partial "<instructions>"
    assert_output --partial "<output-format>"
    assert_output --partial "</output-format>"
}

# =============================================================================
# Configuration Override Tests
# =============================================================================

@test "run: CLI --model overrides config model" {
    # Set model in workflow config
    echo 'MODEL="claude-sonnet-4"' >> .workflow/test-workflow/config

    # Dry-run to see what would be sent (avoid actual API call)
    run bash "$WORKFLOW_SCRIPT" run test-workflow --model claude-opus-4 --count-tokens

    assert_success
    # Can't easily verify model in dry-run, but command should succeed
}

@test "run: CLI --max-tokens overrides config" {
    echo 'MAX_TOKENS=2000' >> .workflow/test-workflow/config

    run bash "$WORKFLOW_SCRIPT" run test-workflow --max-tokens 8000 --count-tokens

    assert_success
}

@test "run: CLI --system-prompts overrides config" {
    # Add NeuroAI prompt
    echo "NeuroAI system prompt" > "$WIREFLOW_PROMPT_PREFIX/NeuroAI.txt"

    run bash "$WORKFLOW_SCRIPT" run test-workflow --system-prompts "base,NeuroAI" --count-tokens

    assert_success
    # System prompt should be built with both
    assert_file_exists ".workflow/prompts/system.txt"
    run cat .workflow/prompts/system.txt
    assert_output --partial "base system prompt"
    assert_output --partial "NeuroAI system prompt"
}

# =============================================================================
# Error Handling Tests
# =============================================================================

@test "run: fails when ANTHROPIC_API_KEY not set" {
    unset ANTHROPIC_API_KEY

    run bash "$WORKFLOW_SCRIPT" run test-workflow

    assert_failure
    assert_output --partial "ANTHROPIC_API_KEY"
}

@test "run: fails when WIREFLOW_PROMPT_PREFIX not set" {
    unset WIREFLOW_PROMPT_PREFIX

    run bash "$WORKFLOW_SCRIPT" run test-workflow

    assert_failure
    assert_output --partial "WIREFLOW_PROMPT_PREFIX"
}

@test "run: fails when system prompt file missing" {
    # Configure to use non-existent prompt
    echo 'SYSTEM_PROMPTS=(base Nonexistent)' >> .workflow/test-workflow/config

    run bash "$WORKFLOW_SCRIPT" run test-workflow

    assert_failure
    assert_output --partial "System prompt file not found"
}

@test "run: fails gracefully on API error" {
    mock_curl_error

    run bash "$WORKFLOW_SCRIPT" run test-workflow

    assert_failure
    assert_output --partial "API Error"
}

@test "run: fails when dependency output not found" {
    echo 'DEPENDS_ON=("nonexistent-workflow")' >> .workflow/test-workflow/config

    run bash "$WORKFLOW_SCRIPT" run test-workflow

    assert_failure
    assert_output --partial "Dependency output not found"
}

@test "run: fails when context file not found" {
    echo 'CONTEXT_FILES=("nonexistent.md")' >> .workflow/test-workflow/config

    run bash "$WORKFLOW_SCRIPT" run test-workflow

    assert_failure
    assert_output --partial "Context file not found"
}

# =============================================================================
# System Prompt Building Tests
# =============================================================================

@test "run: builds system prompt from configured prompts" {
    bash "$WORKFLOW_SCRIPT" run test-workflow --count-tokens > /dev/null

    assert_file_exists ".workflow/prompts/system.txt"

    run cat .workflow/prompts/system.txt
    assert_output --partial "base system prompt"
}

@test "run: rebuilds system prompt on every run" {
    # Run once
    bash "$WORKFLOW_SCRIPT" run test-workflow --count-tokens > /dev/null

    # Modify system prompt file
    echo "MODIFIED BASE PROMPT" > "$WIREFLOW_PROMPT_PREFIX/base.txt"

    # Run again - should rebuild
    bash "$WORKFLOW_SCRIPT" run test-workflow --count-tokens > /dev/null

    run cat .workflow/prompts/system.txt
    assert_output --partial "MODIFIED BASE PROMPT"
    assert_output --partial "<system-prompts>"
    assert_output --partial "</system-prompts>"
}

@test "run: appends project.txt to system prompt when non-empty" {
    # Add content to project.txt
    cat > .workflow/project.txt <<'EOF'
This is a test project for neural analysis.
Use scientific terminology.
EOF

    run bash "$WORKFLOW_SCRIPT" run test-workflow --count-tokens

    # Verify execution succeeds
    assert_success
}

# =============================================================================
# Workflow Chaining Tests
# =============================================================================

@test "run: workflow chain with dependencies executes in order" {
    # Create workflow chain: 00 -> 01 -> 02
    bash "$WORKFLOW_SCRIPT" new 00-first > /dev/null 2>&1
    echo "First task" > .workflow/00-first/task.txt

    bash "$WORKFLOW_SCRIPT" new 01-second > /dev/null 2>&1
    echo "Second task" > .workflow/01-second/task.txt
    echo 'DEPENDS_ON=("00-first")' >> .workflow/01-second/config

    bash "$WORKFLOW_SCRIPT" new 02-third > /dev/null 2>&1
    echo "Third task" > .workflow/02-third/task.txt
    echo 'DEPENDS_ON=("00-first" "01-second")' >> .workflow/02-third/config

    # Run chain
    bash "$WORKFLOW_SCRIPT" run 00-first
    bash "$WORKFLOW_SCRIPT" run 01-second
    run bash "$WORKFLOW_SCRIPT" run 02-third

    # Third workflow should process both dependencies successfully
    assert_success
}

@test "run: handles cross-format dependencies" {
    # Create JSON workflow
    bash "$WORKFLOW_SCRIPT" new json-workflow > /dev/null 2>&1
    echo "JSON task" > .workflow/json-workflow/task.txt
    echo 'OUTPUT_FORMAT="json"' >> .workflow/json-workflow/config

    # Create markdown workflow that depends on JSON one
    bash "$WORKFLOW_SCRIPT" new md-workflow > /dev/null 2>&1
    echo "Markdown task" > .workflow/md-workflow/task.txt
    echo 'DEPENDS_ON=("json-workflow")' >> .workflow/md-workflow/config

    # Run both
    bash "$WORKFLOW_SCRIPT" run json-workflow
    run bash "$WORKFLOW_SCRIPT" run md-workflow

    # Verify both outputs exist
    assert_success
    assert_file_exists ".workflow/json-workflow/output.json"
    assert_file_exists ".workflow/md-workflow/output.md"
}

# =============================================================================
# Additional Tests
# =============================================================================

@test "run: handles empty context gracefully" {
    # Don't configure any context sources
    run bash "$WORKFLOW_SCRIPT" run test-workflow

    assert_success
    assert_output --partial "No input documents or context provided"
}

@test "run: CONTEXT_PATTERN with brace expansion" {
    # Create multiple topic directories
    mkdir -p References/Topic1
    mkdir -p References/Topic2
    echo "Topic 1 content" > References/Topic1/doc.md
    echo "Topic 2 content" > References/Topic2/doc.md

    # Use brace expansion in pattern (needs to be in config file for proper expansion)
    cat >> .workflow/test-workflow/config <<'EOF'
CONTEXT_PATTERN="References/{Topic1,Topic2}/*.md"
EOF

    run bash "$WORKFLOW_SCRIPT" run test-workflow

    # Verify command succeeded
    assert_success
}

# =============================================================================
# INPUT Document Aggregation Tests
# =============================================================================

@test "run: separates INPUT_* from CONTEXT_*" {
    # Create input documents
    mkdir -p Data
    echo "Primary data" > Data/data.csv

    # Create context files
    mkdir -p References
    echo "Reference material" > References/ref.md

    # Configure both INPUT and CONTEXT
    cat >> .workflow/test-workflow/config <<'EOF'
INPUT_PATTERN="Data/*.csv"
CONTEXT_PATTERN="References/*.md"
EOF

    # Mock curl for API
    curl() {
        echo '{"input_tokens": 1000}'
    }
    export -f curl

    run bash "$WORKFLOW_SCRIPT" run test-workflow --count-tokens

    # Verify command succeeded - content is in JSON blocks
    assert_success
}

@test "run: INPUT_PATTERN works from subdirectory (project-relative)" {
    # Create input files
    mkdir -p Data
    echo "Input data" > Data/data.csv

    # Configure pattern relative to project root
    echo 'INPUT_PATTERN="Data/*.csv"' >> .workflow/test-workflow/config

    # Run from subdirectory
    mkdir subdir
    cd subdir

    run bash "$WORKFLOW_SCRIPT" run test-workflow

    # Should still find Data/*.csv relative to project root
    assert_success
}

@test "run: CLI --input-file works (PWD-relative)" {
    # Create input file in current directory
    echo "CLI input data" > input-data.txt

    # Mock curl for API
    curl() {
        echo '{"input_tokens": 1000}'
    }
    export -f curl

    run bash "$WORKFLOW_SCRIPT" run test-workflow --input-file input-data.txt --count-tokens

    # Verify command succeeded
    assert_success
}

@test "run: CLI --input-pattern works" {
    # Create input files in current directory
    mkdir -p TestData
    echo "Pattern input 1" > TestData/test1.dat
    echo "Pattern input 2" > TestData/test2.dat

    # Mock curl for API
    curl() {
        echo '{"input_tokens": 1000}'
    }
    export -f curl

    run bash "$WORKFLOW_SCRIPT" run test-workflow --input-pattern "TestData/*.dat" --count-tokens

    # Verify command succeeded
    assert_success
}

@test "run: creates input.txt file" {
    # Simple test to verify JSON files are created
    run bash "$WORKFLOW_SCRIPT" run test-workflow

    # JSON files should exist
    assert_file_exists ".workflow/test-workflow/user-blocks.json"
    assert_file_exists ".workflow/test-workflow/system-blocks.json"
}

# =============================================================================
# Vision API Image Support Tests
# =============================================================================

@test "run: detects image file types correctly" {
    # Test file type detection for images
    UTILS_LIB="$(cd "$(dirname "$BATS_TEST_DIRNAME")"; pwd)/lib/utils.sh"
    source "$UTILS_LIB"

    # Image files should be detected
    result=$(detect_file_type "test.jpg")
    [[ "$result" == "image" ]]

    result=$(detect_file_type "test.png")
    [[ "$result" == "image" ]]

    result=$(detect_file_type "test.gif")
    [[ "$result" == "image" ]]

    result=$(detect_file_type "test.webp")
    [[ "$result" == "image" ]]

    # Non-image files should not be detected as images
    result=$(detect_file_type "test.txt")
    [[ "$result" == "text" ]]

    result=$(detect_file_type "test.md")
    [[ "$result" == "text" ]]
}

@test "run: maps image extensions to media types" {
    # Test media type mapping
    UTILS_LIB="$(cd "$(dirname "$BATS_TEST_DIRNAME")"; pwd)/lib/utils.sh"
    source "$UTILS_LIB"

    result=$(get_image_media_type "test.jpg")
    [[ "$result" == "image/jpeg" ]]

    result=$(get_image_media_type "test.jpeg")
    [[ "$result" == "image/jpeg" ]]

    result=$(get_image_media_type "test.png")
    [[ "$result" == "image/png" ]]

    result=$(get_image_media_type "test.gif")
    [[ "$result" == "image/gif" ]]

    result=$(get_image_media_type "test.webp")
    [[ "$result" == "image/webp" ]]
}
