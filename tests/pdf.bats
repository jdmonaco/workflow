#!/usr/bin/env bats

load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load
load test_helper/common

setup() {
    setup_test_env

    # Source utility functions for testing
    WORKFLOW_LIB_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")"; pwd)/lib"
    source "$WORKFLOW_LIB_DIR/utils.sh"
}

teardown() {
    cleanup_test_env
}

# =============================================================================
# PDF File Type Detection
# =============================================================================

@test "pdf: detect_file_type recognizes .pdf extension" {
    # Create a dummy PDF file (just needs to exist with .pdf extension)
    touch test.pdf

    run detect_file_type "test.pdf"
    assert_success
    assert_output "document"
}

# =============================================================================
# PDF Validation
# =============================================================================

@test "pdf: validate_pdf_file fails for non-existent file" {
    run validate_pdf_file "nonexistent.pdf"
    assert_failure
    assert_output --partial "Error: PDF file not found"
}

@test "pdf: validate_pdf_file fails for non-readable file" {
    # Create a file and make it non-readable
    touch test.pdf
    chmod 000 test.pdf

    run validate_pdf_file "test.pdf"
    assert_failure
    assert_output --partial "Error: PDF file not readable"

    # Cleanup
    chmod 644 test.pdf
}

@test "pdf: validate_pdf_file fails for file exceeding 32MB limit" {
    skip "Skipping large file test (would take too long to create 32MB+ file)"
    # This test is documented but skipped for performance
    # Manual testing should verify 32MB size limit
}

@test "pdf: validate_pdf_file succeeds for valid small PDF" {
    # Create a minimal valid PDF (smallest possible PDF)
    cat > test.pdf << 'EOF'
%PDF-1.0
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj
xref
0 4
0000000000 65535 f
0000000009 00000 n
0000000052 00000 n
0000000101 00000 n
trailer<</Size 4/Root 1 0 R>>
startxref
189
%%EOF
EOF

    run validate_pdf_file "test.pdf"
    assert_success
}

# =============================================================================
# PDF Content Block Building
# =============================================================================

@test "pdf: build_document_content_block fails for non-existent file" {
    run build_document_content_block "nonexistent.pdf" "false"
    assert_failure
}

@test "pdf: build_document_content_block creates valid JSON structure without cache" {
    # Create a minimal valid PDF
    cat > test.pdf << 'EOF'
%PDF-1.0
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj
xref
0 4
0000000000 65535 f
0000000009 00000 n
0000000052 00000 n
0000000101 00000 n
trailer<</Size 4/Root 1 0 R>>
startxref
189
%%EOF
EOF

    run build_document_content_block "test.pdf" "false"
    assert_success

    # Verify JSON structure
    echo "$output" | jq -e '.type == "document"'
    echo "$output" | jq -e '.source.type == "base64"'
    echo "$output" | jq -e '.source.media_type == "application/pdf"'
    echo "$output" | jq -e '.source.data'

    # Verify no cache_control when disabled
    run bash -c "echo '$output' | jq -e '.cache_control'"
    assert_failure  # Should not have cache_control field
}

@test "pdf: build_document_content_block creates valid JSON structure with cache" {
    # Create a minimal valid PDF
    cat > test.pdf << 'EOF'
%PDF-1.0
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj
xref
0 4
0000000000 65535 f
0000000009 00000 n
0000000052 00000 n
0000000101 00000 n
trailer<</Size 4/Root 1 0 R>>
startxref
189
%%EOF
EOF

    run build_document_content_block "test.pdf" "true"
    assert_success

    # Verify JSON structure with cache_control
    echo "$output" | jq -e '.type == "document"'
    echo "$output" | jq -e '.cache_control.type == "ephemeral"'
}

# =============================================================================
# Integration Tests (would require full workflow setup)
# =============================================================================

@test "pdf: workflow can include PDF in context" {
    skip "Integration test - requires full workflow and API setup"
    # This would test end-to-end PDF processing in a workflow
}

@test "pdf: PDF appears before text in final API request" {
    skip "Integration test - requires inspecting assembled content blocks"
    # This would verify PDF-first ordering in execute_api_request()
}

@test "pdf: PDF documents are tracked in document index map" {
    skip "Integration test - requires full workflow execution"
    # This would verify PDFs are citable via document index
}
