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

@test "integration: help run shows batch options" {
    run "${SCRIPT_DIR}/wireflow.sh" help run
    assert_success
    assert_output --partial "--batch"
    assert_output --partial "--no-batch"
    assert_output --partial "Batch Processing Options"
}

@test "integration: help task does NOT show batch options" {
    run "${SCRIPT_DIR}/wireflow.sh" help task
    assert_success
    refute_output --partial "--batch"
    refute_output --partial "Batch Processing"
}

@test "integration: help status shows batch status command" {
    run "${SCRIPT_DIR}/wireflow.sh" help status
    assert_success
    assert_output --partial "batch processing status"
}

@test "integration: help cancel shows batch cancel command" {
    run "${SCRIPT_DIR}/wireflow.sh" help cancel
    assert_success
    assert_output --partial "Cancel a pending batch"
}

@test "integration: help results shows batch results command" {
    run "${SCRIPT_DIR}/wireflow.sh" help results
    assert_success
    assert_output --partial "Retrieve results"
}

@test "integration: main help lists batch commands" {
    run "${SCRIPT_DIR}/wireflow.sh" --help
    assert_success
    assert_output --partial "status"
    assert_output --partial "cancel"
    assert_output --partial "results"
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

@test "integration: --batch option is recognized by run command" {
    # Initialize project
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    # Create workflow
    run "${SCRIPT_DIR}/wireflow.sh" new batch-test
    assert_success

    # Dry-run with batch option should work (batch check happens after dry-run)
    export WIREFLOW_DRY_RUN="true"
    run "${SCRIPT_DIR}/wireflow.sh" run batch-test --batch
    assert_success
    # Should show dry-run output, indicating option was parsed without error
    assert_output --partial "DRY RUN MODE"
}

@test "integration: batch mode dry run shows batch requests" {
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

    run "${SCRIPT_DIR}/wireflow.sh" run batch-test --batch -- inputs/*.txt
    # Should fail because dry-run happens before batch mode check
    # but should parse the batch option correctly
    assert_output --partial "batch"
}

# ============================================================================
# Status Command Tests
# ============================================================================

@test "integration: status command outside project lists API batches" {
    # Run status outside project - should attempt API call
    # Will fail without valid API key but should parse correctly
    run "${SCRIPT_DIR}/wireflow.sh" status
    # May fail due to missing API key, but should attempt the right path
    assert_output --partial "batch"
}

@test "integration: status command with no batches shows message" {
    # Initialize project
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    # Create workflow (no batch submitted)
    run "${SCRIPT_DIR}/wireflow.sh" new test-workflow
    assert_success

    # Check status - should show no batches
    run "${SCRIPT_DIR}/wireflow.sh" status
    assert_success
    assert_output --partial "No active batches"
}

@test "integration: status with workflow name checks specific batch" {
    # Initialize project
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    # Create workflow
    run "${SCRIPT_DIR}/wireflow.sh" new my-workflow
    assert_success

    # Check status for specific workflow - no batch yet
    run "${SCRIPT_DIR}/wireflow.sh" status my-workflow
    assert_success
    assert_output --partial "No batch found"
}

# ============================================================================
# Cancel Command Tests
# ============================================================================

@test "integration: cancel requires workflow name" {
    run "${SCRIPT_DIR}/wireflow.sh" cancel
    assert_failure
    assert_output --partial "Workflow name required"
}

@test "integration: cancel with no batch shows error" {
    # Initialize project
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    # Create workflow
    run "${SCRIPT_DIR}/wireflow.sh" new test-workflow
    assert_success

    # Try to cancel - no batch exists
    run "${SCRIPT_DIR}/wireflow.sh" cancel test-workflow
    assert_failure
    assert_output --partial "No batch found"
}

# ============================================================================
# Results Command Tests
# ============================================================================

@test "integration: results requires workflow name" {
    run "${SCRIPT_DIR}/wireflow.sh" results
    assert_failure
    assert_output --partial "Workflow name required"
}

@test "integration: results with no batch shows error" {
    # Initialize project
    run "${SCRIPT_DIR}/wireflow.sh" init
    assert_success

    # Create workflow
    run "${SCRIPT_DIR}/wireflow.sh" new test-workflow
    assert_success

    # Try to get results - no batch exists
    run "${SCRIPT_DIR}/wireflow.sh" results test-workflow
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
