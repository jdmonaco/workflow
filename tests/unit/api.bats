#!/usr/bin/env /opt/homebrew/bin/bash
# Unit tests for lib/api.sh
# Tests API validation and citation processing

# Load existing bats helpers
load ../test_helper/bats-support/load
load ../test_helper/bats-assert/load
load ../test_helper/bats-file/load
load ../test_helper/common.bash

# Load our custom helpers
source "${BATS_TEST_DIRNAME}/../test_helper/mock_env.sh"
source "${BATS_TEST_DIRNAME}/../test_helper/fixtures.sh"

# Source the library being tested
setup() {
    setup_test_env
    setup_test_environment
    export WIREFLOW_LIB_DIR="${BATS_TEST_DIRNAME}/../../lib"
    source "${WIREFLOW_LIB_DIR}/api.sh"

    # Clear any existing API key
    unset ANTHROPIC_API_KEY
}

teardown() {
    teardown_test_environment
}

# ============================================================================
# anthropic_validate tests
# ============================================================================

@test "anthropic_validate: accepts valid API key" {
    run anthropic_validate "sk-ant-api03-valid-key"
    assert_success
}

@test "anthropic_validate: rejects empty API key" {
    run anthropic_validate ""
    assert_failure
    assert_output --partial "ANTHROPIC_API_KEY"
}

@test "anthropic_validate: uses env var when no argument" {
    export ANTHROPIC_API_KEY="sk-ant-api03-from-env"
    run anthropic_validate
    assert_success
}

@test "anthropic_validate: fails when no key available" {
    unset ANTHROPIC_API_KEY
    run anthropic_validate
    assert_failure
    assert_output --partial "ANTHROPIC_API_KEY"
}

# ============================================================================
# parse_citations_response tests
# ============================================================================

@test "parse_citations_response: parses response with citations" {
    local response='{"content":[{"type":"text","text":"Sample text","citations":[{"type":"char_location","document_title":"Doc1","start_char_index":0,"end_char_index":10}]}]}'

    run parse_citations_response "$response" ""
    assert_success
    # Should have text and citations
    assert_output --partial '"text"'
    assert_output --partial '"citations"'
}

@test "parse_citations_response: handles empty content" {
    local response='{"content":[]}'

    run parse_citations_response "$response" ""
    assert_success
    assert_output --partial '"text": ""'
    assert_output --partial '"citations": []'
}

@test "parse_citations_response: handles response without citations" {
    local response='{"content":[{"type":"text","text":"Plain text without citations"}]}'

    run parse_citations_response "$response" ""
    assert_success
    assert_output --partial "Plain text without citations"
    assert_output --partial '"citations": []'
}

@test "parse_citations_response: handles null content" {
    local response='{"content":null}'

    run parse_citations_response "$response" ""
    # Should return error status for null content
    assert_failure
    assert_output --partial '"citations": []'
}

# ============================================================================
# format_citations_output tests
# ============================================================================

@test "format_citations_output: formats markdown citations" {
    local parsed='{"text":"Sample text[^1]","citations":[{"citation_number":1,"type":"page_location","document_title":"Test Doc","start_page_number":1,"end_page_number":2}]}'

    run format_citations_output "$parsed" "md"
    assert_success
    assert_output --partial "Sample text"
    assert_output --partial "[^1]:"
    assert_output --partial "Test Doc"
}

@test "format_citations_output: formats text citations" {
    local parsed='{"text":"Sample text[^1]","citations":[{"citation_number":1,"type":"page_location","document_title":"Test Doc","start_page_number":1,"end_page_number":2}]}'

    run format_citations_output "$parsed" "txt"
    assert_success
    assert_output --partial "References:"
    assert_output --partial "[1]"
    assert_output --partial "Test Doc"
}

@test "format_citations_output: returns JSON format unchanged" {
    local parsed='{"text":"Sample text","citations":[{"citation_number":1}]}'

    run format_citations_output "$parsed" "json"
    assert_success
    # Should return the JSON structure as-is
    assert_output --partial '"text"'
    assert_output --partial '"citations"'
}

@test "format_citations_output: handles no citations" {
    local parsed='{"text":"Plain text without citations","citations":[]}'

    run format_citations_output "$parsed" "md"
    assert_success
    # Should return text without references section
    assert_output "Plain text without citations"
}
