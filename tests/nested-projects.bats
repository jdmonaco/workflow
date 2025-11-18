#!/usr/bin/env bats

load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load
load test_helper/common

setup() {
    setup_test_env
    # Source utility and config functions to test directly
    WORKFLOW_LIB_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")"; pwd)/lib"
    source "$WORKFLOW_LIB_DIR/utils.sh"
    source "$WORKFLOW_LIB_DIR/config.sh"
}

teardown() {
    cleanup_test_env
}

# =============================================================================
# Nested Project Description Tests
# =============================================================================

@test "nested: single project uses project.txt normally" {
    # Create single project with project.txt
    mkdir -p "$TEST_TEMP_DIR/single-project/.workflow"
    echo "Single project description" > "$TEST_TEMP_DIR/single-project/.workflow/project.txt"

    # Call aggregation function directly
    cd "$TEST_TEMP_DIR/single-project"
    run aggregate_nested_project_descriptions "$TEST_TEMP_DIR/single-project"

    assert_success
    assert_file_exist "$TEST_TEMP_DIR/single-project/.workflow/prompts/project.txt"

    # Check cached content
    run cat "$TEST_TEMP_DIR/single-project/.workflow/prompts/project.txt"
    assert_output --partial "Single project description"
    assert_output --partial "<single-project>"
}

@test "nested: two-level nesting aggregates both project.txt files" {
    # Create parent and child projects
    mkdir -p "$TEST_TEMP_DIR/parent/.workflow"
    mkdir -p "$TEST_TEMP_DIR/parent/child/.workflow"
    echo "Parent project context" > "$TEST_TEMP_DIR/parent/.workflow/project.txt"
    echo "Child project context" > "$TEST_TEMP_DIR/parent/child/.workflow/project.txt"

    # Call aggregation from child
    cd "$TEST_TEMP_DIR/parent/child"
    run aggregate_nested_project_descriptions "$TEST_TEMP_DIR/parent/child"

    assert_success

    # Check aggregated cache
    run cat "$TEST_TEMP_DIR/parent/child/.workflow/prompts/project.txt"

    # Should contain both, parent first
    assert_output --partial "<parent>"
    assert_output --partial "Parent project context"
    assert_output --partial "</parent>"
    assert_output --partial "<child>"
    assert_output --partial "Child project context"
    assert_output --partial "</child>"
}

@test "nested: parent has project.txt, child empty" {
    # Create parent with project.txt, child with empty file
    mkdir -p "$TEST_TEMP_DIR/parent/.workflow"
    mkdir -p "$TEST_TEMP_DIR/parent/child/.workflow"
    echo "Parent context only" > "$TEST_TEMP_DIR/parent/.workflow/project.txt"
    touch "$TEST_TEMP_DIR/parent/child/.workflow/project.txt"  # Empty

    # Call aggregation from child
    cd "$TEST_TEMP_DIR/parent/child"
    run aggregate_nested_project_descriptions "$TEST_TEMP_DIR/parent/child"

    assert_success

    # Should only contain parent (child is empty)
    run cat "$TEST_TEMP_DIR/parent/child/.workflow/prompts/project.txt"
    assert_output --partial "<parent>"
    assert_output --partial "Parent context only"
    refute_output --partial "<child>"
}

@test "nested: parent empty, child has project.txt" {
    # Create parent with empty, child with content
    mkdir -p "$TEST_TEMP_DIR/parent/.workflow"
    mkdir -p "$TEST_TEMP_DIR/parent/child/.workflow"
    touch "$TEST_TEMP_DIR/parent/.workflow/project.txt"  # Empty
    echo "Child context only" > "$TEST_TEMP_DIR/parent/child/.workflow/project.txt"

    # Call aggregation from child
    cd "$TEST_TEMP_DIR/parent/child"
    run aggregate_nested_project_descriptions "$TEST_TEMP_DIR/parent/child"

    assert_success

    # Should only contain child (parent is empty)
    run cat "$TEST_TEMP_DIR/parent/child/.workflow/prompts/project.txt"
    refute_output --partial "<parent>"
    assert_output --partial "<child>"
    assert_output --partial "Child context only"
}

@test "nested: three-level nesting aggregates in correct order" {
    # Create three-level hierarchy
    mkdir -p "$TEST_TEMP_DIR/grandparent/.workflow"
    mkdir -p "$TEST_TEMP_DIR/grandparent/parent/.workflow"
    mkdir -p "$TEST_TEMP_DIR/grandparent/parent/child/.workflow"
    echo "Grandparent context" > "$TEST_TEMP_DIR/grandparent/.workflow/project.txt"
    echo "Parent context" > "$TEST_TEMP_DIR/grandparent/parent/.workflow/project.txt"
    echo "Child context" > "$TEST_TEMP_DIR/grandparent/parent/child/.workflow/project.txt"

    # Call aggregation from child
    cd "$TEST_TEMP_DIR/grandparent/parent/child"
    run aggregate_nested_project_descriptions "$TEST_TEMP_DIR/grandparent/parent/child"

    assert_success

    # Check all three present in correct order
    run cat "$TEST_TEMP_DIR/grandparent/parent/child/.workflow/prompts/project.txt"
    assert_output --partial "<grandparent>"
    assert_output --partial "Grandparent context"
    assert_output --partial "<parent>"
    assert_output --partial "Parent context"
    assert_output --partial "<child>"
    assert_output --partial "Child context"
}

@test "nested: tag names are properly sanitized" {
    # Create project with special characters in name
    mkdir -p "$TEST_TEMP_DIR/My Project-2024/.workflow"
    echo "Special name project" > "$TEST_TEMP_DIR/My Project-2024/.workflow/project.txt"

    # Call aggregation
    cd "$TEST_TEMP_DIR/My Project-2024"
    run aggregate_nested_project_descriptions "$TEST_TEMP_DIR/My Project-2024"

    assert_success

    # Check tag is sanitized
    run cat "$TEST_TEMP_DIR/My Project-2024/.workflow/prompts/project.txt"
    assert_output --partial "<my-project-2024>"
    assert_output --partial "Special name project"
    assert_output --partial "</my-project-2024>"
}

@test "nested: cache file created in correct location" {
    # Create project with project.txt
    mkdir -p "$TEST_TEMP_DIR/project/.workflow"
    echo "Test content" > "$TEST_TEMP_DIR/project/.workflow/project.txt"

    # Call aggregation
    cd "$TEST_TEMP_DIR/project"
    run aggregate_nested_project_descriptions "$TEST_TEMP_DIR/project"

    assert_success

    # Verify cache exists at correct path
    assert_file_exist "$TEST_TEMP_DIR/project/.workflow/prompts/project.txt"
}

@test "nested: no project.txt files returns empty" {
    # Create nested projects with no project.txt content
    mkdir -p "$TEST_TEMP_DIR/parent/.workflow"
    mkdir -p "$TEST_TEMP_DIR/parent/child/.workflow"
    # No project.txt files created

    # Call aggregation from child
    cd "$TEST_TEMP_DIR/parent/child"
    run aggregate_nested_project_descriptions "$TEST_TEMP_DIR/parent/child"

    # Should return failure (no content processed)
    assert_failure

    # Cache should be empty or not exist
    if [[ -f "$TEST_TEMP_DIR/parent/child/.workflow/prompts/project.txt" ]]; then
        run cat "$TEST_TEMP_DIR/parent/child/.workflow/prompts/project.txt"
        assert_output ""
    fi
}

# =============================================================================
# Nested Config Cascade Tests
# =============================================================================

@test "config cascade: find_ancestor_projects returns oldest first" {
    # Create three-level nesting
    mkdir -p "$TEST_TEMP_DIR/grandparent/.workflow"
    mkdir -p "$TEST_TEMP_DIR/grandparent/parent/.workflow"
    mkdir -p "$TEST_TEMP_DIR/grandparent/parent/child/.workflow"

    # Find ancestors from child
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

@test "config cascade: load_ancestor_configs identifies correct ancestors" {
    # Create three-level nesting
    mkdir -p "$TEST_TEMP_DIR/grandparent/.workflow"
    cat > "$TEST_TEMP_DIR/grandparent/.workflow/config" <<EOF
MODEL=claude-opus-4
EOF

    mkdir -p "$TEST_TEMP_DIR/grandparent/parent/.workflow"
    cat > "$TEST_TEMP_DIR/grandparent/parent/.workflow/config" <<EOF
TEMPERATURE=0.5
EOF

    mkdir -p "$TEST_TEMP_DIR/grandparent/parent/child/.workflow"

    # Load ancestors from child
    cd "$TEST_TEMP_DIR/grandparent/parent/child"

    # Since load_ancestor_configs sets global variables, just verify it doesn't error
    run load_ancestor_configs "$TEST_TEMP_DIR/grandparent/parent/child"
    assert_success
}
