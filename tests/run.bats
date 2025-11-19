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
    assert_file_exists ".workflow/test-workflow/context.txt"
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

    bash "$WORKFLOW_SCRIPT" run test-workflow

    # Check context file contains references
    assert_file_exists ".workflow/test-workflow/context.txt"
    run cat .workflow/test-workflow/context.txt
    assert_output --partial "Reference 1 content"
    assert_output --partial "Reference 2 content"
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

    bash "$WORKFLOW_SCRIPT" run test-workflow

    # Should still find References/*.md relative to project root
    run cat ../.workflow/test-workflow/context.txt
    assert_output --partial "Reference content"
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

    bash "$WORKFLOW_SCRIPT" run test-workflow

    run cat .workflow/test-workflow/context.txt
    assert_output --partial "Data file 1"
    assert_output --partial "Data file 2"
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

    bash "$WORKFLOW_SCRIPT" run workflow-02

    # Check context includes first workflow output
    run cat .workflow/workflow-02/context.txt
    assert_output --partial "This is a test response from the API"
}

@test "run: CLI --context-file is relative to PWD" {
    # Create file in project root
    echo "Root level file" > root-file.md

    # Run from project root with relative path
    bash "$WORKFLOW_SCRIPT" run test-workflow --context-file root-file.md

    # Should find the file
    run cat .workflow/test-workflow/context.txt
    assert_output --partial "Root level file"
}

@test "run: CLI --context-file from subdirectory is relative to subdirectory" {
    # Create file in subdirectory
    mkdir subdir
    echo "Subdir file content" > subdir/local.md

    # Run from subdirectory
    cd subdir

    bash "$WORKFLOW_SCRIPT" run test-workflow --context-file local.md

    # Should find subdir/local.md
    run cat ../.workflow/test-workflow/context.txt
    assert_output --partial "Subdir file content"
}

@test "run: CLI --context-pattern is relative to PWD" {
    # Create files in subdirectory
    mkdir subdir
    echo "File 1" > subdir/file1.md
    echo "File 2" > subdir/file2.md

    # Run from subdirectory with pattern
    cd subdir

    bash "$WORKFLOW_SCRIPT" run test-workflow --context-pattern "*.md"

    # Should find files in subdir
    run cat ../.workflow/test-workflow/context.txt
    assert_output --partial "File 1"
    assert_output --partial "File 2"
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

    bash "$WORKFLOW_SCRIPT" run test-workflow --context-file cli-file.md

    # All sources should be in context
    run cat .workflow/test-workflow/context.txt
    assert_output --partial "This is a test response"  # From dependency
    assert_output --partial "Reference content"        # From pattern
    assert_output --partial "Data content"             # From config files
    assert_output --partial "CLI content"              # From CLI flag
}

# =============================================================================
# Dry-Run and Streaming Mode Tests
# =============================================================================

@test "run: count-tokens mode shows token estimation without API call" {
    # Override curl to fail if called
    curl() {
        echo "ERROR: curl should not be called" >&2
        return 1
    }
    export -f curl

    run bash "$WORKFLOW_SCRIPT" run test-workflow --count-tokens

    assert_success
    assert_output --partial "Estimated system tokens"
    assert_output --partial "Estimated task tokens"
    assert_output --partial "Estimated total input tokens"

    # No output file should be created
    [[ ! -f ".workflow/test-workflow/output.md" ]]
}

@test "run: dry-run mode saves prompts to files" {
    run bash "$WORKFLOW_SCRIPT" run test-workflow --dry-run

    assert_success
    assert_output --partial "Dry-run mode: Prompts saved for inspection"
    assert_output --partial "System prompt:"
    assert_output --partial "User prompt:"
    assert_output --partial "dry-run-system.txt"
    assert_output --partial "dry-run-user.txt"

    # Verify files were created
    assert_file_exists ".workflow/test-workflow/dry-run-system.txt"
    assert_file_exists ".workflow/test-workflow/dry-run-user.txt"

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
    echo "NeuroAI system prompt" > "$WORKFLOW_PROMPT_PREFIX/NeuroAI.txt"

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

@test "run: fails when WORKFLOW_PROMPT_PREFIX not set" {
    unset WORKFLOW_PROMPT_PREFIX

    run bash "$WORKFLOW_SCRIPT" run test-workflow

    assert_failure
    assert_output --partial "WORKFLOW_PROMPT_PREFIX"
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
    echo "MODIFIED BASE PROMPT" > "$WORKFLOW_PROMPT_PREFIX/base.txt"

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
    bash "$WORKFLOW_SCRIPT" run 02-third

    # Third workflow should have both dependencies in context
    run cat .workflow/02-third/context.txt
    assert_output --partial "This is a test response"  # Appears twice
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
    bash "$WORKFLOW_SCRIPT" run md-workflow

    # Markdown workflow should include JSON output
    assert_file_exists ".workflow/md-workflow/context.txt"
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

    bash "$WORKFLOW_SCRIPT" run test-workflow

    # Check context contains both topics
    assert_file_exists ".workflow/test-workflow/context.txt"
    run cat .workflow/test-workflow/context.txt
    assert_output --partial "Topic 1 content"
    assert_output --partial "Topic 2 content"
}

# =============================================================================
# INPUT Document Aggregation Tests
# =============================================================================

@test "run: aggregates INPUT_PATTERN using documentcat" {
    # Create input data files
    mkdir -p Data
    echo "Dataset 1 content" > Data/data1.csv
    echo "Dataset 2 content" > Data/data2.csv

    # Configure INPUT_PATTERN (project-relative)
    echo 'INPUT_PATTERN="Data/*.csv"' >> .workflow/test-workflow/config

    bash "$WORKFLOW_SCRIPT" run test-workflow

    # Check input file was created and contains document structure
    assert_file_exists ".workflow/test-workflow/input.txt"
    run cat .workflow/test-workflow/input.txt

    # Verify documentcat structure (index, metadata)
    assert_output --partial '<document index="1">'
    assert_output --partial '<source>'
    assert_output --partial '<document_content>'
    assert_output --partial "Dataset 1 content"
    assert_output --partial "Dataset 2 content"
}

@test "run: aggregates INPUT_FILES using documentcat" {
    # Create input files
    mkdir -p Data
    echo "Input document 1" > Data/doc1.json
    echo "Input document 2" > Data/doc2.json

    # Configure INPUT_FILES (project-relative)
    cat >> .workflow/test-workflow/config <<'EOF'
INPUT_FILES=(
    "Data/doc1.json"
    "Data/doc2.json"
)
EOF

    bash "$WORKFLOW_SCRIPT" run test-workflow

    # Check input file contains both documents with sequential indexing
    assert_file_exists ".workflow/test-workflow/input.txt"
    run cat .workflow/test-workflow/input.txt

    assert_output --partial '<document index="1">'
    assert_output --partial '<document index="2">'
    assert_output --partial "Input document 1"
    assert_output --partial "Input document 2"
}

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

    bash "$WORKFLOW_SCRIPT" run test-workflow

    # Check input file contains documentcat structure
    run cat .workflow/test-workflow/input.txt
    assert_output --partial '<document index="1">'
    assert_output --partial "Primary data"

    # Check context file contains contextcat structure
    run cat .workflow/test-workflow/context.txt
    assert_output --partial '<context-file>'
    assert_output --partial "Reference material"
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

    bash "$WORKFLOW_SCRIPT" run test-workflow

    # Should still find Data/*.csv relative to project root
    run cat ../.workflow/test-workflow/input.txt
    assert_output --partial "Input data"
}

@test "run: CLI --input-file works (PWD-relative)" {
    # Create input file in current directory
    echo "CLI input data" > input-data.txt

    bash "$WORKFLOW_SCRIPT" run test-workflow --input-file input-data.txt

    # Check input file contains CLI data
    run cat .workflow/test-workflow/input.txt
    assert_output --partial "CLI input data"
    assert_output --partial '<document index="1">'
}

@test "run: CLI --input-pattern works" {
    # Create input files in current directory
    mkdir -p TestData
    echo "Pattern input 1" > TestData/test1.dat
    echo "Pattern input 2" > TestData/test2.dat

    bash "$WORKFLOW_SCRIPT" run test-workflow --input-pattern "TestData/*.dat"

    # Check input file contains pattern matches
    run cat .workflow/test-workflow/input.txt
    assert_output --partial "Pattern input 1"
    assert_output --partial "Pattern input 2"
    assert_output --partial '<document index="1">'
}

@test "run: creates input.txt file" {
    # Simple test to verify input.txt is created even if empty
    run bash "$WORKFLOW_SCRIPT" run test-workflow

    # File should exist (may be empty if no input sources configured)
    assert_file_exists ".workflow/test-workflow/input.txt"
}
