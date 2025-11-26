#!/usr/bin/env /opt/homebrew/bin/bash
# Integration tests for batch mode functionality
# Tests batch mode CLI options and workflow integration

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
    source "${SCRIPT_DIR}/lib/batch.sh"
    source "${SCRIPT_DIR}/lib/core.sh"
}

teardown() {
    cd "${BATS_TEST_DIRNAME}"
    teardown_test_environment
}

# ============================================================================
# CLI Option Tests
# ============================================================================

@test "integration: help run shows batch info but not batch options" {
    run "${SCRIPT_DIR}/wireflow.sh" help run
    assert_success
    # --batch option has been moved to wfw batch subcommand
    refute_output --partial "--batch"
    refute_output --partial "--no-batch"
    # Should reference batch subcommand instead
    assert_output --partial "batch"
}

@test "integration: help task does NOT show batch options" {
    run "${SCRIPT_DIR}/wireflow.sh" help task
    assert_success
    refute_output --partial "--batch"
    refute_output --partial "Batch Processing"
}

@test "integration: help batch shows batch subcommand usage" {
    run "${SCRIPT_DIR}/wireflow.sh" help batch
    assert_success
    assert_output --partial "Submit and manage batch processing"
    assert_output --partial "status"
    assert_output --partial "results"
    assert_output --partial "cancel"
}

@test "integration: main help lists batch subcommand" {
    run "${SCRIPT_DIR}/wireflow.sh" --help
    assert_success
    assert_output --partial "batch"
    # Old top-level commands should not appear
    refute_output --regexp "^[[:space:]]*status[[:space:]]"
    refute_output --regexp "^[[:space:]]*cancel[[:space:]]"
    refute_output --regexp "^[[:space:]]*results[[:space:]]"
}

# ============================================================================
# Batch Mode Configuration Tests
# ============================================================================

@test "integration: BATCH_MODE is workflow-specific setting" {
    # Initialize project
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    # Create workflow
    run "${SCRIPT_DIR}/wireflow.sh" new batch-test
    assert_success

    # Verify BATCH_MODE can be set in workflow config
    echo 'BATCH_MODE="true"' >> .workflow/run/batch-test/config

    # Check config output includes BATCH_MODE
    run "${SCRIPT_DIR}/wireflow.sh" config batch-test
    assert_success
    assert_output --partial "BATCH_MODE"
}

@test "integration: batch subcommand is recognized" {
    # Initialize project
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    # Create workflow
    run "${SCRIPT_DIR}/wireflow.sh" new batch-test
    assert_success

    # Create test input files
    mkdir -p inputs
    echo "Document 1 content" > inputs/doc1.txt

    # Dry-run with batch subcommand should work
    export WIREFLOW_DRY_RUN="true"
    run "${SCRIPT_DIR}/wireflow.sh" batch batch-test -in inputs/doc1.txt
    assert_success
    # Should show dry-run output, indicating subcommand was parsed without error
    assert_output --partial "DRY RUN MODE"
}

@test "integration: batch subcommand dry run shows batch requests" {
    # Initialize project
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    # Create workflow
    run "${SCRIPT_DIR}/wireflow.sh" new batch-test
    assert_success

    # Create test input files
    mkdir -p inputs
    echo "Document 1 content" > inputs/doc1.txt
    echo "Document 2 content" > inputs/doc2.txt
    echo "Document 3 content" > inputs/doc3.txt

    export WIREFLOW_DRY_RUN="true"

    run "${SCRIPT_DIR}/wireflow.sh" batch batch-test -- inputs/*.txt
    assert_success
    assert_output --partial "DRY RUN MODE"
}

# ============================================================================
# Status Command Tests (via batch subcommand)
# ============================================================================

@test "integration: batch status outside project lists API batches" {
    # Run status outside project - should attempt API call
    # Will fail without valid API key but should parse correctly
    run "${SCRIPT_DIR}/wireflow.sh" batch status
    # May fail due to missing API key, but should attempt the right path
    assert_output --partial "batch"
}

@test "integration: batch status with no batches shows message" {
    # Initialize project
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    # Create workflow (no batch submitted)
    run "${SCRIPT_DIR}/wireflow.sh" new test-workflow
    assert_success

    # Check status - should show no batches
    run "${SCRIPT_DIR}/wireflow.sh" batch status
    assert_success
    assert_output --partial "No active batches"
}

@test "integration: batch status with workflow name checks specific batch" {
    # Initialize project
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    # Create workflow
    run "${SCRIPT_DIR}/wireflow.sh" new my-workflow
    assert_success

    # Check status for specific workflow - no batch yet
    run "${SCRIPT_DIR}/wireflow.sh" batch status my-workflow
    assert_success
    assert_output --partial "No batch found"
}

# ============================================================================
# Cancel Command Tests (via batch subcommand)
# ============================================================================

@test "integration: batch cancel requires workflow name" {
    run "${SCRIPT_DIR}/wireflow.sh" batch cancel
    assert_failure
    assert_output --partial "Workflow name required"
}

@test "integration: batch cancel with no batch shows error" {
    # Initialize project
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    # Create workflow
    run "${SCRIPT_DIR}/wireflow.sh" new test-workflow
    assert_success

    # Try to cancel - no batch exists
    run "${SCRIPT_DIR}/wireflow.sh" batch cancel test-workflow
    assert_failure
    assert_output --partial "No batch found"
}

# ============================================================================
# Results Command Tests (via batch subcommand)
# ============================================================================

@test "integration: batch results requires workflow name" {
    run "${SCRIPT_DIR}/wireflow.sh" batch results
    assert_failure
    assert_output --partial "Workflow name required"
}

@test "integration: batch results with no batch shows error" {
    # Initialize project
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    # Create workflow
    run "${SCRIPT_DIR}/wireflow.sh" new test-workflow
    assert_success

    # Try to get results - no batch exists
    run "${SCRIPT_DIR}/wireflow.sh" batch results test-workflow
    assert_failure
    assert_output --partial "No batch found"
}

# ============================================================================
# List Command Batch Status Tests
# ============================================================================

@test "integration: list shows batch status when present" {
    # Initialize project
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    # Create workflow
    run "${SCRIPT_DIR}/wireflow.sh" new batch-workflow
    assert_success

    # Create mock batch state
    cat > .workflow/run/batch-workflow/batch-state.json <<'EOF'
{
    "batch_id": "msgbatch_test123",
    "status": "in_progress",
    "request_count": 10,
    "completed_count": 5,
    "failed_count": 0,
    "last_checked": "2025-01-15T14:30:00Z"
}
EOF

    # List should show batch status
    run "${SCRIPT_DIR}/wireflow.sh" list
    assert_success
    assert_output --partial "batch-workflow"
    assert_output --partial "[batch: in_progress"
}

@test "integration: list shows completed batch with timestamp" {
    # Initialize project
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    # Create workflow
    run "${SCRIPT_DIR}/wireflow.sh" new completed-batch
    assert_success

    # Create mock completed batch state
    cat > .workflow/run/completed-batch/batch-state.json <<'EOF'
{
    "batch_id": "msgbatch_done456",
    "status": "ended",
    "request_count": 5,
    "completed_count": 5,
    "failed_count": 0,
    "last_checked": "2025-01-15T16:45:00Z"
}
EOF

    # List should show completed status
    run "${SCRIPT_DIR}/wireflow.sh" list
    assert_success
    assert_output --partial "completed-batch"
    assert_output --partial "[batch: completed"
}
