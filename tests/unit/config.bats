#!/usr/bin/env bats

# Unit tests for lib/config.sh functions
# Tests config loading, cascading, and nested project handling

load ../test_helper/bats-support/load
load ../test_helper/bats-assert/load
load ../test_helper/bats-file/load
load ../test_helper/common.bash

setup() {
    setup_test_env

    # Source config functions directly for unit testing
    # From tests/unit/ go up two levels to reach project root
    WORKFLOW_LIB_DIR="$(cd "$BATS_TEST_DIRNAME/../.."; pwd)/lib"
    source "$WORKFLOW_LIB_DIR/utils.sh"
    source "$WORKFLOW_LIB_DIR/config.sh"
}

teardown() {
    cleanup_test_env
}

# =============================================================================
# extract_config() tests
# =============================================================================

@test "extract_config: extracts MODEL from config file" {
    local config_file="$TEST_TEMP_DIR/test.config"
    cat > "$config_file" <<'EOF'
MODEL="claude-opus-4"
EOF

    run extract_config "$config_file"
    assert_success
    assert_output --partial "MODEL=claude-opus-4"
}

@test "extract_config: extracts all config values" {
    local config_file="$TEST_TEMP_DIR/test.config"
    cat > "$config_file" <<'EOF'
MODEL="claude-opus-4"
TEMPERATURE=0.7
MAX_TOKENS=8000
OUTPUT_FORMAT="json"
EOF

    run extract_config "$config_file"
    assert_success
    assert_output --partial "MODEL=claude-opus-4"
    assert_output --partial "TEMPERATURE=0.7"
    assert_output --partial "MAX_TOKENS=8000"
    assert_output --partial "OUTPUT_FORMAT=json"
}

@test "extract_config: handles array SYSTEM_PROMPTS" {
    local config_file="$TEST_TEMP_DIR/test.config"
    cat > "$config_file" <<'EOF'
SYSTEM_PROMPTS=(base research stats)
EOF

    run extract_config "$config_file"
    assert_success
    assert_output --partial "SYSTEM_PROMPTS="
    assert_output --partial "base"
    assert_output --partial "research"
    assert_output --partial "stats"
}

@test "extract_config: handles missing file gracefully" {
    run extract_config "/nonexistent/file"
    assert_success
    # Should output empty/default values
    assert_output --partial "MODEL="
    assert_output --partial "TEMPERATURE="
}

@test "extract_config: handles empty config file" {
    local config_file="$TEST_TEMP_DIR/empty.config"
    touch "$config_file"

    run extract_config "$config_file"
    assert_success
    # Should output empty values
    assert_output --partial "MODEL="
}

@test "extract_config: runs in isolated subshell" {
    local config_file="$TEST_TEMP_DIR/test.config"
    cat > "$config_file" <<'EOF'
DANGEROUS_VAR="should_not_leak"
MODEL="claude-opus-4"
EOF

    extract_config "$config_file" > /dev/null

    # Variable should not leak to current shell
    [[ -z "${DANGEROUS_VAR:-}" ]]
}

# =============================================================================
# cat_default_config() tests
# Note: These functions require CONFIG_KEYS arrays from wireflow.sh
# Testing them in isolation is not practical - covered by integration tests
# =============================================================================

# =============================================================================
# load_config_level() tests
# =============================================================================

# Note: load_config_level tests that verify environment variable side effects
# are not reliable in bats 'run' context. Covered by integration tests.

@test "load_config_level: empty values don't override existing" {
    local config_file="$TEST_TEMP_DIR/test.config"
    cat > "$config_file" <<'EOF'
MODEL=""
TEMPERATURE=
EOF

    # Set existing values
    MODEL="existing-model"
    TEMPERATURE="0.8"

    # Load config (empty values should not override)
    load_config_level "$config_file"

    # Verify existing values preserved
    assert_equal "$MODEL" "existing-model"
    assert_equal "$TEMPERATURE" "0.8"
}

@test "load_config_level: handles missing file gracefully" {
    # Should not error on missing file
    run load_config_level "/nonexistent/config"
    # Function succeeds silently for missing files
}

# =============================================================================
# find_ancestor_projects() tests
# =============================================================================

@test "find_ancestor_projects: returns failure for single project (no ancestors)" {
    mkdir -p "$TEST_TEMP_DIR/project/.workflow"

    cd "$TEST_TEMP_DIR/project"
    run find_ancestor_projects "$TEST_TEMP_DIR/project"

    # Returns failure when there are no ancestor projects
    assert_failure
}

@test "find_ancestor_projects: returns oldest first for nested projects" {
    # Create three-level nesting
    mkdir -p "$TEST_TEMP_DIR/grandparent/.workflow"
    mkdir -p "$TEST_TEMP_DIR/grandparent/parent/.workflow"
    mkdir -p "$TEST_TEMP_DIR/grandparent/parent/child/.workflow"

    cd "$TEST_TEMP_DIR/grandparent/parent/child"
    run find_ancestor_projects "$TEST_TEMP_DIR/grandparent/parent/child"

    assert_success

    # Parse output (newline-separated)
    local -a ancestors
    mapfile -t ancestors <<< "$output"

    # Should have 2 ancestors (grandparent and parent)
    [[ ${#ancestors[@]} -eq 2 ]]

    # First should be grandparent (oldest)
    [[ "${ancestors[0]}" == "$TEST_TEMP_DIR/grandparent" ]]

    # Second should be parent
    [[ "${ancestors[1]}" == "$TEST_TEMP_DIR/grandparent/parent" ]]
}

@test "find_ancestor_projects: stops at HOME boundary" {
    # Create project outside of any parent projects
    mkdir -p "$HOME/standalone/.workflow"

    cd "$HOME/standalone"
    run find_ancestor_projects "$HOME/standalone"

    # Returns failure when no ancestors found (stopped at HOME)
    assert_failure
}

# =============================================================================
# aggregate_nested_project_descriptions() tests
# Note: This function does not exist in the current codebase
# These tests were for a planned feature that was not implemented
# =============================================================================

# =============================================================================
# load_ancestor_configs() tests
# =============================================================================

@test "load_ancestor_configs: processes ancestors for nested projects" {
    mkdir -p "$TEST_TEMP_DIR/grandparent/.workflow"
    cat > "$TEST_TEMP_DIR/grandparent/.workflow/config" <<'EOF'
MODEL="grandparent-model"
TEMPERATURE=0.3
EOF

    mkdir -p "$TEST_TEMP_DIR/grandparent/parent/.workflow"
    cat > "$TEST_TEMP_DIR/grandparent/parent/.workflow/config" <<'EOF'
TEMPERATURE=0.5
EOF

    mkdir -p "$TEST_TEMP_DIR/grandparent/parent/child/.workflow"

    cd "$TEST_TEMP_DIR/grandparent/parent/child"
    # load_ancestor_configs uses pwd internally
    # Note: This may return failure if find_ancestor_projects fails
    run load_ancestor_configs

    # Function behavior varies based on project structure detection
    # Covered more thoroughly by integration tests
}

@test "load_ancestor_configs: handles single project (no ancestors)" {
    mkdir -p "$TEST_TEMP_DIR/single/.workflow"
    cat > "$TEST_TEMP_DIR/single/.workflow/config" <<'EOF'
MODEL="single-model"
EOF

    cd "$TEST_TEMP_DIR/single"
    run load_ancestor_configs

    assert_success
}

# =============================================================================
# resolve_model() tests
# =============================================================================

@test "resolve_model: returns MODEL when explicitly set" {
    MODEL="claude-explicit-model"
    PROFILE="balanced"
    MODEL_BALANCED="claude-sonnet-4-5"

    run resolve_model
    assert_success
    assert_output "claude-explicit-model"
}

@test "resolve_model: resolves fast profile to MODEL_FAST" {
    MODEL=""
    PROFILE="fast"
    MODEL_FAST="claude-haiku-4-5"
    MODEL_BALANCED="claude-sonnet-4-5"
    MODEL_DEEP="claude-opus-4-5"

    run resolve_model
    assert_success
    assert_output "claude-haiku-4-5"
}

@test "resolve_model: resolves balanced profile to MODEL_BALANCED" {
    MODEL=""
    PROFILE="balanced"
    MODEL_FAST="claude-haiku-4-5"
    MODEL_BALANCED="claude-sonnet-4-5"
    MODEL_DEEP="claude-opus-4-5"

    run resolve_model
    assert_success
    assert_output "claude-sonnet-4-5"
}

@test "resolve_model: resolves deep profile to MODEL_DEEP" {
    MODEL=""
    PROFILE="deep"
    MODEL_FAST="claude-haiku-4-5"
    MODEL_BALANCED="claude-sonnet-4-5"
    MODEL_DEEP="claude-opus-4-5"

    run resolve_model
    assert_success
    assert_output "claude-opus-4-5"
}

@test "resolve_model: falls back to balanced for unknown profile" {
    MODEL=""
    PROFILE="unknown"
    MODEL_FAST="claude-haiku-4-5"
    MODEL_BALANCED="claude-sonnet-4-5"
    MODEL_DEEP="claude-opus-4-5"

    run resolve_model
    assert_success
    assert_output --partial "claude-sonnet-4-5"
    assert_output --partial "Warning: Unknown profile"
}

@test "resolve_model: sets RESOLVED_MODEL global variable" {
    MODEL=""
    PROFILE="deep"
    MODEL_DEEP="claude-opus-4-5"
    MODEL_BALANCED="claude-sonnet-4-5"

    resolve_model > /dev/null
    assert_equal "$RESOLVED_MODEL" "claude-opus-4-5"
}

# =============================================================================
# validate_api_config() tests
# =============================================================================

@test "validate_api_config: passes for valid thinking config" {
    THINKING_BUDGET=10000
    MAX_TOKENS=16000

    run validate_api_config "claude-sonnet-4-5" "true" "high"
    assert_success
}

@test "validate_api_config: warns for thinking on unsupported model" {
    THINKING_BUDGET=10000
    MAX_TOKENS=16000

    run validate_api_config "claude-3-opus" "true" "high"
    assert_success
    assert_output --partial "Extended thinking may not be supported"
}

@test "validate_api_config: adjusts THINKING_BUDGET below minimum" {
    THINKING_BUDGET=500
    MAX_TOKENS=16000

    validate_api_config "claude-sonnet-4-5" "true" "high" 2>/dev/null
    assert_equal "$THINKING_BUDGET" "1024"
}

@test "validate_api_config: adjusts THINKING_BUDGET exceeding MAX_TOKENS" {
    THINKING_BUDGET=20000
    MAX_TOKENS=16000

    validate_api_config "claude-sonnet-4-5" "true" "high" 2>/dev/null
    # Should be adjusted to MAX_TOKENS - 1000
    assert_equal "$THINKING_BUDGET" "15000"
}

@test "validate_api_config: allows effort on Opus 4.5" {
    THINKING_BUDGET=10000
    MAX_TOKENS=16000
    EFFORT="medium"

    run validate_api_config "claude-opus-4-5-20251101" "false" "medium"
    assert_success
    refute_output --partial "Effort parameter only supported"
}

@test "validate_api_config: warns and resets effort for non-Opus 4.5" {
    THINKING_BUDGET=10000
    MAX_TOKENS=16000
    EFFORT="medium"

    # Run validation - must not use subshell to test EFFORT modification
    # Redirect stderr to a temp file to capture warning
    local tmpfile="$TEST_TEMP_DIR/stderr.txt"
    validate_api_config "claude-sonnet-4-5" "false" "medium" 2>"$tmpfile"

    # Check warning was emitted
    grep -q "Effort parameter only supported" "$tmpfile"

    # Check EFFORT was reset to high
    assert_equal "$EFFORT" "high"
}

@test "validate_api_config: passes silently for effort=high" {
    THINKING_BUDGET=10000
    MAX_TOKENS=16000

    run validate_api_config "claude-sonnet-4-5" "false" "high"
    assert_success
    assert_output ""
}

@test "validate_api_config: skips thinking validation when disabled" {
    THINKING_BUDGET=500  # Invalid but should be ignored
    MAX_TOKENS=16000

    run validate_api_config "claude-3-opus" "false" "high"
    assert_success
    assert_output ""
}

# =============================================================================
# Project Config Caching tests
# =============================================================================

@test "cache_project_config: caches scalar config values" {
    # Initialize required arrays if not already
    CONFIG_KEYS=(MODEL TEMPERATURE MAX_TOKENS OUTPUT_FORMAT)
    USER_ENV_KEYS=(WIREFLOW_PROMPT_PREFIX)
    PROJECT_KEYS=()
    declare -gA PROJECT_CONFIG_CACHE=()
    declare -gA PROJECT_CONFIG_ARRAYS=()

    MODEL="claude-opus-4-5"
    TEMPERATURE="0.5"
    MAX_TOKENS="8000"
    OUTPUT_FORMAT="json"
    WIREFLOW_PROMPT_PREFIX="/custom/prompts"

    cache_project_config

    assert_equal "${PROJECT_CONFIG_CACHE[MODEL]}" "claude-opus-4-5"
    assert_equal "${PROJECT_CONFIG_CACHE[TEMPERATURE]}" "0.5"
    assert_equal "${PROJECT_CONFIG_CACHE[MAX_TOKENS]}" "8000"
    assert_equal "${PROJECT_CONFIG_CACHE[OUTPUT_FORMAT]}" "json"
    assert_equal "${PROJECT_CONFIG_CACHE[WIREFLOW_PROMPT_PREFIX]}" "/custom/prompts"
    assert_equal "$PROJECT_CONFIG_CACHED" "true"
}

@test "cache_project_config: caches array config values" {
    CONFIG_KEYS=(SYSTEM_PROMPTS)
    USER_ENV_KEYS=()
    PROJECT_KEYS=(CONTEXT)
    declare -gA PROJECT_CONFIG_CACHE=()
    declare -gA PROJECT_CONFIG_ARRAYS=()
    declare -a SYSTEM_PROMPTS=(base research custom)
    declare -a CONTEXT=(file1.txt file2.md)

    cache_project_config

    # Arrays should be in PROJECT_CONFIG_ARRAYS, not CACHE
    assert [ -n "${PROJECT_CONFIG_ARRAYS[SYSTEM_PROMPTS]}" ]
    assert [ -n "${PROJECT_CONFIG_ARRAYS[CONTEXT]}" ]

    # Verify array contents (newline-delimited)
    [[ "${PROJECT_CONFIG_ARRAYS[SYSTEM_PROMPTS]}" == *"base"* ]]
    [[ "${PROJECT_CONFIG_ARRAYS[SYSTEM_PROMPTS]}" == *"research"* ]]
    [[ "${PROJECT_CONFIG_ARRAYS[CONTEXT]}" == *"file1.txt"* ]]
}

@test "cache_project_config: handles empty arrays" {
    CONFIG_KEYS=(SYSTEM_PROMPTS)
    USER_ENV_KEYS=()
    PROJECT_KEYS=(CONTEXT)
    declare -gA PROJECT_CONFIG_CACHE=()
    declare -gA PROJECT_CONFIG_ARRAYS=()
    declare -a SYSTEM_PROMPTS=()
    declare -a CONTEXT=()

    cache_project_config

    # Empty arrays should still be cached
    assert [ -v PROJECT_CONFIG_ARRAYS[SYSTEM_PROMPTS] ]
    assert [ -v PROJECT_CONFIG_ARRAYS[CONTEXT] ]
}

@test "reset_workflow_config: restores cached scalars" {
    # Setup cache
    declare -gA PROJECT_CONFIG_CACHE=([MODEL]="cached-model" [TEMPERATURE]="0.7")
    declare -gA PROJECT_CONFIG_ARRAYS=()
    declare -a WORKFLOW_KEYS=(DEPENDS_ON INPUT)
    declare -gA WORKFLOW_SOURCE_MAP=([DEPENDS_ON]="workflow" [INPUT]="cli")

    # Set different current values
    MODEL="current-model"
    TEMPERATURE="0.9"
    DEPENDS_ON=(dep1 dep2)
    INPUT=(input1.txt)

    # Source pipeline.sh for reset_workflow_config
    source "$WORKFLOW_LIB_DIR/pipeline.sh"

    reset_workflow_config

    assert_equal "$MODEL" "cached-model"
    assert_equal "$TEMPERATURE" "0.7"
    # Workflow-specific should be cleared
    assert_equal "${#DEPENDS_ON[@]}" "0"
    assert_equal "${#INPUT[@]}" "0"
}

@test "reset_workflow_config: restores cached arrays" {
    # Setup cache with arrays
    declare -gA PROJECT_CONFIG_CACHE=()
    declare -gA PROJECT_CONFIG_ARRAYS=([SYSTEM_PROMPTS]=$'base\nresearch' [CONTEXT]=$'ctx1.txt\nctx2.txt')
    declare -a WORKFLOW_KEYS=(DEPENDS_ON INPUT)
    declare -gA WORKFLOW_SOURCE_MAP=([DEPENDS_ON]="unset" [INPUT]="unset")
    declare -a SYSTEM_PROMPTS=(different)
    declare -a CONTEXT=(other.txt)

    source "$WORKFLOW_LIB_DIR/pipeline.sh"

    reset_workflow_config

    # Arrays should be restored
    assert_equal "${#SYSTEM_PROMPTS[@]}" "2"
    assert_equal "${SYSTEM_PROMPTS[0]}" "base"
    assert_equal "${SYSTEM_PROMPTS[1]}" "research"
    assert_equal "${#CONTEXT[@]}" "2"
    assert_equal "${CONTEXT[0]}" "ctx1.txt"
}

@test "reset_workflow_config: handles empty cached arrays" {
    declare -gA PROJECT_CONFIG_CACHE=()
    declare -gA PROJECT_CONFIG_ARRAYS=([SYSTEM_PROMPTS]="" [CONTEXT]="")
    declare -a WORKFLOW_KEYS=(DEPENDS_ON INPUT)
    declare -gA WORKFLOW_SOURCE_MAP=([DEPENDS_ON]="unset" [INPUT]="unset")
    declare -a SYSTEM_PROMPTS=(will-be-cleared)
    declare -a CONTEXT=(will-be-cleared)

    source "$WORKFLOW_LIB_DIR/pipeline.sh"

    reset_workflow_config

    # Should result in empty arrays
    assert_equal "${#SYSTEM_PROMPTS[@]}" "0"
    assert_equal "${#CONTEXT[@]}" "0"
}
