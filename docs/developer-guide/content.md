# Content & I/O Layer

Technical reference for WireFlow's content handling: project structure, input processing, context aggregation, and output management.

## Project Structure

A WireFlow project is identified by the `.workflow/` directory:

```
my-project/
├── .workflow/                           # Project root
│   ├── config                           # Project configuration
│   ├── project.txt                      # Project description (optional)
│   ├── output/                          # Hardlinks to workflow outputs
│   │   └── <name>.<format>              # → run/<name>/output.<format>
│   ├── cache/                           # Shared conversion cache
│   │   └── conversions/
│   │       ├── office/                  # Office→PDF (.docx, .pptx)
│   │       └── images/                  # Image resize cache
│   └── run/                             # Individual workflows
│       └── <name>/
│           ├── task.txt                 # Task prompt
│           ├── config                   # Workflow configuration
│           ├── output.<format>          # Current output
│           └── output-TIMESTAMP.<format> # Backups
└── (project files...)
```

### Key Directories

| Directory | Purpose | Created By |
|-----------|---------|------------|
| `.workflow/` | Project root marker | `wfw init` |
| `.workflow/output/` | Hardlinks to outputs | First workflow run |
| `.workflow/cache/` | Shared conversion cache | `wfw init` |
| `.workflow/run/<name>/` | Workflow directory | `wfw new` |

### Implementation

Project discovery walks up the directory tree looking for `.workflow/`:

```bash
# lib/utils.sh
find_project_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        [[ -d "$dir/.workflow" ]] && echo "$dir" && return 0
        dir="$(dirname "$dir")"
    done
    return 1
}
```

## Input Processing

### File Type Detection

Implemented in `lib/utils.sh:detect_file_type()`:

```bash
detect_file_type "$file"  # Returns: text, pdf, image, office, or binary
```

### Supported Types

| Type | Extensions | Processing | API Format |
|------|------------|------------|------------|
| **Text** | `.md`, `.txt`, `.json`, `.py`, etc. | Read UTF-8 | Document block |
| **PDF** | `.pdf` | Base64 encode | PDF document block |
| **Image** | `.png`, `.jpg`, `.gif`, `.webp` | Base64 encode | Image block |
| **Image (convert)** | `.svg`, `.heic`, `.tiff` | Convert + base64 | Image block |
| **Office** | `.docx`, `.pptx` | Convert to PDF | PDF document block |
| **Binary** | (other) | Skipped | N/A |

### Image Processing

Native formats pass through directly. Conversion formats require ImageMagick:

| Extension | Converts To | Notes |
|-----------|-------------|-------|
| `.svg` | PNG | Rasterized |
| `.heic`, `.heif` | JPEG | Apple format |
| `.tiff`, `.tif` | PNG | Print/scan |

**Implementation:**
- `lib/utils.sh:get_image_media_type()` - MIME type lookup
- `lib/utils.sh:needs_format_conversion()` - Check if conversion needed
- `lib/utils.sh:convert_image_format()` - ImageMagick conversion
- `lib/utils.sh:build_image_content_block()` - API block construction

### Office Document Processing

Office files (.docx, .pptx) are converted to PDF via LibreOffice:

```bash
# lib/utils.sh:convert_office_to_pdf()
soffice --convert-to pdf --outdir "$temp_dir" --headless "$source"
```

**Note:** `.xlsx` not supported - export to CSV for tabular data.

### Conversion Caching

Conversions are cached at project level with hash-based IDs:

```
.workflow/cache/conversions/
├── office/
│   ├── <hash>.pdf           # Converted PDF
│   └── <hash>.pdf.meta      # Metadata sidecar
└── images/
    ├── <hash>.<ext>         # Resized image
    └── <hash>.<ext>.meta    # Metadata sidecar
```

**Cache validation:**
1. Check mtime (fast path)
2. Check content hash for files ≤10MB (slow path)

**Implementation:** `lib/utils.sh:generate_cache_id()`

## Context Aggregation

### Semantic Separation

WireFlow distinguishes two content types:

| Type | Config Variables | Purpose |
|------|------------------|---------|
| **Input** | `INPUT` | Primary documents to analyze |
| **Context** | `CONTEXT`, `DEPENDS_ON` | Supporting references |

### Aggregation Methods

Two methods can be combined:

1. **Config arrays** - `INPUT=(data/*.csv report.pdf)` (globs expand at source time)
2. **Dependencies** - `DEPENDS_ON=(preprocessing)` (context only)

### Aggregation Order

Content is aggregated stable → volatile:

**Context Materials:**
1. Config `CONTEXT` (project-relative, already glob-expanded)
2. CLI `-cx/--context` (PWD-relative)

**Dependencies:**
1. `DEPENDS_ON` outputs from `.workflow/output/`

**Input Documents:**
1. Config `INPUT` (project-relative, already glob-expanded)
2. CLI `-in/--input` or `-- <files>` (PWD-relative)

### Document Ordering

Within aggregated content, documents are ordered for optimal API processing:

1. **PDFs** - Context PDFs, then input PDFs (processed first)
2. **Text** - Context text, dependencies, input text
3. **Images** - All sources (Vision API)
4. **Task** - Always last

**Rationale:** Per Anthropic guidelines, PDFs before text improves processing.

### Content Block Arrays

All content is organized into typed arrays:

| Array | Purpose | Citable |
|-------|---------|---------|
| `CONTEXT_PDF_BLOCKS` | PDF files from context | Yes |
| `INPUT_PDF_BLOCKS` | PDF files from input | Yes |
| `CONTEXT_BLOCKS` | Text files from context | Yes |
| `DEPENDENCY_BLOCKS` | Workflow outputs | Yes |
| `INPUT_BLOCKS` | Text files from input | Yes |
| `IMAGE_BLOCKS` | Images from all sources | No |
| `TASK_BLOCK` | Task prompt | N/A |

### Path Resolution

| Source | Resolution |
|--------|------------|
| Config variables | Project-relative |
| CLI flags | PWD-relative |

### Implementation

Content aggregation is handled by a unified function in `lib/execute.sh`:

```bash
aggregate_context(mode, project_root, workflow_dir)
```

This function:
- Processes all context sources (patterns, files, CLI)
- Resolves dependencies from `.workflow/output/`
- Processes all input sources (patterns, files, CLI)
- Populates the typed block arrays as side effects
- Handles file type detection and conversion

**Note:** CLI context is processed after CLI input to ensure input files take precedence when files appear in both sources.

## Output Handling

### Output Formats

Any text-based format is supported:

| Format | Extension | Post-Processing |
|--------|-----------|-----------------|
| Markdown | `.md` | `mdformat` if available |
| JSON | `.json` | `jq` pretty-print |
| Plain text | `.txt` | None |
| HTML, XML, CSV, YAML | `.html`, etc. | None |
| Code | `.py`, `.js`, etc. | None |

### Format Hints

For non-markdown formats, WireFlow appends a hint to the task:

```xml
<output-format>json</output-format>
```

### Output Locations

| Location | Purpose |
|----------|---------|
| `.workflow/run/<name>/output.<format>` | Primary output |
| `.workflow/output/<name>.<format>` | Hardlink for quick access |
| `.workflow/run/<name>/output-TIMESTAMP.<format>` | Backup versions |

### Hardlink Strategy

```bash
# Primary location
output_file=".workflow/run/$name/output.$format"

# Create hardlink
ln "$output_file" ".workflow/output/$name.$format"
```

**Benefits:**
- Visible in file browsers (unlike symlinks)
- Single data storage (no duplication)
- Atomic updates

### Backup Strategy

Before overwriting, create timestamped backup:

```bash
# Before run
cp "$output_file" "${output_file%.${format}}-$(date +%Y%m%d-%H%M%S).${format}"
```

### Post-Processing

**Markdown:** If `mdformat` available, format output
**JSON:** If `jq` available, pretty-print

### Implementation

Core functions in `lib/execute.sh`:

```bash
write_output()           # Write to file, create hardlink
backup_output()          # Create timestamped backup
postprocess_output()     # Format-specific processing
```

## Prompt Caching

### Cache Breakpoint Strategy

WireFlow places cache breakpoints (`cache_control: {type: "ephemeral"}`) strategically:

**System blocks:**
1. After aggregated system prompts (most stable)
2. After project descriptions

**User content blocks:**
1. After last PDF block (if PDFs exist)
2. After last text/image block (before task)

**Benefits:**
- 90% cost reduction on cache reads
- 5-minute default TTL
- Minimum 1024 tokens per cached block

### Adaptive Logic

```
PDFs present:     [PDFs ✓] → [text docs] → [images ✓] → task
No PDFs:          [text docs ✓] → [images ✓] → task
Only task:        task (no breakpoints)
```

## See Also

- [Architecture](architecture.md) - System design overview
- [Execution](execution.md) - Run/task/batch mode processing
- [API Layer](api.md) - Request building and response handling
- [Configuration](configuration.md) - Config cascade
