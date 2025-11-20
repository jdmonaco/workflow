# Workflow Architecture

System design, architecture patterns, and design decisions for the Workflow codebase.

**For development workflows, see [CLAUDE.md](https://github.com/jdmonaco/workflow/blob/main/CLAUDE.md) (GitHub).**
**For implementation details, see [implementation.md](implementation.md).**

## Overview

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
├── *.bats             # Test files (280+ tests)
└── common.bash        # Shared test utilities
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
│       ├── cache/                # Cached processed files (images, Office→PDF)
│       ├── output.<format>       # Primary output
│       ├── output-TIMESTAMP.<format>  # Backup outputs
│       ├── system-blocks.json    # JSON system content blocks (for debugging)
│       ├── user-blocks.json      # JSON user content blocks (for debugging)
│       ├── request.json          # Full API request JSON (dry-run mode)
│       └── document-map.json     # Citation index mapping (if enabled)
└── (project files...)
```

## Configuration System

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

**Benefits:**
- Change global default → affects all empty configs
- Explicit values stay independent
- Easy to reset: set to empty to restore pass-through
- Nested projects inherit from ALL ancestors in the tree

### Nested Project Configuration

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

**Processing order:**
1. Config CONTEXT_PATTERN (project-relative)
2. CLI --context-pattern (PWD-relative)
3. Config CONTEXT_FILES (project-relative)
4. CLI --context-file (PWD-relative)

## Content Aggregation

### Semantic Separation

- **INPUT documents** (`INPUT_PATTERN`, `INPUT_FILES`): Primary documents to be analyzed or transformed
- **CONTEXT materials** (`CONTEXT_PATTERN`, `CONTEXT_FILES`, `DEPENDS_ON`): Supporting information and references
- **PDFs**: Automatically detected from INPUT/CONTEXT sources (PDF API support)
- **Office files**: Automatically detected from INPUT/CONTEXT sources (.docx, .pptx converted to PDF)
- **IMAGES**: Automatically detected from INPUT/CONTEXT sources (Vision API support)

### Three Aggregation Methods

Applies to both INPUT and CONTEXT:

1. **Glob patterns:** Bash glob expansion, multiple files
2. **Explicit files:** Array of specific paths
3. **Workflow dependencies:** Include outputs via hardlinks (CONTEXT only)

### Automatic File Type Detection

**PDF documents:**
- Validated against 32MB size limit
- Base64-encoded for API
- Added to CONTEXT_PDF_BLOCKS or INPUT_PDF_BLOCKS (citable, optimized ordering)
- Placed BEFORE text documents in API request (per PDF optimization guidelines)
- Citable (PDFs get document indices for citations)
- Token estimation: ~2000 tokens per page (conservative)

**Office files (.docx, .pptx):**
- Converted to PDF using LibreOffice (gracefully skips if unavailable)
- Converted PDFs cached in `.workflow/<name>/cache/office/` with preserved filenames
- Cache validated by mtime (regenerates only if source file is newer)
- Processed as PDF documents (follow PDF ordering)
- Citable with ORIGINAL filename (not cached PDF path)
- Token estimation: same as PDFs (~2000 tokens per page)

**Images (jpg, jpeg, png, gif, webp):**
- Validated against 5MB size limit
- Resized if >1568px on long edge (optimal performance)
- Cached in `.workflow/<name>/cache/` with preserved paths
- Base64-encoded for API
- Added to IMAGE_BLOCKS array (separate from text documents)
- NOT citable (images don't get document indices)

### Dependency Resolution

Workflow dependencies read from `.workflow/output/` hardlinks. Dependencies always go to CONTEXT (not INPUT).

### Nested Project Descriptions

`aggregate_nested_project_descriptions()` finds all ancestor projects, aggregates their project.txt files (oldest first), wraps each in XML tags using sanitized directory name, and caches to `.workflow/prompts/project.txt`. Used in both workflow.sh and lib/task.sh.

## Prompt System

### JSON-First Architecture

Builds JSON content blocks only. Pseudo-XML files optionally created via custom converter for human readability.

### System Prompt Composition

**Build process (every run):**

1. Load prompts from `$WORKFLOW_PROMPT_PREFIX/{name}.txt`
2. Concatenate in order specified by `SYSTEM_PROMPTS` array
3. Create JSON content block with `cache_control: {type: "ephemeral"}`
4. Add to `SYSTEM_BLOCKS` array
5. Write concatenated prompts to `.workflow/prompts/system.txt` for caching
6. Add project-description block (if exists) with cache_control
7. Add current-date block (without cache_control - intentionally volatile)

**JSON content blocks (canonical):**

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

**Date format:** Date-only (not datetime) prevents minute-by-minute cache invalidation.

### User Prompt Composition

Each file becomes its own content block in optimized order: context PDFs → input PDFs → context text → dependencies → input text → images → task

**JSON content blocks (canonical):**

```json
[
  // Context PDF documents (each PDF is a separate block)
  {"type": "document", "source": {"type": "base64", "media_type": "application/pdf", "data": "..."}},
  {"type": "document", "source": {"type": "base64", "media_type": "application/pdf", "data": "..."}, "cache_control": {"type": "ephemeral"}},

  // Input PDF documents (each PDF is a separate block)
  {"type": "document", "source": {"type": "base64", "media_type": "application/pdf", "data": "..."}, "cache_control": {"type": "ephemeral"}},

  // Context text files (each file is a separate block)
  {"type": "text", "text": "<metadata type=\"context\" source=\"...\"></metadata>\n\n[file content]"},
  {"type": "text", "text": "<metadata type=\"context\" source=\"...\"></metadata>\n\n[file content]", "cache_control": {"type": "ephemeral"}},

  // Dependencies (each workflow output is a separate block)
  {"type": "text", "text": "<metadata type=\"dependency\" workflow=\"name\" source=\"...\"></metadata>\n\n[file content]", "cache_control": {"type": "ephemeral"}},

  // Input text documents (each file is a separate block)
  {"type": "text", "text": "<metadata type=\"input\" source=\"...\"></metadata>\n\n[file content]"},
  {"type": "text", "text": "<metadata type=\"input\" source=\"...\"></metadata>\n\n[file content]", "cache_control": {"type": "ephemeral"}},

  // Images (Vision API)
  {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": "..."}, "cache_control": {"type": "ephemeral"}},

  // Task (single block, no cache_control - most volatile)
  {"type": "text", "text": "[task content]"}
]
```

**Aggregation order (optimized for PDF processing):**

1. **Context PDF documents:** CONTEXT_FILES + CONTEXT_PATTERN + CLI (PDFs only, filtered first)
2. **Input PDF documents:** INPUT_FILES + INPUT_PATTERN + CLI (PDFs only, filtered first)
3. **Context text files:** CONTEXT_FILES → CONTEXT_PATTERN → CLI_CONTEXT_FILES → CLI_CONTEXT_PATTERN (text only)
4. **Dependencies:** DEPENDS_ON workflow outputs
5. **Input text documents:** INPUT_FILES → INPUT_PATTERN → CLI_INPUT_FILES → CLI_INPUT_PATTERN (text only)
6. **Images:** Detected from all INPUT/CONTEXT sources (Vision API)
7. **Task:** Always last

**PDF-first ordering rationale:** Per Anthropic PDF API optimization guidelines, placing PDF documents before text documents improves processing performance and accuracy.

**Metadata embedding:** Each file's metadata (type, source, workflow name) is embedded as XML tags at the start of the text content, not as separate JSON fields (Anthropic API doesn't accept extra fields).

### Content Block Arrays

All content is organized into typed arrays for proper ordering and cache management:

| Array | Purpose | Citable | Ordering |
|-------|---------|---------|----------|
| `SYSTEM_BLOCKS` | System prompts, project description, date | N/A | First in request |
| `CONTEXT_PDF_BLOCKS` | PDF files from context sources | Yes | 1st in user array |
| `INPUT_PDF_BLOCKS` | PDF files from input sources | Yes | 2nd in user array |
| `CONTEXT_BLOCKS` | Text files from context sources | Yes | 3rd in user array |
| `DEPENDENCY_BLOCKS` | Workflow dependency outputs | Yes | 4th in user array |
| `INPUT_BLOCKS` | Text files from input sources | Yes | 5th in user array |
| `IMAGE_BLOCKS` | Images from all sources | No | 6th in user array |
| `TASK_BLOCK` | Task prompt (single block) | N/A | Last in user array |
| `DOCUMENT_INDEX_MAP` | Citation tracking for citable docs | N/A | Saved to document-map.json |

**Citability:**
- PDFs (context and input): Citable with document indices
- Text files (context, dependency, input): Citable with document indices
- Images: NOT citable (no document indices assigned)

## API Design

### Request Architecture

**JSON-first:** Content blocks are constructed and passed to API functions via temporary files (avoids bash parameter parsing issues with large JSON payloads).

**Streaming mode:**
- Uses `curl` with chunked transfer encoding
- Parses SSE (Server-Sent Events) format
- Writes incrementally to output file
- Real-time terminal display

**Batch mode:**
- Single request, buffers entire response
- Atomic file write
- Opens in pager when complete

### Parameter Passing Strategy

Content blocks are built incrementally in bash and written to JSON files, then:
1. **Individual image blocks**: Use `printf | jq -Rs` to create each image block with base64 data
2. **Content block arrays**: Use `jq --slurpfile` to read JSON arrays from files (avoids arg limits)
3. **API request**: Pass JSON payload to curl via stdin with `-d @-` (avoids arg limits)

**Why not `--rawfile` for images?**
- Our architecture builds blocks incrementally in bash, then assembles arrays
- Each image block is created via `printf | jq -Rs` (handles base64 correctly)
- Final assembly uses `--slurpfile` for the complete arrays (not individual images)

### Token Counting

**Token Counting API:** Dedicated endpoint `/v1/messages/count_tokens` provides exact token counts.

**Dual approach:** Both heuristic estimation and exact API counting.

**Heuristic:** Simple character-based approximation (`token_count=$(( char_count / 4 ))`) - reasonable for English text.

**Display:**
- System prompts tokens (heuristic)
- Task tokens (heuristic)
- Input documents tokens (heuristic)
- Context tokens (heuristic)
- Total heuristic estimate
- Exact total from API (when ANTHROPIC_API_KEY is set)
- Comparison between heuristic and API count

## Data Management

### Output Management

**Hardlink strategy:**

```bash
# Primary location
output_file=".workflow/$workflow_name/output.$format"

# Create hardlink
ln "$output_file" ".workflow/output/$workflow_name.$format"
```

**Why hardlinks:**
- Visible in file browsers (unlike symlinks)
- Single data storage (not duplication)
- Atomic updates

**Backup strategy:**

Before overwriting, create timestamped backup: `output-TIMESTAMP.format`

**Format-specific post-processing:**
- Markdown: `mdformat` if available
- JSON: `jq '.'` for pretty-printing if available
- Others: No processing

### Prompt Caching

**Implementation:** Anthropic prompt caching with ephemeral cache breakpoints.

**Architecture:**
- Each file becomes its own content block
- Metadata embedded as XML tags within text content
- Cache breakpoints at semantic boundaries (maximum 4)

**Cache Breakpoint Strategy**

Cache breakpoints (`cache_control: {type: "ephemeral"}`) are placed strategically to maximize cost reduction while respecting the 4-breakpoint limit.

**System blocks array:**
1. After aggregated system prompts (most stable)
2. After date block

Result: System prompts and project descriptions are fully cached for all workflow runs in the same project on the same day.

**User content blocks array - Adaptive Strategy:**

The strategy adapts based on what content is present:

1. **If PDFs exist:** Place breakpoint after last PDF block (INPUT_PDF_BLOCKS or CONTEXT_PDF_BLOCKS)
2. **Always:** Place breakpoint after last text document OR last image block (whichever comes last)
    - If images exist: after last image block
    - If no images: after last text block (INPUT_BLOCKS, CONTEXT_BLOCKS, or DEPENDENCY_BLOCKS)
3. **If no PDFs:** Move the "would-be PDF breakpoint" to after text documents (before images)
    - Result: Text documents and images cached separately
4. **If no context/input documents:** No breakpoints in user array
    - Result: Task is re-processed on every run (expected behavior)

**Adaptive breakpoint logic:**
- PDFs present: [PDFs w/ breakpoint] → [text docs] → [images w/ breakpoint] → task
- No PDFs, have docs: [text docs w/ breakpoint] → [images w/ breakpoint] → task
- Only task: task (no breakpoints, re-processed each run)

**Aggregation order within categories:** Stable → volatile
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

## Editor Selection

**Algorithm:**

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
