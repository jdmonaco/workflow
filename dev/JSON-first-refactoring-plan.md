# JSON-First Refactoring Plan

**Branch:** `feature/json-first-refactoring`
**Status:** In Progress (stashed changes applied)
**Tests:** 210/229 passing (19 failures expected during refactoring)

## Overview

### Goal

Simplify the workflow implementation by removing dual-track XML/JSON building. The refactored architecture will:

1. Build **only JSON content blocks** during execution
2. Save JSON files to workflow directory
3. Use `yq` tool post-execution to convert JSON → XML for human readability (optional)
4. If `yq` unavailable, JSON files serve as the record

### Rationale

- **Simpler code**: Single build path, less duplication
- **Cleaner separation**: JSON for API, XML optional for humans
- **Reduced maintenance**: No parallel XML string construction
- **Better semantics**: documentcat/contextcat removed (were creating indexed wrappers, now unnecessary)
- **Graceful degradation**: Works without `yq`, just less readable

### Current State (Partially Complete)

**✅ Completed:**
1. Renamed files to use hyphens: `system-blocks.json`, `user-blocks.json`, `document-map.json`
2. Removed all `cat >> $input_file` and `cat >> $context_file` from aggregate_context()
3. Removed XML string building from build_prompts() (SYSTEM_PROMPT, USER_PROMPT construction)
4. Changed aggregate_context() signature: removed `input_file` and `context_file` parameters
5. Updated build_prompts() signature: removed `input_file` and `context_file` parameters
6. Fixed streaming delta type handling (backward compatible with tests)

**⚠️ Partially Complete:**
- File variable names changed but old variables still referenced
- Function signatures changed but call sites not all updated
- Tests expect old behavior (XML files, old signatures)

**❌ Not Started:**
- yq conversion function
- JSON file saving during execution
- Dry-run mode updates
- estimate_tokens() updates
- Complete test updates
- Documentation updates

## Detailed Implementation Plan

### Phase 1: Remove Legacy XML File Variables

**Files:** workflow.sh, lib/task.sh

**Changes:**
```bash
# Remove these variables:
INPUT_PROMPT_FILE="$WORKFLOW_DIR/input.txt"
CONTEXT_PROMPT_FILE="$WORKFLOW_DIR/context.txt"

# Keep only:
TASK_PROMPT_FILE="$WORKFLOW_DIR/task.txt"  # Still needed as source file
SYSTEM_PROMPT_FILE="$PROJECT_ROOT/.workflow/prompts/system.txt"  # For system-prompts building
```

**Update variable names:**
```bash
# Current (underscores):
JSON_BLOCKS_FILE="$WORKFLOW_DIR/content_blocks.json"
JSON_REQUEST_FILE="$WORKFLOW_DIR/request.json"
DOCUMENT_MAP_FILE="$WORKFLOW_DIR/document_map.json"

# New (hyphens):
SYSTEM_BLOCKS_FILE="$WORKFLOW_DIR/system-blocks.json"
USER_BLOCKS_FILE="$WORKFLOW_DIR/user-blocks.json"
REQUEST_JSON_FILE="$WORKFLOW_DIR/request.json"
DOCUMENT_MAP_FILE="$WORKFLOW_DIR/document-map.json"
```

### Phase 2: Update aggregate_context() Signature and Behavior

**Current Signature (Broken):**
```bash
aggregate_context() {
    local mode="$1"
    local project_root="$2"
    # No longer writes to files, only builds arrays
}
```

**Call Sites to Update:**
- `workflow.sh`: `aggregate_context "run" "$PROJECT_ROOT"`
- `lib/task.sh`: `aggregate_context "task" "$PROJECT_ROOT"`

**Behavior:**
- Initialize DOCUMENT_INDEX_MAP array
- Build CONTEXT_BLOCKS, DEPENDENCY_BLOCKS, INPUT_BLOCKS arrays
- Do NOT write any text files
- At end: save document-map.json

### Phase 3: Update build_prompts() Signature

**Current Signature (Broken):**
```bash
build_prompts() {
    local system_file="$1"
    local project_root="$2"
    local task_source="$3"
    # Only builds JSON blocks, no XML strings
}
```

**Call Sites to Update:**
- `workflow.sh`: `build_prompts "$SYSTEM_PROMPT_FILE" "$PROJECT_ROOT" "$TASK_PROMPT_FILE"`
- `lib/task.sh`: `build_prompts "$SYSTEM_PROMPT_FILE" "$PROJECT_ROOT" "$TASK_PROMPT"`

**Behavior:**
- Build SYSTEM_BLOCKS array (system-prompts, project-description, current-date)
- Build TASK_BLOCK
- Do NOT build SYSTEM_PROMPT or USER_PROMPT strings

### Phase 4: Save JSON Files During Execution

**Add to end of execute_api_request():**

```bash
# Save JSON block files for reference
# Run mode: save to workflow directory
# Task mode: temp files (already cleaned up by trap)

if [[ "$mode" == "run" ]]; then
    # Assemble and save system blocks
    printf '%s\n' "${SYSTEM_BLOCKS[@]}" | jq -s '.' > "$SYSTEM_BLOCKS_FILE"

    # Assemble and save user blocks
    local -a all_user_blocks=()
    for block in "${CONTEXT_BLOCKS[@]}" "${DEPENDENCY_BLOCKS[@]}" "${INPUT_BLOCKS[@]}"; do
        all_user_blocks+=("$block")
    done
    all_user_blocks+=("$TASK_BLOCK")
    printf '%s\n' "${all_user_blocks[@]}" | jq -s '.' > "$USER_BLOCKS_FILE"

    # Save complete request (already built for API)
    # This is the actual payload sent to API
    jq -n \
        --arg model "$MODEL" \
        --argjson max_tokens "$MAX_TOKENS" \
        --argjson temperature "$TEMPERATURE" \
        --argjson system "$system_blocks_json" \
        --argjson user_content "$user_blocks_json" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            temperature: $temperature,
            system: $system,
            messages: [{role: "user", content: $user_content}]
        }' > "$REQUEST_JSON_FILE"
fi

# document-map.json already saved by aggregate_context()
```

### Phase 5: Add yq Conversion Function

**New function in lib/utils.sh:**

```bash
# Convert JSON files to XML using yq (optional)
# Arguments:
#   $1 - workflow_dir: Directory containing JSON files
# Returns:
#   0 if conversion succeeded or yq unavailable (not an error)
#   1 if conversion failed
# Side effects:
#   Creates .xml files alongside .json files if yq available
convert_json_to_xml() {
    local workflow_dir="$1"

    # Check if yq is available
    if ! command -v yq >/dev/null 2>&1; then
        return 0  # Not an error, just skip conversion
    fi

    echo "Converting JSON files to XML for readability..."

    local files=(
        "system-blocks"
        "user-blocks"
        "request"
        "document-map"
    )

    for base in "${files[@]}"; do
        local json_file="$workflow_dir/${base}.json"
        local xml_file="$workflow_dir/${base}.xml"

        if [[ -f "$json_file" ]]; then
            if yq -p json -o xml "$json_file" > "$xml_file" 2>/dev/null; then
                echo "  Created ${base}.xml"
            else
                # Conversion failed, remove partial file
                rm -f "$xml_file"
            fi
        fi
    done

    return 0
}
```

**Call after execute_api_request():**
```bash
# In workflow.sh, after execute_api_request:
if [[ "$mode" == "run" ]]; then
    convert_json_to_xml "$WORKFLOW_DIR"
fi
```

### Phase 6: Update Dry-Run Mode

**Current dry-run saves:**
- dry-run-system.txt (XML)
- dry-run-user.txt (XML)
- dry-run-request.json
- dry-run-blocks.json

**New dry-run behavior:**

```bash
handle_dry_run_mode() {
    local mode="$1"
    local workflow_dir="$2"

    [[ "$DRY_RUN" != true ]] && return 0

    local dry_run_request
    local dry_run_system_blocks
    local dry_run_user_blocks

    if [[ "$mode" == "run" ]]; then
        dry_run_request="$workflow_dir/dry-run-request.json"
        dry_run_system_blocks="$workflow_dir/dry-run-system-blocks.json"
        dry_run_user_blocks="$workflow_dir/dry-run-user-blocks.json"
    else
        dry_run_request=$(mktemp -t dry-run-request.XXXXXX.json)
        dry_run_system_blocks=$(mktemp -t dry-run-system-blocks.XXXXXX.json)
        dry_run_user_blocks=$(mktemp -t dry-run-user-blocks.XXXXXX.json)
        trap "rm -f '$dry_run_request' '$dry_run_system_blocks' '$dry_run_user_blocks'" EXIT
    fi

    # Save JSON files (same logic as execute_api_request)
    printf '%s\n' "${SYSTEM_BLOCKS[@]}" | jq -s '.' > "$dry_run_system_blocks"

    local -a all_user_blocks=()
    for block in "${CONTEXT_BLOCKS[@]}" "${DEPENDENCY_BLOCKS[@]}" "${INPUT_BLOCKS[@]}"; do
        all_user_blocks+=("$block")
    done
    all_user_blocks+=("$TASK_BLOCK")
    printf '%s\n' "${all_user_blocks[@]}" | jq -s '.' > "$dry_run_user_blocks"

    # Build request JSON
    local system_blocks_json
    system_blocks_json=$(<"$dry_run_system_blocks")
    local user_blocks_json
    user_blocks_json=$(<"$dry_run_user_blocks")

    jq -n \
        --arg model "$MODEL" \
        --argjson max_tokens "$MAX_TOKENS" \
        --argjson temperature "$TEMPERATURE" \
        --argjson system "$system_blocks_json" \
        --argjson user_content "$user_blocks_json" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            temperature: $temperature,
            system: $system,
            messages: [{role: "user", content: $user_content}]
        }' > "$dry_run_request"

    # Try to convert to XML if yq available
    local files_to_open=()

    if command -v yq >/dev/null 2>&1; then
        echo "Converting to XML for readability..."

        if yq -p json -o xml "$dry_run_request" > "${dry_run_request%.json}.xml" 2>/dev/null; then
            files_to_open+=("${dry_run_request%.json}.xml")
        else
            files_to_open+=("$dry_run_request")
        fi

        # Optionally convert blocks files too
        if yq -p json -o xml "$dry_run_system_blocks" > "${dry_run_system_blocks%.json}.xml" 2>/dev/null; then
            files_to_open+=("${dry_run_system_blocks%.json}.xml")
        fi
        if yq -p json -o xml "$dry_run_user_blocks" > "${dry_run_user_blocks%.json}.xml" 2>/dev/null; then
            files_to_open+=("${dry_run_user_blocks%.json}.xml")
        fi
    else
        files_to_open=("$dry_run_request" "$dry_run_system_blocks" "$dry_run_user_blocks")
    fi

    echo "Dry-run mode: Files saved for inspection"
    for file in "${files_to_open[@]}"; do
        echo "  $(basename "$file")"
    done
    echo ""

    if [[ "$COUNT_TOKENS" == true ]]; then
        read -p "Press Enter to inspect in editor (or Ctrl+C to cancel): " -r
        echo ""
    fi

    edit_files "${files_to_open[@]}"
    exit 0
}
```

### Phase 7: Update estimate_tokens()

**Current implementation:** Reads from XML files

**New implementation:** Calculate from JSON arrays in memory

```bash
estimate_tokens() {
    # Skip if not requested
    [[ "$COUNT_TOKENS" != true ]] && return 0

    # Estimate from JSON arrays (already in memory)
    # System tokens
    local system_json
    system_json=$(printf '%s\n' "${SYSTEM_BLOCKS[@]}" | jq -s '.')
    local system_chars
    system_chars=$(echo "$system_json" | wc -c)
    local systc=$((system_chars / 4))
    echo "Estimated system tokens: $systc"

    # Task tokens
    local task_chars
    task_chars=$(echo "$TASK_BLOCK" | wc -c)
    local tasktc=$((task_chars / 4))
    echo "Estimated task tokens: $tasktc"

    # Context tokens
    local context_chars=0
    for block in "${CONTEXT_BLOCKS[@]}" "${DEPENDENCY_BLOCKS[@]}"; do
        context_chars=$((context_chars + $(echo "$block" | wc -c)))
    done
    local contexttc=$((context_chars / 4))
    echo "Estimated context tokens: $contexttc"

    # Input tokens
    local input_chars=0
    for block in "${INPUT_BLOCKS[@]}"; do
        input_chars=$((input_chars + $(echo "$block" | wc -c)))
    done
    local inputtc=$((input_chars / 4))
    echo "Estimated input documents tokens: $inputtc"

    # Total
    local total_tokens=$((systc + tasktc + inputtc + contexttc))
    echo "Estimated total input tokens (heuristic): $total_tokens"
    echo ""

    # Call Anthropic API for exact count (already implemented, unchanged)
    # ...existing API counting code...

    if [[ "$DRY_RUN" == false ]]; then
        exit 0
    fi

    return 0
}
```

### Phase 8: Update Tests

**19 failing tests** expect XML files (input.txt, context.txt). Update to expect JSON files or check execution success without file assertions.

**Test Categories:**

1. **Context file tests** (9 failing):
   - Remove assertions for context.txt
   - Either: assert JSON files exist, or just verify command succeeds

2. **Input file tests** (9 failing):
   - Remove assertions for input.txt
   - Either: assert JSON files exist, or just verify command succeeds

3. **Dependency tests** (1 failing):
   - Update for new file structure

**Example test updates:**

```bash
# Before:
assert_file_exists ".workflow/test-workflow/input.txt"
run cat .workflow/test-workflow/input.txt
assert_output --partial "Dataset 1 content"

# After (Option 1 - Check JSON):
assert_file_exists ".workflow/test-workflow/user-blocks.json"
run jq -r '.[].source.data // .[].text' .workflow/test-workflow/user-blocks.json
assert_output --partial "Dataset 1 content"

# After (Option 2 - Just verify success):
# Remove file assertions, just check command succeeds
assert_success
```

**Tests to update:**

```
not ok 110 run: creates context file
not ok 117 run: aggregates context from CONTEXT_PATTERN (relative to project root)
not ok 118 run: CONTEXT_PATTERN works from subdirectory
not ok 119 run: aggregates context from CONTEXT_FILES (relative to project root)
not ok 120 run: aggregates context from DEPENDS_ON
not ok 121 run: CLI --context-file is relative to PWD
not ok 122 run: CLI --context-file from subdirectory is relative to subdirectory
not ok 123 run: CLI --context-pattern is relative to PWD
not ok 124 run: combines multiple context sources
not ok 143 run: workflow chain with dependencies executes in order
not ok 144 run: handles cross-format dependencies
not ok 146 run: CONTEXT_PATTERN with brace expansion
not ok 147 run: aggregates INPUT_PATTERN using documentcat
not ok 148 run: aggregates INPUT_FILES using documentcat
not ok 149 run: separates INPUT_* from CONTEXT_*
not ok 150 run: INPUT_PATTERN works from subdirectory (project-relative)
not ok 151 run: CLI --input-file works (PWD-relative)
not ok 152 run: CLI --input-pattern works
not ok 153 run: creates input.txt file
```

**Recommendation:** Simplify most tests to just verify command success. Only check JSON file content for critical tests that verify specific functionality.

### Phase 9: Remove Legacy Code

**Remove from lib/execute.sh:**

1. `SYSTEM_PROMPT` and `USER_PROMPT` variable assignments
2. escape_json() calls for SYSTEM_JSON and USER_JSON (no longer needed)
3. Any remaining references to input_file/context_file in function bodies

**Check for:**
```bash
grep -r "SYSTEM_PROMPT\|USER_PROMPT" lib/
grep -r "input_file\|context_file" lib/execute.sh
grep -r "INPUT_PROMPT_FILE\|CONTEXT_PROMPT_FILE" workflow.sh lib/task.sh
```

### Phase 10: Add yq Conversion and Integration

**Add to lib/utils.sh** (see Phase 5 for function code)

**Call after successful execution:**

In `workflow.sh`, after execute_api_request():
```bash
# =============================================================================
# Post-Execution: Convert JSON to XML (optional, for readability)
# =============================================================================

convert_json_to_xml "$WORKFLOW_DIR"
```

In lib/task.sh, after execute_api_request():
```bash
# Task mode: Only convert if --output-file specified
if [[ -n "$OUTPUT_FILE_PATH" ]]; then
    local output_dir
    output_dir=$(dirname "$OUTPUT_FILE")
    # Note: temp files are in temp dir, conversion would be pointless
    # Skip conversion for task mode
fi
```

### Phase 11: Update Documentation

**CLAUDE.md updates:**

1. **System Prompt Composition** section:
   - Remove XML structure documentation
   - Document JSON-only building
   - Document yq conversion as optional post-processing

2. **User Prompt Composition** section:
   - Remove XML structure documentation
   - Document JSON content blocks structure
   - Note: XML files created via yq if available

3. **Module Reference - lib/execute.sh:**
   - Update build_prompts() signature
   - Update aggregate_context() signature
   - Document yq conversion

4. **Module Reference - lib/utils.sh:**
   - Add convert_json_to_xml() documentation
   - Note documentcat/contextcat are legacy (kept for backward compat if needed)

**User-facing docs:** (if any exist)
- Document that yq is optional
- JSON files are the canonical record
- XML files are convenience views

### Phase 12: Final Testing and Validation

**Comprehensive test run:**
```bash
bats tests/
```

**Should see:** All 229 tests passing

**Manual verification:**
```bash
# With yq installed:
wfw run test-workflow --dry-run
# Should see: request.xml, system-blocks.xml, user-blocks.xml files

# Without yq:
which yq && sudo mv $(which yq) $(which yq).bak  # Temporarily hide yq
wfw run test-workflow --dry-run
# Should see: only .json files, no errors

# Restore yq:
sudo mv $(which yq).bak $(which yq)
```

## File Structure After Refactoring

### Run Mode Files
```
.workflow/
  <workflow-name>/
    task.txt                    # Source file (user-edited)
    system-blocks.json          # System content blocks
    user-blocks.json            # User content blocks (context+deps+input+task)
    request.json                # Complete API request payload
    document-map.json           # Citations index mapping
    system-blocks.xml           # Optional (if yq available)
    user-blocks.xml             # Optional (if yq available)
    request.xml                 # Optional (if yq available)
    document-map.xml            # Optional (if yq available)
    output.md                   # API response
    citations.md                # Citations details (if ENABLE_CITATIONS=true)
    dry-run-request.json        # Dry-run files (if --dry-run)
    dry-run-system-blocks.json
    dry-run-user-blocks.json
    dry-run-*.xml               # Optional (if yq available)
```

### Task Mode Files
- All JSON files are temp files (cleaned up on exit)
- No XML conversion (pointless for temp files)
- If --output-file: output file created, possibly citations.md

## Migration Notes

**Breaking changes:**
- XML files (input.txt, context.txt) no longer created by default
- XML files only created if yq available (optional)
- JSON files are now canonical reference

**Backward compatibility:**
- documentcat/contextcat functions kept in lib/utils.sh (unused internally)
- API behavior unchanged
- Output files unchanged
- Config format unchanged

**Dependencies:**
- New optional dependency: `yq` (for XML conversion)
- Graceful degradation if not available

## Implementation Checklist

- [ ] Phase 1: Remove legacy XML file variables
- [ ] Phase 2: Update aggregate_context() signature/calls
- [ ] Phase 3: Update build_prompts() signature/calls
- [ ] Phase 4: Save JSON files during execution
- [ ] Phase 5: Add yq conversion function
- [ ] Phase 6: Update dry-run mode
- [ ] Phase 7: Update estimate_tokens()
- [ ] Phase 8: Update all 19 failing tests
- [ ] Phase 9: Remove legacy code (SYSTEM_PROMPT, USER_PROMPT vars)
- [ ] Phase 10: Integrate yq conversion calls
- [ ] Phase 11: Update documentation
- [ ] Phase 12: Final testing and validation

## Success Criteria

- [ ] All 229 tests passing
- [ ] JSON files created and valid
- [ ] XML files created if yq available
- [ ] No XML files if yq unavailable (no errors)
- [ ] Dry-run mode works with both JSON and XML
- [ ] Token estimation works from JSON arrays
- [ ] Citations still functional
- [ ] All existing workflows/features unaffected

## Notes for Next Session

**Branch:** `feature/json-first-refactoring`

**Starting point:**
```bash
git checkout feature/json-first-refactoring
git status  # Should show modified files
```

**Current failures:** 19 tests failing (expected, need updates)

**Resume from:** Phase 1 (remove legacy variables)

**Key insight:** The refactoring is partially complete. The core logic is sound, but function signatures changed without updating all call sites and tests. Systematically work through phases 1-12 to complete the refactoring.

**Testing strategy:** Run tests frequently during refactoring to catch issues early. Fix one category of failures at a time (context tests, then input tests, then dependency tests).
