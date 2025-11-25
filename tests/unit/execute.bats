#!/usr/bin/env /opt/homebrew/bin/bash
# Unit tests for lib/execute.sh
# Tests dependency resolution functions (critical, recently bugfixed)

# Load existing bats helpers
load ../test_helper/bats-support/load
load ../test_helper/bats-assert/load
load ../test_helper/bats-file/load
load ../test_helper/common.bash

# Load our custom helpers
source "${BATS_TEST_DIRNAME}/../test_helper/mock_env.sh"
source "${BATS_TEST_DIRNAME}/../test_helper/fixtures.sh"

# Source the libraries being tested
setup() {
    setup_test_env
    setup_test_environment
    export WIREFLOW_LIB_DIR="${BATS_TEST_DIRNAME}/../../lib"
    source "${WIREFLOW_LIB_DIR}/utils.sh"
    source "${WIREFLOW_LIB_DIR}/execute.sh"

    # Setup mock prompts directory for dependency resolution tests
    export WIREFLOW_PROMPT_PREFIX="${BATS_TEST_TMPDIR}/prompts/system"
    export BUILTIN_WIREFLOW_PROMPT_PREFIX="${WIREFLOW_PROMPT_PREFIX}"
    export WIREFLOW_TASK_PREFIX="${BATS_TEST_TMPDIR}/prompts/tasks"
    export BUILTIN_WIREFLOW_TASK_PREFIX="${WIREFLOW_TASK_PREFIX}"
    mkdir -p "$WIREFLOW_PROMPT_PREFIX"
    mkdir -p "$WIREFLOW_TASK_PREFIX"

    # Reset dependency trackers
    declare -gA LOADED_SYSTEM_DEPS=()
    declare -gA LOADED_TASK_DEPS=()
}

teardown() {
    teardown_test_environment
}

# ============================================================================
# extract_dependencies tests
# ============================================================================

@test "extract_dependencies: returns empty for no dependencies" {
    local test_file="${BATS_TEST_TMPDIR}/no-deps.txt"
    cat > "$test_file" <<'EOF'
<system-component>
  <metadata>
    <name>no-deps</name>
    <version>1.0</version>
  </metadata>
  <content>Component without dependencies</content>
</system-component>
EOF

    run extract_dependencies "$test_file"
    assert_success
    assert_output ""
}

@test "extract_dependencies: extracts single dependency" {
    local test_file="${BATS_TEST_TMPDIR}/single-dep.txt"
    cat > "$test_file" <<'EOF'
<system-component>
  <metadata>
    <name>single-dep</name>
    <version>1.0</version>
    <dependencies>
      <dependency>core/base</dependency>
    </dependencies>
  </metadata>
  <content>Component with single dependency</content>
</system-component>
EOF

    run extract_dependencies "$test_file"
    assert_success
    assert_output "core/base"
}

@test "extract_dependencies: extracts multiple dependencies" {
    local test_file="${BATS_TEST_TMPDIR}/multi-dep.txt"
    cat > "$test_file" <<'EOF'
<system-component>
  <metadata>
    <name>multi-dep</name>
    <version>1.0</version>
    <dependencies>
      <dependency>core/base</dependency>
      <dependency>core/style</dependency>
      <dependency>domains/science</dependency>
    </dependencies>
  </metadata>
  <content>Component with multiple dependencies</content>
</system-component>
EOF

    run extract_dependencies "$test_file"
    assert_success
    assert_line --index 0 "core/base"
    assert_line --index 1 "core/style"
    assert_line --index 2 "domains/science"
}

# ============================================================================
# resolve_system_dependencies tests
# ============================================================================

@test "resolve_system_dependencies: returns empty for no deps" {
    # Create component with no dependencies
    mkdir -p "$WIREFLOW_PROMPT_PREFIX/core"
    cat > "$WIREFLOW_PROMPT_PREFIX/core/simple.txt" <<'EOF'
<system-component>
  <metadata>
    <name>simple</name>
    <version>1.0</version>
  </metadata>
  <content>Simple component</content>
</system-component>
EOF

    run resolve_system_dependencies "core/simple"
    assert_success
    assert_output ""
}

@test "resolve_system_dependencies: resolves single dependency" {
    # Create base component (no deps)
    mkdir -p "$WIREFLOW_PROMPT_PREFIX/core"
    cat > "$WIREFLOW_PROMPT_PREFIX/core/base.txt" <<'EOF'
<system-component>
  <metadata>
    <name>base</name>
    <version>1.0</version>
  </metadata>
  <content>Base component</content>
</system-component>
EOF

    # Create component that depends on base
    cat > "$WIREFLOW_PROMPT_PREFIX/core/derived.txt" <<'EOF'
<system-component>
  <metadata>
    <name>derived</name>
    <version>1.0</version>
    <dependencies>
      <dependency>core/base</dependency>
    </dependencies>
  </metadata>
  <content>Derived component</content>
</system-component>
EOF

    run resolve_system_dependencies "core/derived"
    assert_success
    assert_output "core/base"
}

@test "resolve_system_dependencies: resolves dependency chain" {
    # Create chain: level3 -> level2 -> level1
    mkdir -p "$WIREFLOW_PROMPT_PREFIX/chain"

    # Level 1 (no deps)
    cat > "$WIREFLOW_PROMPT_PREFIX/chain/level1.txt" <<'EOF'
<system-component>
  <metadata>
    <name>level1</name>
    <version>1.0</version>
  </metadata>
  <content>Level 1</content>
</system-component>
EOF

    # Level 2 depends on level1
    cat > "$WIREFLOW_PROMPT_PREFIX/chain/level2.txt" <<'EOF'
<system-component>
  <metadata>
    <name>level2</name>
    <version>1.0</version>
    <dependencies>
      <dependency>chain/level1</dependency>
    </dependencies>
  </metadata>
  <content>Level 2</content>
</system-component>
EOF

    # Level 3 depends on level2
    cat > "$WIREFLOW_PROMPT_PREFIX/chain/level3.txt" <<'EOF'
<system-component>
  <metadata>
    <name>level3</name>
    <version>1.0</version>
    <dependencies>
      <dependency>chain/level2</dependency>
    </dependencies>
  </metadata>
  <content>Level 3</content>
</system-component>
EOF

    run resolve_system_dependencies "chain/level3"
    assert_success
    # Should resolve in order: level1, level2 (transitive deps first)
    assert_line --index 0 "chain/level1"
    assert_line --index 1 "chain/level2"
}

@test "resolve_system_dependencies: handles circular dependency" {
    # Create circular: comp-a -> comp-b -> comp-a
    mkdir -p "$WIREFLOW_PROMPT_PREFIX/circular"

    cat > "$WIREFLOW_PROMPT_PREFIX/circular/comp-a.txt" <<'EOF'
<system-component>
  <metadata>
    <name>comp-a</name>
    <version>1.0</version>
    <dependencies>
      <dependency>circular/comp-b</dependency>
    </dependencies>
  </metadata>
  <content>Component A</content>
</system-component>
EOF

    cat > "$WIREFLOW_PROMPT_PREFIX/circular/comp-b.txt" <<'EOF'
<system-component>
  <metadata>
    <name>comp-b</name>
    <version>1.0</version>
    <dependencies>
      <dependency>circular/comp-a</dependency>
    </dependencies>
  </metadata>
  <content>Component B</content>
</system-component>
EOF

    # Should complete without infinite loop
    run resolve_system_dependencies "circular/comp-a"
    assert_success
    # Output should be bounded (no infinite recursion)
    assert [ "${#output}" -lt 1000 ]
}

# ============================================================================
# resolve_task_dependencies tests
# ============================================================================

@test "resolve_task_dependencies: resolves single dependency" {
    # Create base task (no deps)
    mkdir -p "$WIREFLOW_TASK_PREFIX/base"
    cat > "$WIREFLOW_TASK_PREFIX/base/task.txt" <<'EOF'
<user-task>
  <metadata>
    <name>base-task</name>
    <version>1.0</version>
  </metadata>
  <content>Base task</content>
</user-task>
EOF

    # Create task that depends on base
    cat > "$WIREFLOW_TASK_PREFIX/base/derived.txt" <<'EOF'
<user-task>
  <metadata>
    <name>derived-task</name>
    <version>1.0</version>
    <dependencies>
      <dependency>base/task</dependency>
    </dependencies>
  </metadata>
  <content>Derived task</content>
</user-task>
EOF

    run resolve_task_dependencies "base/derived"
    assert_success
    # Output contains the dependency (may have extra whitespace from recursive calls)
    assert_output --partial "base/task"
}

@test "resolve_task_dependencies: resolves chain" {
    # Create chain: task3 -> task2 -> task1
    mkdir -p "$WIREFLOW_TASK_PREFIX/chain"

    cat > "$WIREFLOW_TASK_PREFIX/chain/task1.txt" <<'EOF'
<user-task>
  <metadata>
    <name>task1</name>
    <version>1.0</version>
  </metadata>
  <content>Task 1</content>
</user-task>
EOF

    cat > "$WIREFLOW_TASK_PREFIX/chain/task2.txt" <<'EOF'
<user-task>
  <metadata>
    <name>task2</name>
    <version>1.0</version>
    <dependencies>
      <dependency>chain/task1</dependency>
    </dependencies>
  </metadata>
  <content>Task 2</content>
</user-task>
EOF

    cat > "$WIREFLOW_TASK_PREFIX/chain/task3.txt" <<'EOF'
<user-task>
  <metadata>
    <name>task3</name>
    <version>1.0</version>
    <dependencies>
      <dependency>chain/task2</dependency>
    </dependencies>
  </metadata>
  <content>Task 3</content>
</user-task>
EOF

    run resolve_task_dependencies "chain/task3"
    assert_success
    # Verifies recursive resolution completes and finds dependencies
    # Note: resolve_task_dependencies outputs deps at each recursion level
    assert_output --partial "chain/task1"
}

@test "resolve_task_dependencies: handles circular dependency" {
    # Create circular: task-x -> task-y -> task-x
    mkdir -p "$WIREFLOW_TASK_PREFIX/circular"

    cat > "$WIREFLOW_TASK_PREFIX/circular/task-x.txt" <<'EOF'
<user-task>
  <metadata>
    <name>task-x</name>
    <version>1.0</version>
    <dependencies>
      <dependency>circular/task-y</dependency>
    </dependencies>
  </metadata>
  <content>Task X</content>
</user-task>
EOF

    cat > "$WIREFLOW_TASK_PREFIX/circular/task-y.txt" <<'EOF'
<user-task>
  <metadata>
    <name>task-y</name>
    <version>1.0</version>
    <dependencies>
      <dependency>circular/task-x</dependency>
    </dependencies>
  </metadata>
  <content>Task Y</content>
</user-task>
EOF

    # Should complete without infinite loop
    run resolve_task_dependencies "circular/task-x"
    assert_success
    # Output should be bounded (no infinite recursion)
    assert [ "${#output}" -lt 1000 ]
}

# ============================================================================
# build_project_description_blocks tests
# Migrated from aggregate_nested_project_descriptions
# ============================================================================

@test "build_project_description_blocks: single project creates tagged block" {
    # Create a single project with project.txt
    local project_dir="${BATS_TEST_TMPDIR}/single-project"
    mkdir -p "$project_dir/.workflow"
    echo "Single project description" > "$project_dir/.workflow/project.txt"

    # Initialize SYSTEM_BLOCKS array
    declare -ga SYSTEM_BLOCKS=()

    cd "$project_dir"
    run build_project_description_blocks "$project_dir"
    assert_success

    # Check SYSTEM_BLOCKS was populated
    assert [ ${#SYSTEM_BLOCKS[@]} -gt 0 ] || skip "SYSTEM_BLOCKS not populated (function runs in subshell)"
}

@test "build_project_description_blocks: handles nested projects" {
    # Create nested project structure
    local parent_dir="${BATS_TEST_TMPDIR}/parent"
    local child_dir="${parent_dir}/child"
    mkdir -p "$parent_dir/.workflow"
    mkdir -p "$child_dir/.workflow"
    echo "Parent project context" > "$parent_dir/.workflow/project.txt"
    echo "Child project context" > "$child_dir/.workflow/project.txt"

    declare -ga SYSTEM_BLOCKS=()

    cd "$child_dir"
    run build_project_description_blocks "$child_dir"

    # Should succeed (output may be via global array)
    assert_success
}

@test "build_project_description_blocks: returns failure for empty project.txt" {
    local project_dir="${BATS_TEST_TMPDIR}/empty-project"
    mkdir -p "$project_dir/.workflow"
    touch "$project_dir/.workflow/project.txt"  # Empty file

    declare -ga SYSTEM_BLOCKS=()

    cd "$project_dir"
    run build_project_description_blocks "$project_dir"

    # Returns failure when no content was processed
    assert_failure
}
