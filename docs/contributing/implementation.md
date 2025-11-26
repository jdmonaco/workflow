# Workflow Implementation Details

Technical implementation details, module reference, and code-level specifics for the Workflow codebase.

**For development workflows, see [CLAUDE.md](https://github.com/jdmonaco/wireflow/blob/main/CLAUDE.md) (GitHub).**
**For architecture and design, see [architecture.md](architecture.md).**

## Module Reference

### lib/core.sh

**Subcommand implementations:**

- `init_project()` - Create `.workflow/` structure, handle nested projects
- `new_workflow()` - Create workflow directory with task.txt XML skeleton and config template
- `edit_workflow()` - Open files in editor (includes output if available)
- `list_workflows()` - List workflow directories (excludes config, prompts, output)
- `show_config()` - Display configuration with source tracking
- `run_workflow()` - Execute workflow with full context aggregation

**Key patterns:**

- Project root discovery via `find_project_root()`
- Subshell isolation for config extraction
- Interactive prompts with validation

### lib/config.sh

**Configuration management:**

- `ensure_global_config()` - Create `~/.config/wireflow/` on first use
- `create_default_global_config()` - Write default config and base.txt
- `load_global_config()` - Load with pass-through logic
- `extract_config()` - Parse config files (bash variable assignments)

**Pass-through implementation:**

```bash
# Only set if currently empty
if [[ -z "$MODEL" && -n "$value" ]]; then
    MODEL="$value"
fi
```

### lib/help.sh

**Help system:**

- One function per subcommand: `show_help_<subcommand>()`
- Git-style format: usage line, options, description, examples
- Sourced early, integrated via `help` subcommand and `-h` flags

### lib/task.sh

**Task mode execution:**

- Simplified config loading (global → project → CLI only)
- Temporary file management with trap cleanup
- Stdout default (vs file for run mode)
- No workflow dependencies or workflow config

**Key difference:**

```bash
# SYSTEM_PROMPTS_OVERRIDE applied AFTER config loading
# (Not before, or it gets overwritten)
if [[ -n "$SYSTEM_PROMPTS_OVERRIDE" ]]; then
    IFS=',' read -ra SYSTEM_PROMPTS <<< "$SYSTEM_PROMPTS_OVERRIDE"
fi
```

### lib/edit.sh

**Editor selection:**

- Checks `$VISUAL`, `$EDITOR`, platform defaults, common editors
- Falls back to `vi` (always available)
- Multi-file support: `edit_files file1 [file2 ...]`

### lib/utils.sh

**Utility functions:**

- `sanitize()` - Filename to XML tag conversion
- `find_project_root()` - Walk up directory tree for `.workflow/`
- `list_workflows()` - List workflow directories
- `escape_json()` - JSON string escaping for API payloads
- `build_text_content_block()` - Creates JSON content block from file with embedded XML metadata
- `build_document_content_block()` - Creates PDF content block with base64 encoding
- `detect_file_type()` - Detects text vs document/PDF vs office vs image files
- `convert_json_to_xml()` - Optional post-processing to create pseudo-XML files (custom converter)

**PDF document functions:**

- `validate_pdf_file()` - Check file size against 32MB limit
- `build_document_content_block()` - Base64 encode PDF and create content block

**Microsoft Office conversion functions:**

- `check_soffice_available()` - Detect LibreOffice installation
- `convert_office_to_pdf()` - Convert .docx/.pptx to PDF with mtime-based caching

**Vision API image functions:**

- `get_image_media_type()` - Map file extension to MIME type (image/jpeg, image/png, etc.)
- `get_image_dimensions()` - Extract width/height using ImageMagick identify
- `validate_image_file()` - Check against API limits (5MB, 8000x8000 px)
- `should_resize_image()` - Check if image exceeds 1568px on long edge
- `calculate_target_dimensions()` - Compute resize dimensions maintaining aspect ratio
- `resize_image()` - Resize using ImageMagick with geometry specification
- `cache_image()` - Cache resized images using hash-based IDs in CACHE_DIR
- `build_image_content_block()` - Create Vision API image block with base64 encoding

**Project discovery implementation:**

```bash
find_project_root() {
    local dir="$PWD"
    while [[ "$dir" != "$HOME" && "$dir" != "/" ]]; do
        if [[ -d "$dir/.workflow" ]]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}
```

Stops at `$HOME` or `/` to avoid escaping user space.

### lib/api.sh

**API functions:**

- `anthropic_validate()` - Validates API key configuration
- `anthropic_execute_single()` - Single-shot request with pager display
- `anthropic_execute_stream()` - Streaming request with real-time output
- `anthropic_count_tokens()` - Exact token counting via count_tokens endpoint

**Request construction:**

- Uses `jq` to build JSON payloads with content blocks
- Accepts `system_blocks_file` and `user_blocks_file` parameters
- Reads JSON arrays from files (avoids bash parameter parsing issues)

**Key implementation:**

- Uses `curl` with Anthropic Messages API
- Handles both streaming and non-streaming modes
- Supports prompt caching via `cache_control` in content blocks
- Returns actual token counts from response

### lib/execute.sh

**Shared execution logic:**

Eliminates duplication between run mode (wireflow.sh) and task mode (lib/task.sh) by extracting common execution functions. All functions are mode-aware with a `mode` parameter ("run" or "task") for mode-specific behavior.

**Functions:**

- `build_system_prompt()` - Builds JSON content blocks for system prompts
    - Concatenates prompt files from SYSTEM_PROMPTS array
    - Creates JSON block with cache_control for system prompts
    - Populates SYSTEM_BLOCKS array
    - Writes concatenated text to `.workflow/prompts/system.txt` for caching
- `build_project_description_block()` - Creates cached JSON block for project descriptions
- `build_current_date_block()` - Creates uncached JSON block for current date
- `estimate_tokens()` - Dual token estimation (heuristic + API)
    - No parameters (reads from JSON arrays in memory)
    - Heuristic character-based estimation for quick feedback
    - Image tokens: 1600 per image (conservative estimate for ~1.15 megapixels)
    - Calls `anthropic_count_tokens()` for exact API count (when API key available)
    - Displays comparison between heuristic and actual counts
- `handle_dry_run_mode()` - Saves JSON payloads for inspection
    - Saves 2 files: JSON request, JSON blocks breakdown
    - Opens in editor for inspection
    - Exits without making API call
- `build_prompts(system_file, project_root, task_source)` - Builds JSON structures
    - Calls block-building functions to populate SYSTEM_BLOCKS
    - Creates TASK_BLOCK for user message
    - No XML construction (JSON-first architecture)
- `aggregate_context(mode, project_root, workflow_dir)` - Builds JSON content blocks
    - Order: context PDFs → input PDFs → context text → dependencies → input text → images (stable → volatile)
    - Within each: FILES → PATTERN → CLI (stable → volatile)
    - PDF files → CONTEXT_PDF_BLOCKS or INPUT_PDF_BLOCKS (citable)
    - Text files → CONTEXT_BLOCKS, DEPENDENCY_BLOCKS, or INPUT_BLOCKS (citable)
    - Image files → IMAGE_BLOCKS (Vision API, not citable)
    - Automatic image processing: validation, resizing, caching, base64 encoding
    - Automatic Office conversion: .docx/.pptx → PDF with caching
    - Adds cache_control strategically (adaptive strategy based on content mix)
    - Embeds metadata as XML tags in block text content
    - Saves document-map.json for citations processing (all citable docs)
- `execute_api_request(mode, output_file, output_file_path)` - Unified API execution
    - Assembles content blocks arrays in optimized order
    - Order: context PDFs → input PDFs → context text → dependencies → input text → images → task
    - Writes JSON arrays to temporary files
    - Passes files to API functions (avoids bash parameter parsing issues)
    - Run mode: backs up existing output before API call, saves JSON files after completion
    - Task mode: displays to stdout in non-stream mode if no explicit file
    - Cleans up temporary files

**Design rationale:**

JSON-first architecture eliminates dual-track XML/JSON building, reducing complexity by ~150 lines. Pseudo-XML files optionally created via custom converter for human readability.

## Implementation Details

### Configuration Sourcing Safety

**Subshell isolation for config extraction:**

```bash
extract_parent_config() {
    # Source in subshell to avoid polluting current environment
    (
        source "$parent_config"
        echo "MODEL=${MODEL:-}"
        echo "TEMPERATURE=${TEMPERATURE:-}"
        # ...
    )
}
```

Prevents parent config from affecting current shell.

### Path Resolution Implementation

**Config patterns:**

```bash
# Expansion in project root context
local files
files=$(cd "$PROJECT_ROOT" && eval echo "$CONTEXT_PATTERN")
```

**CLI paths:**

```bash
# Stored separately, used as-is
CLI_CONTEXT_FILES+=("$file")  # Relative to PWD
```

**Why:** Ensures patterns resolve relative to project root regardless of PWD.

### Glob Expansion Timing

Patterns must expand in correct directory:

```bash
# Good - explicit context
(cd "$PROJECT_ROOT" && echo $PATTERN)

# Bad - expands in current directory
echo $PATTERN
```

### Hardlink Behavior

**Creation:**

```bash
ln "$source" "$hardlink"  # Not ln -s (symlink)
```

**Properties:**

- Both paths point to same inode
- Deleting one doesn't affect the other
- Visible in file browsers
- Works within same filesystem only

**Limitation:** Fails across filesystem boundaries (rare in practice).

**Fallback pattern:**

```bash
ln "$source" "$target" || {
    # Fallback: copy instead of hardlink
    cp "$source" "$target"
}
```

### Temporary File Cleanup

**Task mode pattern:**

```bash
temp_file=$(mktemp)
trap 'rm -f "$temp_file"' EXIT

# Use temp_file
# Automatically cleaned on exit (success or failure)
```

### Bash Version Requirements

**Minimum: Bash 4.0**

**Required features:**

- Associative arrays (4.0+)
- `[[ ]]` conditional expressions
- Process substitution
- `read -a` array reading

**Compatibility tested on:**

- macOS (bash 3.2 via system, 5.x via Homebrew)
- Linux (bash 4.x, 5.x)
- WSL (bash 4.x, 5.x)

**Development note:**

- Development environment PATH is configured to use Homebrew bash (`/opt/homebrew/bin/bash`) by default
- System bash (`/bin/bash`) is version 3.2 and lacks required features
- Tests require Homebrew bash 4.0+ for associative array support
- No need to explicitly call `/opt/homebrew/bin/bash` in Bash tool calls

### API Request Construction

**Implementation** (`lib/api.sh`):

```bash
# Read content blocks from files
system_blocks=$(<"${params[system_blocks_file]}")
user_blocks=$(<"${params[user_blocks_file]}")

# Build JSON payload with content blocks
payload=$(jq -n \
    --arg model "$MODEL" \
    --argjson max_tokens "$MAX_TOKENS" \
    --argjson temperature "$TEMPERATURE" \
    --argjson system "$system_blocks" \
    --argjson user_content "$user_blocks" \
    '{
        model: $model,
        max_tokens: $max_tokens,
        temperature: $temperature,
        system: $system,
        messages: [
            {
                role: "user",
                content: $user_content
            }
        ]
    }'
)
```

**File-based parameter passing:**

- Avoids bash variable expansion issues with large JSON strings
- Temporary files created by `execute_api_request()`, cleaned up after use
- Each content block contains metadata as embedded XML tags

**Streaming vs buffered:**

- Streaming: `stream: true` added to payload, parse SSE events
- Buffered: `stream: false`, single JSON response

### Output Format Hints

**For non-markdown formats:**

```bash
if [[ "$OUTPUT_FORMAT" != "md" && "$OUTPUT_FORMAT" != "markdown" ]]; then
    task_content="${task_content}\n\n<output-format>${OUTPUT_FORMAT}</output-format>"
fi
```

Guides LLM to generate in requested format.

### Token Estimation Algorithm

**Dual approach:**

1. **Heuristic (character-based):**

```bash
char_count=$(wc -c < "$file")
token_count=$((char_count / 4))
```

Simple approximation: ~4 chars per token (reasonable for English). Fast and requires no API call.

2. **Exact (API-based):**

Calls Anthropic's `/v1/messages/count_tokens` endpoint with full content blocks for precise counting.

**Display breakdown:**

- System prompts (heuristic)
- Task (heuristic)
- Input documents (heuristic)
- Context (heuristic)
- Total heuristic estimate
- Exact total from API (when API key available)
- Difference between heuristic and API count

**Note:** API count is typically higher due to:

- XML metadata headers in each block
- JSON structure overhead
- More accurate tokenization

## Testing Implementation

### Test File Organization

```
tests/
├── unit/                   # Function-level unit tests
│   ├── api.bats           # API validation, citations
│   ├── config.bats        # Config loading, cascade
│   ├── core.bats          # Task file resolution
│   ├── edit.bats          # Editor detection
│   ├── execute.bats       # Dependency resolution
│   ├── help.bats          # Help output
│   └── utils.bats         # Path/file utilities
├── integration/            # End-to-end command tests
│   ├── cat.bats           # cat command
│   ├── config.bats        # config command
│   ├── help.bats          # help/version commands
│   ├── init.bats          # init command
│   ├── list.bats          # list command
│   ├── new.bats           # new command
│   ├── run.bats           # run mode execution
│   └── task.bats          # task mode execution
├── test_helper/            # Bats support libraries
│   ├── common.bash        # Shared test setup
│   ├── mock_env.sh        # Environment mocking
│   ├── fixtures.sh        # Test fixture creation
│   └── assertions.sh      # Custom assertions
└── run-tests.sh            # Test runner script
```

**Test counts:** ~137 tests (95 unit + 42 integration)

### Common Test Patterns

```bash
setup() {
    setup_test_env  # Mock HOME, create temp dirs
    source "${WIREFLOW_LIB_DIR}/utils.sh"  # Source lib being tested
}

teardown() {
    cleanup_test_env  # Remove temp dirs
}

@test "function_name: specific behavior" {
    run function_name "arg1" "arg2"
    assert_success
    assert_output --partial "expected text"
}
```

### Mock API Calls

- Tests should not make real API calls
- Use `WIREFLOW_DRY_RUN="true"` to avoid API calls in tests
- Mock environment variables for configuration testing

## Technical Gotchas

### Subshell Isolation

Use subshells for config extraction to avoid polluting environment:

```bash
(source "$config_file"; echo "VAR=$VAR")  # Good - isolated
source "$config_file"  # Bad - affects current shell
```

### Array Handling in Config

**Correct:**

```bash
SYSTEM_PROMPTS=(base custom)
CONTEXT_FILES=("file1.md" "file2.txt")
```

**Incorrect:**

```bash
SYSTEM_PROMPTS="base,custom"  # String, not array
CONTEXT_FILES=["file1.md", "file2.txt"]  # JSON syntax, not bash
```

### Glob Expansion Context

Patterns must expand in correct directory:

```bash
# Good - explicit context
(cd "$PROJECT_ROOT" && echo $PATTERN)

# Bad - expands in current directory
echo $PATTERN
```

### Hardlink Filesystem Limitations

Hardlinks fail across filesystem boundaries:

```bash
ln "$source" "$target" || {
    # Fallback: copy instead of hardlink
    cp "$source" "$target"
}
```

### Streaming Interruption

Ctrl+C during streaming:

- Partial output preserved in file
- Trap ensures cleanup
- User sees partial results

## Implementation Notes

- System prompts use XML formatting for structured instructions
- `filecat()` adds visual separators and metadata
- Config files are sourced bash scripts (can include logic)
- CLI context augments (not replaces) config context
- Hardlinks updated atomically for safe concurrent access
- Token estimation is approximate (actual may vary ±5%)
- Don't run the full test suite any more than needed. Don't run it multiple times to process the output differently.
