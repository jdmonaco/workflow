#!/usr/bin/env /opt/homebrew/bin/bash
# Custom Assertions for WireFlow Tests
# Extends bats-assert with wireflow-specific assertions

# Note: This assumes bats helpers are already loaded by the test file

# Assert that a wireflow project exists
# Args:
#   $1 - Project directory path
assert_project_exists() {
    local project_dir="${1:?Project directory required}"

    assert_dir_exists "$project_dir/.workflow"
    assert_file_exists "$project_dir/.workflow/config"
    assert_file_exists "$project_dir/.workflow/project.txt"
}

# Assert that a wireflow workflow exists
# Args:
#   $1 - Workflow directory path
assert_workflow_exists() {
    local workflow_dir="${1:?Workflow directory required}"

    assert_dir_exists "$workflow_dir"
    assert_file_exists "$workflow_dir/config"
    assert_file_exists "$workflow_dir/task.txt"
}

# Assert that configuration contains a specific key-value pair
# Args:
#   $1 - Config file path
#   $2 - Key
#   $3 - Expected value
assert_config_contains() {
    local config_file="${1:?Config file required}"
    local key="${2:?Key required}"
    local expected_value="${3:?Expected value required}"

    assert_file_exists "$config_file"

    local actual_value
    actual_value=$(grep "^${key}=" "$config_file" | cut -d'=' -f2- | tr -d '"')

    if [[ "$actual_value" != "$expected_value" ]]; then
        fail "Config key '$key' expected '$expected_value' but got '$actual_value'"
    fi
}

# Assert that a run directory contains expected output files
# Args:
#   $1 - Run directory path
assert_run_output_exists() {
    local run_dir="${1:?Run directory required}"

    assert_dir_exists "$run_dir"

    # At least one output format should exist
    if [[ ! -f "$run_dir/output.txt" ]] && [[ ! -f "$run_dir/output.md" ]] && [[ ! -f "$run_dir/output.json" ]]; then
        fail "No output files found in run directory: $run_dir"
    fi
}

# Assert that JSON is valid
# Args:
#   $1 - JSON string or file path
assert_valid_json() {
    local json_input="${1:?JSON input required}"

    local json_content
    if [[ -f "$json_input" ]]; then
        json_content=$(cat "$json_input")
    else
        json_content="$json_input"
    fi

    if ! echo "$json_content" | jq empty 2>/dev/null; then
        fail "Invalid JSON: $json_content"
    fi
}

# Assert that XML contains a specific element
# Args:
#   $1 - XML file path or content
#   $2 - Element name to check for
assert_xml_contains_element() {
    local xml_input="${1:?XML input required}"
    local element="${2:?Element name required}"

    local xml_content
    if [[ -f "$xml_input" ]]; then
        xml_content=$(cat "$xml_input")
    else
        xml_content="$xml_input"
    fi

    if ! echo "$xml_content" | grep -q "<${element}[> ]"; then
        fail "XML does not contain element: $element"
    fi
}

# Assert that a task file has valid structure
# Args:
#   $1 - Task file path
assert_valid_task_file() {
    local task_file="${1:?Task file required}"

    assert_file_exists "$task_file"

    local content=$(cat "$task_file")

    # Check for required elements
    assert_xml_contains_element "$content" "user-task"
    assert_xml_contains_element "$content" "metadata"
    assert_xml_contains_element "$content" "name"
    assert_xml_contains_element "$content" "content"
}

# Assert that a system prompt file has valid structure
# Args:
#   $1 - Prompt file path
assert_valid_system_prompt() {
    local prompt_file="${1:?Prompt file required}"

    assert_file_exists "$prompt_file"

    local content=$(cat "$prompt_file")

    # Check for required elements
    assert_xml_contains_element "$content" "system-component"
    assert_xml_contains_element "$content" "metadata"
    assert_xml_contains_element "$content" "name"
    assert_xml_contains_element "$content" "content"
}

# Assert that API response has expected structure
# Args:
#   $1 - Response file or JSON string
assert_valid_api_response() {
    local response="${1:?Response required}"

    assert_valid_json "$response"

    local json_content
    if [[ -f "$response" ]]; then
        json_content=$(cat "$response")
    else
        json_content="$response"
    fi

    # Check for required fields
    if echo "$json_content" | jq -e '.error' >/dev/null 2>&1; then
        # Error response
        echo "$json_content" | jq -e '.error.type' >/dev/null || fail "Error response missing type"
        echo "$json_content" | jq -e '.error.message' >/dev/null || fail "Error response missing message"
    else
        # Success response
        echo "$json_content" | jq -e '.id' >/dev/null || fail "Response missing id"
        echo "$json_content" | jq -e '.content' >/dev/null || fail "Response missing content"
        echo "$json_content" | jq -e '.model' >/dev/null || fail "Response missing model"
    fi
}

# Assert that a command outputs specific text
# Args:
#   $1 - Command to run
#   $2 - Expected text (substring)
assert_command_outputs() {
    local command="${1:?Command required}"
    local expected="${2:?Expected output required}"

    local output
    output=$(eval "$command" 2>&1)

    if [[ "$output" != *"$expected"* ]]; then
        fail "Command output does not contain expected text.\nExpected: $expected\nActual: $output"
    fi
}

# Assert that a function exists
# Args:
#   $1 - Function name
assert_function_exists() {
    local func_name="${1:?Function name required}"

    if ! declare -F "$func_name" >/dev/null; then
        fail "Function '$func_name' does not exist"
    fi
}

# Assert that an environment variable is set
# Args:
#   $1 - Variable name
#   $2 - Optional expected value
assert_env_var_set() {
    local var_name="${1:?Variable name required}"
    local expected_value="${2:-}"

    if [[ -z "${!var_name:-}" ]]; then
        fail "Environment variable '$var_name' is not set"
    fi

    if [[ -n "$expected_value" ]] && [[ "${!var_name}" != "$expected_value" ]]; then
        fail "Environment variable '$var_name' expected '$expected_value' but got '${!var_name}'"
    fi
}

# Assert that a path is normalized correctly
# Args:
#   $1 - Input path
#   $2 - Expected normalized path
assert_path_normalized() {
    local input_path="${1:?Input path required}"
    local expected="${2:?Expected path required}"

    # Source utils if normalize_path function isn't loaded
    if ! declare -F normalize_path >/dev/null; then
        source "${WIREFLOW_LIB_DIR:-lib}/utils.sh"
    fi

    local actual
    actual=$(normalize_path "$input_path")

    if [[ "$actual" != "$expected" ]]; then
        fail "Path normalization failed.\nInput: $input_path\nExpected: $expected\nActual: $actual"
    fi
}

# Assert that token estimation is within range
# Args:
#   $1 - Text to estimate
#   $2 - Minimum expected tokens
#   $3 - Maximum expected tokens
assert_token_estimate_in_range() {
    local text="${1:?Text required}"
    local min_tokens="${2:?Minimum tokens required}"
    local max_tokens="${3:?Maximum tokens required}"

    # Source execute if estimate_tokens function isn't loaded
    if ! declare -F estimate_tokens >/dev/null; then
        source "${WIREFLOW_LIB_DIR:-lib}/execute.sh"
    fi

    local estimated
    estimated=$(estimate_tokens "$text")

    if (( estimated < min_tokens )) || (( estimated > max_tokens )); then
        fail "Token estimate $estimated not in range [$min_tokens, $max_tokens]"
    fi
}

# Assert that a file has specific permissions
# Args:
#   $1 - File path
#   $2 - Expected permissions (octal, e.g., 755)
assert_file_permissions() {
    local file_path="${1:?File path required}"
    local expected_perms="${2:?Expected permissions required}"

    assert_file_exists "$file_path"

    local actual_perms
    if [[ "$(uname)" == "Darwin" ]]; then
        actual_perms=$(stat -f "%OLp" "$file_path")
    else
        actual_perms=$(stat -c "%a" "$file_path")
    fi

    if [[ "$actual_perms" != "$expected_perms" ]]; then
        fail "File permissions for '$file_path' expected '$expected_perms' but got '$actual_perms'"
    fi
}

# Assert that cache control is properly set in JSON
# Args:
#   $1 - JSON file or string
#   $2 - Expected cache type (ephemeral, etc.)
assert_cache_control_set() {
    local json_input="${1:?JSON input required}"
    local expected_type="${2:-ephemeral}"

    assert_valid_json "$json_input"

    local json_content
    if [[ -f "$json_input" ]]; then
        json_content=$(cat "$json_input")
    else
        json_content="$json_input"
    fi

    local cache_type
    cache_type=$(echo "$json_content" | jq -r '.cache_control.type // empty')

    if [[ -z "$cache_type" ]]; then
        fail "No cache_control found in JSON"
    fi

    if [[ "$cache_type" != "$expected_type" ]]; then
        fail "Cache control type expected '$expected_type' but got '$cache_type'"
    fi
}

# Export all assertion functions
export -f assert_project_exists
export -f assert_workflow_exists
export -f assert_config_contains
export -f assert_run_output_exists
export -f assert_valid_json
export -f assert_xml_contains_element
export -f assert_valid_task_file
export -f assert_valid_system_prompt
export -f assert_valid_api_response
export -f assert_command_outputs
export -f assert_function_exists
export -f assert_env_var_set
export -f assert_path_normalized
export -f assert_token_estimate_in_range
export -f assert_file_permissions
export -f assert_cache_control_set