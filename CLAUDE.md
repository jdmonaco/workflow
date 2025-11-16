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
├── utils.sh            # Utilities (file processing, project discovery, sanitization)
└── api.sh              # Anthropic API interaction (streaming and batch)
tests/
├── test_helper/        # Bats support libraries (git submodules)
├── *.bats             # Test files (190+ tests)
└── common.sh          # Shared test utilities
```

### Project Structure

User projects contain a `.workflow/` directory:

```
project-root/
├── .workflow/
│   ├── config                    # Project-level configuration
│   ├── project.txt               # Optional project description
│   ├── prompts/system.txt        # Cached system prompt
│   ├── output/                   # Hardlinks to workflow outputs
│   │   └── <name>.<format>       # → ../<name>/output/response.<format>
│   └── <workflow-name>/          # Individual workflows
│       ├── config                # Workflow configuration
│       ├── task.txt              # Task prompt
│       ├── context/              # Optional context files
│       └── output/
│           ├── response.<format>
│           └── response.<format>.backup.TIMESTAMP
└── (project files...)
```

## Core Implementations

### Configuration Cascade

**Four-tier cascade with pass-through:**

1. Global defaults (hardcoded in `lib/config.sh`)
2. Global config (`~/.config/workflow/config`, auto-created on first use)
3. Project config (`.workflow/config`)
4. Workflow config (`.workflow/<name>/config`)
5. CLI flags (highest priority)

**Pass-Through Mechanism:**

- Empty value (`MODEL=`) → Inherit from parent tier
- Explicit value (`MODEL="claude-opus-4"`) → Override parent, decoupled from changes

**Implementation:**

```bash
# In load_global_config(), load_project_config(), etc.
if [[ -z "$MODEL" && -n "$value" ]]; then
    MODEL="$value"  # Only set if currently empty
fi
```

**Benefits:**
- Change global default → affects all empty configs
- Explicit values stay independent
- Easy to reset: set to empty to restore pass-through

**Nested Project Inheritance:**

When initializing inside an existing project:
- `find_project_root()` from target directory searches for parent
- `extract_parent_config()` sources parent config in isolated subshell
- Displays inherited values, writes to new project config
- Creates separate workflow namespace

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

### Context Aggregation

**Three methods (combined):**

1. **Glob patterns:** Bash glob expansion, multiple files
2. **Explicit files:** Array of specific paths
3. **Workflow dependencies:** Include outputs via hardlinks

**File processing:**

```bash
filecat() {
    # Wraps file in XML tags with path and type metadata
    # Handles binary detection, encoding issues
    # Adds visual separators
}
```

**Dependency resolution:**

```bash
# Reads from .workflow/output/ hardlinks
for dep in "${DEPENDS_ON[@]}"; do
    dep_file=$(ls "$PROJECT_ROOT/.workflow/output/$dep".* 2>/dev/null)
done
```

### System Prompt Composition

**Build process (every run):**

1. Load prompts from `$WORKFLOW_PROMPT_PREFIX/{name}.txt`
2. Concatenate in order specified by `SYSTEM_PROMPTS` array
3. Append `project.txt` if non-empty (wrapped in `<project>` tags)
4. Write to `.workflow/prompts/system.txt`
5. Use cached version as fallback if rebuild fails

**Rationale:** Rebuild ensures configuration changes take effect immediately.

### API Interaction

**Location:** `lib/api.sh`

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
# Build JSON payload
jq -n --arg model "$MODEL" \
      --arg prompt "$combined_prompt" \
      --argjson max_tokens "$MAX_TOKENS" \
      --argjson temp "$TEMPERATURE" \
      --argjson stream "$stream_flag" \
      '{model: $model, messages: [{role: "user", content: $prompt}], ...}'
```

### Token Estimation

**Formula:**

```bash
token_count=$(( char_count / 4 ))
```

Simple character-based approximation (reasonable for English text).

**Display:**
- System prompts tokens
- Task tokens
- Project description tokens
- Context tokens (per-file breakdown)
- Total and estimated cost

### Output Management

**Hardlink creation:**

```bash
# Primary location
output_file=".workflow/$workflow_name/output/response.$format"

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
    timestamp=$(date +%Y%m%d_%H%M%S)
    mv "$output_file" "$output_file.backup.$timestamp"
fi
```

**Format-specific post-processing:**
- Markdown: `mdformat` if available
- JSON: `jq '.'` for pretty-printing if available
- Others: No processing

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
- `new_workflow()` - Create workflow directory and files
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
- `filecat()` - File concatenation with XML wrappers and metadata
- `find_project_root()` - Walk up directory tree for `.workflow/`
- `list_workflows()` - List workflow directories
- `escape_json()` - JSON string escaping for API payloads

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

**API interaction:**

- Request construction with `jq`
- Streaming via SSE parsing
- Batch mode with single response
- Error handling and validation

**Key implementation:**
- Uses `curl` with Anthropic Messages API
- Handles both streaming and non-streaming modes
- Displays actual token counts from response

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

### API Request Construction

**Implementation** (`lib/api.sh`):

```bash
# Build JSON payload with jq
payload=$(jq -n \
    --arg model "$MODEL" \
    --arg content "$combined_prompt" \
    --argjson max_tokens "$MAX_TOKENS" \
    --argjson temperature "$TEMPERATURE" \
    --argjson stream "$stream_bool" \
    '{
        model: $model,
        max_tokens: $max_tokens,
        temperature: $temperature,
        stream: $stream,
        messages: [{role: "user", content: $content}]
    }'
)
```

**Streaming vs batch:**
- Streaming: `stream: true`, parse SSE events
- Batch: `stream: false`, single JSON response

### System Prompt Caching

**Build process:**

1. Concatenate prompts: `cat "$WORKFLOW_PROMPT_PREFIX/"{base,custom}.txt`
2. Append project.txt if non-empty
3. Write to `.workflow/prompts/system.txt`
4. Use cached version on failure

**Rebuild timing:** Every run, not cached across runs

**Why:** Ensures config changes apply immediately

### Output Format Hints

**For non-markdown formats:**

```bash
if [[ "$OUTPUT_FORMAT" != "md" && "$OUTPUT_FORMAT" != "markdown" ]]; then
    task_content="${task_content}\n\n<output-format>${OUTPUT_FORMAT}</output-format>"
fi
```

Guides LLM to generate in requested format.

### Token Estimation Algorithm

**Formula:**

```bash
char_count=$(wc -c < "$file")
token_count=$((char_count / 4))
```

Simple approximation: ~4 chars per token (reasonable for English).

**Display breakdown:**
- System prompts
- Task
- Project description
- Each context source
- Total and cost estimate

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
- Use `--dry-run` where possible
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
