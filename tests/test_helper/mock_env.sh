#!/usr/bin/env /opt/homebrew/bin/bash
# Mock Environment Setup for WireFlow Tests
# Provides functions to create isolated test environments with mock configurations,
# prompts, tasks, and project structures

# Create a complete mock project structure
# Args:
#   $1 - Test directory path
#   $2 - Project name (optional, defaults to "test-project")
setup_mock_project() {
    local test_dir="${1:?Test directory required}"
    local project_name="${2:-test-project}"

    # Create project structure
    mkdir -p "$test_dir"/{.workflow/{run,workflows},prompts,tasks}

    # Create project config
    cat > "$test_dir/.workflow/config" <<EOF
Project="$project_name"
Model="claude-3-5-sonnet-20241022"
Temperature="0.7"
MaxTokens="4096"
Stream="true"
EOF

    # Create project description
    cat > "$test_dir/.workflow/project.txt" <<EOF
Test project for automated testing.
This is a mock project used for testing wireflow functionality.
EOF

    echo "$test_dir"
}

# Create a mock global configuration directory
# Sets GLOBAL_CONFIG_DIR and GLOBAL_CONFIG_FILE to point to the mock directory
# Args:
#   $1 - Base directory for mock config (optional, uses in-repo tmp if available)
mock_global_config() {
    local repo_root
    repo_root="$(cd "${BATS_TEST_DIRNAME:-$(dirname "$0")}/../.."; pwd)"
    local default_tmp="$repo_root/tmp/mock-$$-${RANDOM}"
    local base_dir="${1:-${BATS_TEST_TMPDIR:-$default_tmp}}"
    mkdir -p "$base_dir"
    local config_dir="$base_dir/mock_config"

    # Create directory structure
    mkdir -p "$config_dir"/{prompts/{system,tasks},workflows}

    # Export for wireflow to use
    export GLOBAL_CONFIG_DIR="$config_dir"
    export GLOBAL_CONFIG_FILE="$config_dir/config"

    # Create mock global config
    cat > "$config_dir/config" <<EOF
Model="claude-3-5-sonnet-20241022"
Temperature="0.7"
MaxTokens="4096"
SystemPrompt="prompts/system/meta.txt"
Stream="false"
ApiKey="${ANTHROPIC_API_KEY:-mock-api-key}"
EOF

    # Install mock system prompts
    create_mock_system_prompts "$config_dir/prompts/system"

    # Install mock task templates
    create_mock_task_templates "$config_dir/prompts/tasks"

    echo "$config_dir"
}

# Create mock system prompt files
# Args:
#   $1 - System prompts directory
create_mock_system_prompts() {
    local prompts_dir="${1:?Prompts directory required}"

    # Meta prompt (always loaded)
    cat > "$prompts_dir/meta.txt" <<'EOF'
<system-component>
  <metadata>
    <name>meta</name>
    <version>1.0</version>
  </metadata>
  <content>
    You are a helpful AI assistant in a test environment.
    This is a mock system prompt for testing purposes.
  </content>
</system-component>
EOF

    # Core user component
    cat > "$prompts_dir/core-user.txt" <<'EOF'
<system-component>
  <metadata>
    <name>core-user</name>
    <version>1.0</version>
  </metadata>
  <content>
    Test user context and information.
  </content>
</system-component>
EOF

    # Component with dependencies
    cat > "$prompts_dir/with-deps.txt" <<'EOF'
<system-component>
  <metadata>
    <name>with-deps</name>
    <version>1.0</version>
    <dependencies>
      <dependency>core-user</dependency>
    </dependencies>
  </metadata>
  <content>
    Component that depends on core-user.
  </content>
</system-component>
EOF
}

# Create mock task template files
# Args:
#   $1 - Tasks directory
create_mock_task_templates() {
    local tasks_dir="${1:?Tasks directory required}"

    # General task template
    cat > "$tasks_dir/general.txt" <<'EOF'
<user-task>
  <metadata>
    <name>general</name>
    <version>1.0</version>
  </metadata>
  <content>
    <description>General task template for testing</description>
    <instructions>Process the input and provide output</instructions>
  </content>
</user-task>
EOF

    # Task with dependencies
    cat > "$tasks_dir/analysis.txt" <<'EOF'
<user-task>
  <metadata>
    <name>analysis</name>
    <version>1.0</version>
    <dependencies>
      <dependency>general</dependency>
    </dependencies>
  </metadata>
  <content>
    <description>Analysis task that extends general</description>
    <instructions>Analyze the provided content</instructions>
  </content>
</user-task>
EOF
}

# Create a mock workflow
# Args:
#   $1 - Project directory
#   $2 - Workflow name
#   $3 - Workflow content (optional)
create_mock_workflow() {
    local project_dir="${1:?Project directory required}"
    local workflow_name="${2:?Workflow name required}"
    local content="${3:-Mock workflow content for testing.}"

    local workflow_dir="$project_dir/.workflow/run/$workflow_name"
    mkdir -p "$workflow_dir"

    # Create workflow config
    cat > "$workflow_dir/config" <<EOF
Workflow="$workflow_name"
Model="claude-3-5-sonnet-20241022"
Temperature="0.5"
EOF

    # Create workflow prompt
    cat > "$workflow_dir/prompt.txt" <<EOF
Test workflow: $workflow_name
$content
EOF

    # Create workflow task
    cat > "$workflow_dir/task.txt" <<'EOF'
<user-task>
  <metadata>
    <name>test-task</name>
    <version>1.0</version>
  </metadata>
  <content>
    <description>Test task for workflow</description>
  </content>
</user-task>
EOF

    echo "$workflow_dir"
}

# Mock API call by creating expected output
# Args:
#   $1 - Output file path
#   $2 - Content (optional)
mock_api_response() {
    local output_file="${1:?Output file required}"
    local content="${2:-Mock API response for testing.}"

    mkdir -p "$(dirname "$output_file")"

    if [[ "$output_file" == *.json ]]; then
        # Create JSON response
        cat > "$output_file" <<EOF
{
  "id": "msg_mock_$(date +%s)",
  "type": "message",
  "content": [{
    "type": "text",
    "text": "$content"
  }],
  "model": "claude-3-5-sonnet-20241022",
  "usage": {
    "input_tokens": 100,
    "output_tokens": 50
  }
}
EOF
    else
        # Create text response
        echo "$content" > "$output_file"
    fi
}

# Setup environment variables for testing
# This ensures tests use mock directories instead of real ones
setup_test_environment() {
    # Use in-repo tmp directory
    local repo_root
    repo_root="$(cd "${BATS_TEST_DIRNAME:-$(dirname "$0")}/../.."; pwd)"
    local base_tmp="$repo_root/tmp/env-$$-${RANDOM}"
    mkdir -p "$base_tmp"

    # Save original values
    export ORIGINAL_GLOBAL_CONFIG_DIR="${GLOBAL_CONFIG_DIR:-}"
    export ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_PATH="${PATH:-}"

    # Set test values
    export WIREFLOW_TEST_MODE="true"
    export GLOBAL_CONFIG_DIR="${BATS_TEST_TMPDIR:-$base_tmp}/config"
    export GLOBAL_CONFIG_FILE="$GLOBAL_CONFIG_DIR/config"

    # Mock home directory if needed
    if [[ "${MOCK_HOME:-}" == "true" ]]; then
        export HOME="${BATS_TEST_TMPDIR:-$base_tmp}/home"
        mkdir -p "$HOME"
    fi

    # Ensure test directories exist
    mkdir -p "$GLOBAL_CONFIG_DIR"
}

# Restore original environment variables
teardown_test_environment() {
    if [[ -n "${ORIGINAL_GLOBAL_CONFIG_DIR}" ]]; then
        export GLOBAL_CONFIG_DIR="${ORIGINAL_GLOBAL_CONFIG_DIR}"
    else
        unset GLOBAL_CONFIG_DIR
    fi

    if [[ -n "${ORIGINAL_HOME}" ]]; then
        export HOME="${ORIGINAL_HOME}"
    fi

    if [[ -n "${ORIGINAL_PATH}" ]]; then
        export PATH="${ORIGINAL_PATH}"
    fi

    unset WIREFLOW_TEST_MODE
    unset GLOBAL_CONFIG_FILE
    unset ORIGINAL_GLOBAL_CONFIG_DIR
    unset ORIGINAL_HOME
    unset ORIGINAL_PATH
}

# Create a mock run directory with output
# Args:
#   $1 - Workflow directory
#   $2 - Run name (optional, defaults to timestamp)
#   $3 - Output content (optional)
create_mock_run() {
    local workflow_dir="${1:?Workflow directory required}"
    local run_name="${2:-$(date +%Y%m%d_%H%M%S)}"
    local output="${3:-Mock output from run.}"

    local project_dir="$(dirname "$(dirname "$workflow_dir")")"
    local workflow_name="$(basename "$workflow_dir")"
    local run_dir="$project_dir/run/$workflow_name/$run_name"

    mkdir -p "$run_dir"

    # Create output files
    echo "$output" > "$run_dir/output.txt"
    echo "$output" > "$run_dir/output.md"

    # Create metadata
    cat > "$run_dir/metadata.json" <<EOF
{
  "workflow": "$workflow_name",
  "run": "$run_name",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "model": "claude-3-5-sonnet-20241022",
  "tokens": {
    "input": 100,
    "output": 50
  }
}
EOF

    echo "$run_dir"
}

# Utility function to create nested projects
# Args:
#   $1 - Base directory
#   $2 - Nesting depth (default: 2)
create_nested_projects() {
    local base_dir="${1:?Base directory required}"
    local depth="${2:-2}"

    local current_dir="$base_dir"

    for ((i=1; i<=depth; i++)); do
        setup_mock_project "$current_dir" "project-level-$i"

        if ((i < depth)); then
            current_dir="$current_dir/nested"
            mkdir -p "$current_dir"
        fi
    done

    echo "$current_dir"
}

# Export functions for use in tests
export -f setup_mock_project
export -f mock_global_config
export -f create_mock_system_prompts
export -f create_mock_task_templates
export -f create_mock_workflow
export -f mock_api_response
export -f setup_test_environment
export -f teardown_test_environment
export -f create_mock_run
export -f create_nested_projects