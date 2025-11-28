# Context & Input

Understand the distinction between input and context files, supported document types, and how content is aggregated.

## Input vs Context

WireFlow distinguishes between **input** (primary documents to process) and **context** (supporting materials):

| Aspect | Input (`-in`) | Context (`-cx`) |
|--------|---------------|-----------------|
| **Purpose** | Documents to analyze/transform | Background information |
| **Position** | After context in prompt | Before input in prompt |
| **Typical use** | PDFs to summarize, data to analyze | Reference docs, prior outputs |
| **Citations** | Yes (with `--enable-citations`) | Yes |

**Example:**
```bash
# Summarize a report (input) using style guide (context)
wfw run summarize -in report.pdf -cx style-guide.md

# Analyze data (input) with reference materials (context)
wfw run analyze -in results.csv -cx methodology.md -cx prior-analysis.md
```

## Supported Document Types

### Text Files

All text-based files (`.md`, `.txt`, `.py`, `.js`, `.csv`, etc.) are processed directly with syntax highlighting based on extension.

```bash
wfw run analysis -cx data.csv -cx script.py -cx notes.md
```

### PDF Documents

- Processed using Claude API (text + visual analysis)
- Maximum size: 32MB per PDF
- Supports citations with document indices

```bash
wfw run analysis -in report.pdf -cx references.pdf
```

### Microsoft Office Files

- **Supported:** `.docx`, `.pptx`
- Auto-converted to PDF via LibreOffice
- Cached in `.workflow/cache/office/`
- Citations use original filename

```bash
wfw run summary -in presentation.pptx -cx notes.docx
```

**Requirements:** LibreOffice installed (`libreoffice` or `soffice` in PATH)

### Images

- **Native:** `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`
- **Converted:** `.heic` → JPEG, `.tiff` → PNG, `.svg` → PNG
- Processed using Claude Vision API
- Auto-resize if larger than 1568px on longest edge
- Maximum size: 5MB per image
- NOT citable (no document indices)

```bash
wfw run analyze-diagram -in flowchart.svg -cx photo.heic
```

**Requirements:**
- HEIC: `sips` (macOS) or ImageMagick
- TIFF: `sips` (macOS) or ImageMagick
- SVG: `rsvg-convert` (librsvg) or Inkscape

### Mixing Types

```bash
wfw run research \
    -in "papers/*.pdf" \
    -cx notes.docx \
    -cx diagram.png \
    -cx references.md
```

## Context Aggregation

Content is assembled in this order:

**Run mode:**
1. System prompts (`SYSTEM_PROMPTS`)
2. Project description (`project.txt`)
3. Context files (config + CLI)
4. Dependencies (`--depends-on` outputs)
5. Input files (config + CLI)
6. Images
7. Task prompt (`task.txt`)

**Task mode:**
1. System prompts
2. Project description (if in project)
3. Context files (CLI)
4. Input files (CLI)
5. Images
6. Task prompt (inline or template)

## Path Resolution

### Config File Paths

Paths in config files are **relative to project root**:

```bash
# In .workflow/config or .workflow/run/<name>/config
CONTEXT_PATTERN=data/*.csv
CONTEXT_FILES=(notes/analysis.md refs/paper.pdf)
INPUT_PATTERN=reports/*.pdf
INPUT_FILES=(main-report.pdf)
```

### CLI Paths

CLI paths are **relative to current directory**:

```bash
cd /project/subdir
wfw run analysis -cx local-notes.md
# Looks for: /project/subdir/local-notes.md
```

### Glob Patterns

```bash
# Single directory
-cx "data/*.csv"

# Recursive
-cx "notes/**/*.md"

# Multiple directories
-cx "data/{exp1,exp2}/*"

# In config
CONTEXT_PATTERN=data/*.csv
INPUT_PATTERN=reports/**/*.pdf
```

## Caching

WireFlow caches converted files to speed up repeated runs.

### Office Conversion Cache

Location: `.workflow/cache/office/`

- PDF conversions are cached per source file
- Cache invalidated when source file changes (by mtime)
- Shared across all workflows in the project

### Image Conversion Cache

Location: `.workflow/cache/images/`

- Resized/converted images cached per source
- HEIC→JPEG, TIFF→PNG, SVG→PNG conversions cached
- Original dimensions preserved in cache filename

### Cache Management

```bash
# Clear project cache
rm -rf .workflow/cache/

# View cache contents
ls -la .workflow/cache/office/
ls -la .workflow/cache/images/
```

## Configuration Variables

| Variable | Description | Scope |
|----------|-------------|-------|
| `CONTEXT_PATTERN` | Glob for context files | Project, Workflow |
| `CONTEXT_FILES` | Explicit context file paths | Project, Workflow |
| `INPUT_PATTERN` | Glob for input files | Workflow |
| `INPUT_FILES` | Explicit input file paths | Workflow |
| `ENABLE_CITATIONS` | Enable source citations | All |

## Best Practices

**Input vs Context:**
- Use `-in` for documents you're actively processing
- Use `-cx` for reference materials, prior outputs, style guides
- Dependencies (`--depends-on`) automatically become context

**File organization:**
- Keep source documents in predictable locations
- Use glob patterns in config for dynamic file sets
- Use explicit `INPUT_FILES`/`CONTEXT_FILES` for fixed sets

**Performance:**
- First run with Office/image files is slower (conversion)
- Subsequent runs use cache
- Large images auto-resize to reduce API costs

---

Continue to [Execution Modes](execution.md) →
