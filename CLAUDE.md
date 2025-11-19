# Workflow - Developer Guide

Technical reference for developers working on the Workflow codebase.

**For user documentation, see `docs/` directory and README.md.**

## Architecture

### Overview

Workflow is a modular bash application for AI-assisted project development using the Anthropic Messages API.

**Design Principles:**
- Git-like project discovery (walk up directory tree for `.workflow/`)
- Configuration cascade with transparent pass-through inheritance
- Modular library structure for maintainability
- Safe execution (backups, atomic writes, cleanup traps)

### Module Structure

```
workflow.sh              # Main entry point, argument parsing, subcommand dispatch
lib/
├── core.sh             # Subcommand implementations (init, new, edit, list, config, run)
├── config.sh           # Configuration loading and cascade logic
├── help.sh             # Help text for all subcommands
├── task.sh             # Task mode (lightweight execution without workflow dirs)
├── edit.sh             # Cross-platform editor selection
├── execute.sh          # Shared execution logic (prompts, context, API requests)
├── utils.sh            # Utilities (file processing, project discovery, sanitization)
└── api.sh              # Anthropic API interaction (streaming and batch)
tests/
├── test_helper/        # Bats support libraries (git submodules)
├── *.bats             # Test files (205 tests)
└── common.sh          # Shared test utilities
```

### Project Structure

User projects contain a `.workflow/` directory:

```
project-root/
├── .workflow/
│   ├── config                    # Project-level configuration
│   ├── project.txt               # Optional project description
│   ├── prompts/
│   │   ├── system.txt            # Cached system prompt
│   │   └── project.txt           # Cached nested project descriptions
│   ├── output/                   # Hardlinks to workflow outputs
│   │   └── <name>.<format>       # → ../<name>/output.<format>
│   └── <name>/                   # Individual workflows
│       ├── config                # Workflow configuration
│       ├── task.txt              # Task prompt
│       ├── context/              # Optional context files
│       ├── output.<format>       # Primary output
│       └── output-TIMESTAMP.<format>  # Backup outputs
└── (project files...)
```

## Core Implementations

### Configuration Cascade

**Multi-tier cascade with pass-through:**

1. Global defaults (hardcoded in `lib/config.sh`)
2. Global config (`~/.config/workflow/config`, auto-created on first use)
3. Ancestor project configs (grandparent → parent, oldest to newest)
4. Current project config (`.workflow/config`)
5. Workflow config (`.workflow/<name>/config`)
6. CLI flags (highest priority)

**Pass-Through Mechanism:**

- Empty value (`MODEL=`) → Inherit from parent tier
- Explicit value (`MODEL="claude-opus-4"`) → Override parent, decoupled from changes

**Implementation:**

```bash
# In load_ancestor_configs(), apply non-empty values from each ancestor
if [[ -n "$value" ]]; then
    MODEL="$value"
    CONFIG_SOURCE_MAP[MODEL]="$ancestor_path"
fi
```

**Benefits:**
- Change global default → affects all empty configs
- Explicit values stay independent
- Easy to reset: set to empty to restore pass-through
- Nested projects inherit from ALL ancestors in the tree

**Nested Project Configuration:**

When running workflows in nested projects:
- `find_ancestor_projects()` walks up the directory tree to find all `.workflow/` directories
- `load_ancestor_configs()` loads configs from oldest to newest ancestor
- `CONFIG_SOURCE_MAP` tracks which ancestor (or tier) set each value
- Display functions (`config_project`, `config_workflow`) show full cascade with ancestor paths
- Each project can override ancestor values or pass through with empty values

When initializing a new nested project:
- `init_project()` detects parent project and displays inherited values
- Creates separate workflow namespace
- Stub config shows inherited values in comments for reference

### Path Resolution

**Design:** Config paths relative to project root, CLI paths relative to PWD

**Implementation:**

**Config paths** (`CONTEXT_PATTERN`, `CONTEXT_FILES`):
```bash
# Glob expansion in subshell
(cd "$PROJECT_ROOT" && eval echo "$CONTEXT_PATTERN")

# File paths prepended
for file in "${CONTEXT_FILES[@]}"; do
    full_path="$PROJECT_ROOT/$file"
done
```

**CLI paths** (`--context-file`, `--context-pattern`):
```bash
# Stored separately, used as-is
CLI_CONTEXT_FILES+=("$file")  # Relative to PWD
```

**Processing order:**
1. Config CONTEXT_PATTERN (project-relative)
2. CLI --context-pattern (PWD-relative)
3. Config CONTEXT_FILES (project-relative)
4. CLI --context-file (PWD-relative)

### Input and Context Aggregation

**Semantic separation:**

- **INPUT documents** (`INPUT_PATTERN`, `INPUT_FILES`): Primary documents to be analyzed or transformed
- **CONTEXT materials** (`CONTEXT_PATTERN`, `CONTEXT_FILES`, `DEPENDS_ON`): Supporting information and references

**Three aggregation methods (applies to both INPUT and CONTEXT):**

1. **Glob patterns:** Bash glob expansion, multiple files
2. **Explicit files:** Array of specific paths
3. **Workflow dependencies:** Include outputs via hardlinks (CONTEXT only)

**File processing functions:**

```bash
documentcat() {
    # For INPUT documents
    # Sequential indexing: <document index="1">, <document index="2">
    # Includes absolute source path in <source> tag
    # Wraps content in <document_content> tags
}

contextcat() {
    # For CONTEXT files
    # No indexing, each file in <context-file> tag
    # Includes absolute source path in <source> tag
    # Wraps content in <context_content> tags
}

filecat() {
    # Legacy function, uses contextcat() for backward compatibility
}
```

**Dependency resolution:**

```bash
# Reads from .workflow/output/ hardlinks
# Dependencies always go to CONTEXT (not INPUT)
for dep in "${DEPENDS_ON[@]}"; do
    dep_file=$(ls "$PROJECT_ROOT/.workflow/output/$dep".* 2>/dev/null)
done
```

**Nested Project Descriptions:**

```bash
aggregate_nested_project_descriptions() {
    # Finds all ancestor projects
    # Aggregates their project.txt files (oldest first)
    # Wraps each in XML tags using sanitized directory name
    # Caches to .workflow/prompts/project.txt
    # Used in both workflow.sh and lib/task.sh
}
```

### System Prompt Composition

**Dual-track architecture:** Builds both XML text files (for debugging) and JSON content blocks (for API).

**Build process (every run):**

1. Load prompts from `$WORKFLOW_PROMPT_PREFIX/{name}.txt`
2. Concatenate in order specified by `SYSTEM_PROMPTS` array
3. Create JSON content block with `cache_control: {type: "ephemeral"}`
4. Add to `SYSTEM_BLOCKS` array
5. Write XML version to `.workflow/prompts/system.txt` for debugging
6. Add project-description block (if exists) with cache_control
7. Add current-date block (without cache_control - intentionally volatile)
8. Use cached XML version as fallback if rebuild fails

**XML structure (for debugging):**

```xml
<system>
  <system-prompts>
    [Concatenated prompt files from SYSTEM_PROMPTS array]
  </system-prompts>

  <project-description>
    [Nested project descriptions if project.txt exists]
  </project-description>

  <current-date>
    [UTC date in YYYY-MM-DD format]
  </current-date>
</system>
```

**JSON content blocks (for API):**

```json
[
  {
    "type": "text",
    "text": "[concatenated system prompts]",
    "cache_control": {"type": "ephemeral"}
  },
  {
    "type": "text",
    "text": "[project descriptions]",
    "cache_control": {"type": "ephemeral"}
  },
  {
    "type": "text",
    "text": "Today's date: YYYY-MM-DD"
  }
]
```

**Cache breakpoints:** System prompts and project descriptions are cached (most stable), date is not cached (changes daily).

**Date format change:** Changed from datetime to date-only to prevent minute-by-minute cache invalidation.

### User Prompt Composition

**Dual-track architecture:** Builds both XML text files (for debugging) and JSON content blocks (for API).

**XML structure (for debugging):**

```xml
<user>
  <documents>
    [Input documents from INPUT_PATTERN and INPUT_FILES]
    [Each wrapped in <document index="N"> with <source> and <document_content>]
  </documents>

  <context>
    [Context files from CONTEXT_PATTERN, CONTEXT_FILES, and DEPENDS_ON]
    [Each wrapped in <context-file> with <source> and <context_content>]
  </context>

  <task>
    [Task content from task.txt or inline specification]
  </task>
</user>
```

**JSON content blocks (for API):**

Each file becomes its own content block in the order: context → dependencies → input → task

```json
[
  // Context files (each file is a separate block)
  {"type": "text", "text": "<metadata type=\"context\" source=\"...\"></metadata>\n\n[file content]"},
  {"type": "text", "text": "<metadata type=\"context\" source=\"...\"></metadata>\n\n[file content]", "cache_control": {"type": "ephemeral"}},

  // Dependencies (each workflow output is a separate block)
  {"type": "text", "text": "<metadata type=\"dependency\" workflow=\"name\" source=\"...\"></metadata>\n\n[file content]", "cache_control": {"type": "ephemeral"}},

  // Input documents (each file is a separate block)
  {"type": "text", "text": "<metadata type=\"input\" source=\"...\"></metadata>\n\n[file content]"},
  {"type": "text", "text": "<metadata type=\"input\" source=\"...\"></metadata>\n\n[file content]", "cache_control": {"type": "ephemeral"}},

  // Task (single block, no cache_control - most volatile)
  {"type": "text", "text": "[task content]"}
]
```

**Aggregation order (stable → volatile):**

1. **Context files:** CONTEXT_FILES → CONTEXT_PATTERN → CLI_CONTEXT_FILES → CLI_CONTEXT_PATTERN
2. **Dependencies:** DEPENDS_ON workflow outputs
3. **Input documents:** INPUT_FILES → INPUT_PATTERN → CLI_INPUT_FILES → CLI_INPUT_PATTERN
4. **Task:** Always last

**Cache breakpoints:** Maximum of 4 breakpoints placed at semantic boundaries:
- End of context files section
- End of dependencies section
- End of input documents section
- Task has no cache_control (most volatile)

**Metadata embedding:** Each file's metadata (type, source, workflow name) is embedded as XML tags at the start of the text content, not as separate JSON fields (Anthropic API doesn't accept extra fields).

**Section rules:**
- `<documents>` XML section only appears if INPUT_* sources are configured
- `<context>` XML section only appears if CONTEXT_* or DEPENDS_ON sources are configured
- `<task>` section always present
- Content blocks are created for all files regardless of XML sections

### API Interaction

**Location:** `lib/api.sh`

**JSON-first architecture:** Content blocks are constructed and passed to API functions via temporary files (avoids bash parameter parsing issues with large JSON payloads).

**Streaming mode:**
- Uses `curl` with chunked transfer encoding
- Parses SSE (Server-Sent Events) format
- Writes incrementally to output file
- Real-time terminal display

**Batch mode:**
- Single request, buffers entire response
- Atomic file write
- Opens in pager when complete

**Request construction:**
```bash
# Build JSON payload with content blocks
jq -n \
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
        messages: [{role: "user", content: $user_content}]
    }'
```

**Parameter passing:** System and user content blocks are passed via temporary files to avoid bash variable expansion issues.

**Token Counting API:** Dedicated endpoint `/v1/messages/count_tokens` provides exact token counts.

### Token Estimation

**Dual approach:** Both heuristic estimation and exact API counting.

**Heuristic formula:**

```bash
token_count=$(( char_count / 4 ))
```

Simple character-based approximation (reasonable for English text).

**API counting:**

```bash
anthropic_count_tokens \
    api_key="$ANTHROPIC_API_KEY" \
    model="$MODEL" \
    system_blocks_file="$temp_system" \
    user_blocks_file="$temp_user"
```

Calls Anthropic's `/v1/messages/count_tokens` endpoint for exact counts.

**Display:**
- System prompts tokens (heuristic)
- Task tokens (heuristic)
- Input documents tokens (heuristic)
- Context tokens (heuristic)
- Total heuristic estimate
- Exact total from API (when ANTHROPIC_API_KEY is set)
- Comparison between heuristic and API count

### Output Management

**Hardlink creation:**

```bash
# Primary location
output_file=".workflow/$workflow_name/output/$workflow_name.$format"

# Create hardlink
ln "$output_file" ".workflow/output/$workflow_name.$format"
```

**Why hardlinks:**
- Visible in file browsers (unlike symlinks)
- Single data storage (not duplication)
- Atomic updates

**Backup strategy:**

```bash
# Before overwriting
if [[ -f "$output_file" ]]; then
    timestamp=$(date +%Y%m%d%H%M%S)
    backup_file="${output_file%.*}-${timestamp}.${output_file##*.}"
    mv "$output_file" "$backup_file"
fi
```

**Format-specific post-processing:**
- Markdown: `mdformat` if available
- JSON: `jq '.'` for pretty-printing if available
- Others: No processing

### Prompt Caching

**Implementation:** Anthropic prompt caching with ephemeral cache breakpoints.

**Architecture:**
- Dual-track: XML text files for debugging, JSON content blocks for API
- Each file becomes its own content block (enables future PDF support)
- Metadata embedded as XML tags within text content
- Cache breakpoints at semantic boundaries (maximum 4)

**Cache breakpoint strategy:**

1. **System prompts** (most stable) - `cache_control: {type: "ephemeral"}`
2. **Project descriptions** (stable) - `cache_control: {type: "ephemeral"}`
3. **Context files** (medium stability) - cache_control on last block
4. **Dependencies** (medium stability) - cache_control on last block
5. **Input documents** (volatile) - cache_control on last block
6. **Task** (most volatile) - no cache_control

**Aggregation order:** Stable → volatile within each category:
- Context: CONTEXT_FILES → CONTEXT_PATTERN → CLI_CONTEXT_FILES → CLI_CONTEXT_PATTERN
- Input: INPUT_FILES → INPUT_PATTERN → CLI_INPUT_FILES → CLI_INPUT_PATTERN

**Benefits:**
- 90% cost reduction on cache reads
- 5-minute default TTL (can extend to 1 hour)
- Minimum 1024 tokens per cached block
- Date-only timestamp (not datetime) prevents minute-by-minute invalidation

**Monitoring:**
- Heuristic token estimation (character-based)
- Exact API token counting via `/v1/messages/count_tokens`
- Future: cache usage metrics from API response

### Editor Selection

**Algorithm** (`lib/edit.sh`):

1. Check `$VISUAL` (highest priority)
2. Check `$EDITOR`
3. Platform-specific defaults (`uname -s`):
   - Darwin (macOS): `vim` → `nano` → `vi`
   - Linux: `vim` → `nano` → `vi`
   - Windows/WSL: `vim` → `nano` → `code` → `vi`
4. Common editor detection: `command -v vim nvim emacs nano code subl atom vi`
5. Fallback: `vi` (POSIX standard)

**Integration:**
- `workflow init` - Opens `project.txt` and `config`
- `workflow new` - Opens `task.txt` and `config`
- `workflow edit` - Opens project or workflow files (includes output if exists)

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

- `ensure_global_config()` - Create `~/.config/workflow/` on first use
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
- `documentcat()` - Wraps INPUT documents with `<document index="N">` tags and metadata
- `contextcat()` - Wraps CONTEXT files with `<context-file>` tags and metadata
- `filecat()` - Legacy function (uses contextcat for backward compatibility)
- `find_project_root()` - Walk up directory tree for `.workflow/`
- `list_workflows()` - List workflow directories
- `escape_json()` - JSON string escaping for API payloads
- `build_text_content_block()` - Creates JSON content block from file with embedded XML metadata
- `build_document_content_block()` - Placeholder for future PDF support
- `detect_file_type()` - Detects text vs document/PDF files

**Project discovery:**

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

Eliminates duplication between run mode (workflow.sh) and task mode (lib/task.sh) by extracting common execution functions. All functions are mode-aware with a `mode` parameter ("run" or "task") for mode-specific behavior.

**Functions:**

- `build_system_prompt()` - Builds both XML and JSON content blocks for system prompts
  - Concatenates prompt files from SYSTEM_PROMPTS array
  - Creates JSON block with cache_control for system prompts
  - Populates SYSTEM_BLOCKS array
  - Writes XML version to `.workflow/prompts/system.txt` for debugging
- `build_project_description_block()` - Creates cached JSON block for project descriptions
- `build_current_date_block()` - Creates uncached JSON block for current date
- `estimate_tokens()` - Dual token estimation (heuristic + API)
  - Heuristic character-based estimation for quick feedback
  - Calls `anthropic_count_tokens()` for exact API count (when API key available)
  - Displays comparison between heuristic and actual counts
- `handle_dry_run_mode()` - Saves prompts and JSON payloads for inspection
  - Saves 4 files: XML system, XML user, JSON request, JSON blocks breakdown
  - Opens in editor for inspection
  - Exits without making API call
- `build_prompts()` - Builds both XML and JSON structures
  - Calls block-building functions to populate SYSTEM_BLOCKS
  - Creates TASK_BLOCK for user message
  - Builds hierarchical XML for debugging: `<system>` with `<system-prompts>`, `<project-description>`, `<current-date>`
  - Builds hierarchical XML for debugging: `<user>` with `<documents>`, `<context>`, `<task>`
- `aggregate_context(mode, input_file, context_file, project_root)` - Builds content blocks and XML
  - Order: context → dependencies → input (stable → volatile)
  - Within each: FILES → PATTERN → CLI (stable → volatile)
  - Each file becomes a JSON content block in CONTEXT_BLOCKS, DEPENDENCY_BLOCKS, or INPUT_BLOCKS
  - Also writes XML to input_file and context_file for debugging
  - Adds cache_control at end of each section (4 total breakpoints)
  - Embeds metadata as XML tags in block text content
- `execute_api_request(mode)` - Unified API execution
  - Assembles content blocks arrays (SYSTEM_BLOCKS + CONTEXT_BLOCKS + DEPENDENCY_BLOCKS + INPUT_BLOCKS + TASK_BLOCK)
  - Writes JSON arrays to temporary files
  - Passes files to API functions (avoids bash parameter parsing issues)
  - Run mode: backs up existing output before API call
  - Task mode: displays to stdout in non-stream mode if no explicit file
  - Cleans up temporary files

**Design rationale:**

The refactoring eliminated ~352 lines of duplication while preserving exact behavior. An orchestrator function was considered but rejected to maintain clarity and flexibility. The explicit execution sequence in workflow.sh and lib/task.sh makes the flow easier to understand and modify.

## Development Workflows

### Testing

**Framework:** Bats (Bash Automated Testing System)

**Running tests:**

```bash
# All tests
bats tests/

# Specific file
bats tests/config.bats

# Verbose output
bats -t tests/
```

**Test organization:**
- One file per major feature (init, config, run, task, help, etc.)
- Mock global config via `setup_test_env()` in `tests/test_helper/common.sh`
- 190+ tests covering all subcommands and features

**Coverage expectations:**
- All subcommands have basic tests
- Configuration cascade tested
- Path resolution tested
- Error conditions tested
- Edge cases covered

### Documentation Update Protocol

When making interface changes (new features, behavior changes):

**Required updates:**

1. Code implementation and tests
2. `lib/help.sh` - CLI help text
3. `docs/` - User-facing documentation
4. README.md and docs/index.md - Keep synchronized
5. CLAUDE.md - Technical implementation details
6. Code comments and library headers

**Checklist:**

- [ ] Implement feature with tests
- [ ] Update help text
- [ ] Update relevant docs pages
- [ ] Update README.md if user-facing
- [ ] Update CLAUDE.md with technical details
- [ ] Update code comments
- [ ] Verify README.md ↔ docs/index.md sync
- [ ] Test with `mkdocs serve` (no warnings)

**Style guidelines:** See Documentation Style Guidelines section below

### Making Changes

**Adding a subcommand:**

1. Add case to `workflow.sh` subcommand dispatcher
2. Implement in `lib/core.sh` (or new lib file if complex)
3. Add help function to `lib/help.sh`
4. Add `-h` check to subcommand case
5. Add test file `tests/<subcommand>.bats`
6. Document in `docs/reference/cli-reference.md`

**Modifying configuration:**

1. Update loading logic in `lib/config.sh`
2. Update display in `show_config()` in `lib/core.sh`
3. Document in `docs/user-guide/configuration.md`
4. Add tests in `tests/config.bats`

**Changing API interaction:**

1. Modify `lib/api.sh`
2. Test both streaming and batch modes
3. Update token estimation if request structure changes

### Version Management

**Current version:** 0.1.0 (pre-release)

**Location:** `WORKFLOW_VERSION` constant in `workflow.sh` (line 5)

**Semantic versioning strategy:**
- **0.x.x** - Pre-release (API may change)
- **1.0.0** - First stable release
- **MAJOR** - Breaking changes to CLI interface or config format
- **MINOR** - New features (backward compatible)
- **PATCH** - Bug fixes (backward compatible)

**Updating version:**

1. Edit `WORKFLOW_VERSION` in `workflow.sh`
2. Add entry to `CHANGELOG.md` with date and changes
3. Update version in `README.md` and `docs/index.md`
4. Commit: `git commit -m "chore: Bump version to X.Y.Z"`
5. Tag: `git tag -a vX.Y.Z -m "Release version X.Y.Z"`

**Version display:**
- `workflow --version` or `workflow -v` - Shows version number
- `workflow --help` - Includes version in header
- CHANGELOG.md - Tracks all version history

## Technical Details

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

### Glob Expansion Timing

**Config patterns:**

```bash
# Expansion in project root context
local files
files=$(cd "$PROJECT_ROOT" && eval echo "$CONTEXT_PATTERN")
```

**Why:** Ensures patterns resolve relative to project root regardless of PWD.

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

**Streaming vs batch:**
- Streaming: `stream: true` added to payload, parse SSE events
- Batch: `stream: false`, single JSON response

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

## Development Guidelines

### Documentation Update Protocol

**When to update:**
- New features or subcommands
- Changed behavior or options
- Bug fixes affecting usage
- Performance improvements

**Required updates:**

1. **README.md:** Brief feature mention, update quick start if needed
2. **CLAUDE.md:** Technical details, architecture changes
3. **docs/:** User-facing documentation (see hierarchy below)
4. **lib/help.sh:** CLI help text for affected subcommands
5. **Code comments:** Update in workflow.sh and lib/*.sh
6. **Library headers:** Update file docstrings in lib/*.sh
7. **Tests:** Add/update in tests/*.bats

**Documentation hierarchy:**

```
README.md               → Brief overview, link to docs
docs/index.md           → Landing page, features
docs/getting-started/   → Installation, tutorials
docs/user-guide/        → Complete usage guide
docs/reference/         → CLI and technical reference
lib/help.sh             → CLI help text
CLAUDE.md               → Developer/technical guide
Code comments           → Inline documentation
```

**Critical sync:** README.md ↔ docs/index.md
- Features list must match
- Quick start must be consistent
- Both must reflect current capabilities
- README briefer, index.md more detailed

### Canonical Subcommand Ordering

**All subcommand listings must use this order:**

1. `init` - Project initialization
2. `new` - Create workflows
3. `edit` - Edit workflows/config
4. `config` - View/manage configuration
5. `run` - Execute workflows
6. `task` - Quick execution
7. `cat` - View output
8. `open` - View output in app
9. `list` - List workflows
10. `help` - Documentation

**Rationale:**
- Follows natural workflow progression (setup → prepare → execute → review → utility)
- Groups related commands (run/task, cat/open)
- Improves readability and scannability
- Consistent across all help messages, docs, and tables

**Apply to:**
- Main help message (lib/help.sh)
- Subcommand tables in docs
- Quick reference tables
- README command lists

### Documentation Style Guidelines

**Key Features (README.md and docs/index.md only):**

```markdown
- 🎯 **Feature Name:** Description text on same line, can be 1-2 sentences providing detail.
```

**Other bullet lists:**

```markdown
// Short descriptions (< 10 words):
- **Item:** Brief description

// Longer descriptions:
- **Item:**
  Longer description on next line
```

**Avoid:**
- `**Heading** - Description` (old dash style)
- Emojis outside Key Features
- Inconsistent punctuation

### Testing Strategy

**Test file organization:**
- `tests/<subcommand>.bats` - One file per subcommand
- `tests/test_helper/common.sh` - Shared utilities
- Mock `$HOME`, `$XDG_CONFIG_HOME`, global config dir

**Common patterns:**

```bash
setup() {
    setup_test_env  # Mock HOME, create temp dirs
}

teardown() {
    cleanup_test_env  # Remove temp dirs
}

@test "feature: specific behavior" {
    run bash "$WORKFLOW_SCRIPT" subcommand args
    assert_success
    assert_output --partial "expected text"
}
```

**Mock API calls:**
- Tests should not make real API calls
- Use `--count-tokens` or `--dry-run` to avoid API calls in tests
- Mock `lib/api.sh` functions for integration tests

### Git Commit Guidelines

**Format:**

```
<type>: <subject>

<body>

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types:** feat, fix, docs, test, refactor, style, chore

**Subject:** Max 72 chars, imperative mood

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

## Notes

- System prompts use XML formatting for structured instructions
- `filecat()` adds visual separators and metadata
- Config files are sourced bash scripts (can include logic)
- CLI context augments (not replaces) config context
- Hardlinks updated atomically for safe concurrent access
- Token estimation is approximate (actual may vary ±5%)
- Don't run the full test suite any more than needed. Don't run it multiple times to process the output differently.