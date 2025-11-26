# Input and Context Aggregation

Reference for how Workflow aggregates input documents and context materials from multiple sources.

## Overview

Workflow distinguishes between two types of materials:

- **Input Documents** (`INPUT_*`): Primary data to be analyzed or transformed
- **Context Materials** (`CONTEXT_*`): Supporting information and references

Both support three aggregation methods that can be combined:

1. **Glob patterns** - Match files by pattern
2. **Explicit files** - Specify exact file paths
3. **Workflow dependencies** - Include outputs from other workflows (CONTEXT only)

## Aggregation Order

Content is aggregated in this specific order (stable → volatile):

**Context Materials** (processed first):

1. Config `CONTEXT_FILES` (project-relative, run mode only)
2. Config `CONTEXT_PATTERN` (project-relative, run mode only)
3. CLI `-cx/--context` (PWD-relative, both modes)

**Workflow Dependencies** (processed second, run mode only):

1. `DEPENDS_ON` workflow outputs from `.workflow/output/` directory

**Input Documents** (processed third):

1. Config `INPUT_FILES` (project-relative, run mode only)
2. Config `INPUT_PATTERN` (project-relative, run mode only)
3. CLI `-in/--input` or `-- <files>` (PWD-relative, both modes)

**Document Type Ordering:**

Within context and input sources, documents are automatically ordered for optimal processing:
1. PDF documents (context PDFs, then input PDFs) - processed first
2. Text documents (context text, dependencies, input text)
3. Images (detected from all sources) - Vision API
4. Task prompt - always last

## Method 1: Glob Patterns

Match files using glob patterns.

### Input Patterns

**In Config:**

```bash
# .workflow/analysis/config
INPUT_PATTERN="data/*.csv"
```

**From CLI:**

```bash
wfw run analysis -in "data/*.csv"
```

### Context Patterns

**In Config:**

```bash
# .workflow/analysis/config
CONTEXT_PATTERN="references/*.md"
```

**From CLI:**

```bash
wfw run analysis -cx "references/*.md"
```

### Pattern Syntax

| Pattern | Matches |
|---------|---------|
| `*.md` | All `.md` files in current directory |
| `**/*.md` | All `.md` files recursively |
| `data/*.csv` | All CSV files in `data/` |
| `{notes,refs}/*.md` | Markdown files in `notes/` or `refs/` |
| `experiment-{1,2,3}/data.csv` | Data files from specific experiments |

### Multiple Patterns

**Config:**

```bash
CONTEXT_PATTERN="data/*.csv notes/*.md"
```

**CLI:**

```bash
-cx "data/*.csv" -cx "notes/*.md"
```

### Path Resolution

- **Config patterns:** Relative to **project root**
- **CLI patterns:** Relative to **PWD**

## Method 2: Explicit Files

Specify exact file paths.

### Input Files

**In Config:**

```bash
# .workflow/analysis/config
INPUT_FILES=("data/dataset1.json" "data/dataset2.json")
```

**From CLI:**

```bash
wfw run analysis \
  -in data/dataset1.json \
  -in data/dataset2.json
```

### Context Files

**In Config:**

```bash
# .workflow/analysis/config
CONTEXT_FILES=("README.md" "notes/important.txt")
```

**From CLI:**

```bash
wfw run analysis \
  -cx README.md \
  -cx notes/important.txt
```

### Path Resolution

- **Config files:** Relative to **project root**
- **CLI files:** Relative to **PWD**

### File Order

Files are included in the order specified.

## Method 3: Workflow Dependencies

Include outputs from other workflows.

### In Config

```bash
# .workflow/report/config
DEPENDS_ON=(context-gathering data-analysis)
```

### From CLI

```bash
wfw run report --depends-on context-gathering --depends-on data-analysis

# Or comma-separated
wfw run report --depends-on context-gathering,data-analysis
```

### Dependency Resolution

Dependencies are resolved to:

```
.workflow/output/<workflow-name>.<format>
```

Which is a hardlink to:

```
.workflow/<workflow-name>/output.<format>
```

### Cross-Format Dependencies

Works across formats:

```bash
# JSON output
wfw run extract --format json

# Depends on JSON (included as text context)
wfw run analyze --depends-on extract
```

## Combining Methods

All three methods can be combined in a single workflow:

### Example Config

```bash
# Dependencies
DEPENDS_ON=(00-context 01-preprocessing)

# Glob patterns
CONTEXT_PATTERN="data/*.csv"

# Explicit files
CONTEXT_FILES=("README.md" "notes/analysis-plan.txt")
```

### Example CLI

```bash
wfw run analysis \
  --depends-on 00-context \
  -cx "data/*.csv" \
  -cx additional-notes.md
```

### Result

Context includes (in order):

1. System prompts
2. Project description
3. `00-context` output
4. `01-preprocessing` output (from config)
5. All `.csv` files from `data/` (from config)
6. `README.md` (from config)
7. `notes/analysis-plan.txt` (from config)
8. `additional-notes.md` (from CLI)

## Context File Format

Files are wrapped in XML tags with metadata:

```xml
<file path="data/results.csv" type="csv">
trial,condition,score
1,control,0.85
2,experimental,0.92
</file>

<file path="notes/analysis.md" type="md">
# Analysis Notes

Key findings:
- Significant effect observed
- Further validation needed
</file>
```

## Supported File Types

WireFlow supports various file types with automatic format detection and processing:

### Text Documents

Standard text files are included directly:

| Format | Extensions | Handling |
|--------|------------|----------|
| Plain text | `.txt` | Direct inclusion |
| Markdown | `.md`, `.markdown` | Direct inclusion |
| Code | `.py`, `.js`, `.sh`, etc. | Direct inclusion |
| Data | `.csv`, `.json`, `.yaml` | Direct inclusion |
| Structured | `.xml`, `.html` | Direct inclusion |

### PDF Documents

PDF files are automatically processed using the Anthropic document API:

```bash
wfw task summarize -cx paper.pdf
wfw run analysis -in report.pdf
```

**Requirements:**

- Maximum file size: 32MB per PDF
- PDFs are sent as base64-encoded document blocks

### Office Documents

Microsoft Office files (`.docx`, `.pptx`) are automatically converted to PDF:

```bash
wfw task review -cx presentation.pptx
```

**Requirements:**

- LibreOffice must be installed (`soffice` command)
- Converted PDFs are cached for performance

### Images (Vision API)

Image files are processed using Claude's vision capabilities:

| Format | Extensions |
|--------|------------|
| JPEG | `.jpg`, `.jpeg` |
| PNG | `.png` |
| GIF | `.gif` |
| WebP | `.webp` |

```bash
wfw task describe -cx diagram.png
wfw run analysis -in "figures/*.jpg"
```

**Constraints:**

- Maximum dimension: 8000px (longer edge)
- Recommended maximum: 1568px (longer edge)
- Maximum file size: 5MB per image
- Images exceeding limits are automatically resized

**Optional dependency:** ImageMagick (`convert` command) for resizing large images.

## Advanced Patterns

### Recursive Matching

```bash
CONTEXT_PATTERN="**/*.py"  # All Python files recursively
```

### Brace Expansion

```bash
CONTEXT_PATTERN="{data,results}/*.csv"  # CSV files from data/ or results/
CONTEXT_PATTERN="experiment-{1,2,3}/output.txt"  # Specific experiments
```

### Excluding Files

Glob doesn't support exclusion directly. Use explicit files instead:

```bash
# Instead of "data/*.csv except bad.csv"
CONTEXT_FILES=("data/good1.csv" "data/good2.csv" "data/good3.csv")
```

### Conditional Context

Different workflows, different context:

```bash
# Exploratory workflow: broad context
# .workflow/exploratory/config
CONTEXT_PATTERN="data/**/*.csv"

# Focused workflow: specific files
# .workflow/focused/config
CONTEXT_FILES=("data/subset/specific.csv")
```

## Path Resolution Examples

### Config File Paths

```bash
# Project structure:
/home/user/project/
├── .workflow/
│   └── analysis/
│       └── config  # CONTEXT_PATTERN="data/*.csv"
└── data/
    └── results.csv

# Pattern resolves to: /home/user/project/data/results.csv
```

Works regardless of where you run `workflow` from:

```bash
cd /home/user/project/subdir
wfw run analysis  # Still finds /home/user/project/data/results.csv
```

### CLI Paths

```bash
# Current directory: /home/user/project/subdir
wfw run analysis -cx local.csv
# Looks for: /home/user/project/subdir/local.csv
```

Standard CLI behavior (like `cp`, `cat`, etc.).

## Context Size Management

### Estimate Before Running

```bash
wfw run analysis --count-tokens
```

Shows:

```
Context:
  - 00-context (1,200 tokens)
  - data/file1.csv (2,500 tokens)
  - data/file2.csv (1,800 tokens)
  - notes.md (650 tokens)

Total estimated: ~6,150 tokens
```

### Reduce Context Size

**Use specific patterns:**

```bash
# Instead of:
CONTEXT_PATTERN="data/**/*"  # Everything

# Use:
CONTEXT_PATTERN="data/2024-01/*.csv"  # Specific month
```

**Use explicit files:**

```bash
# Instead of pattern matching many files
CONTEXT_FILES=("data/summary.csv" "data/key-results.txt")
```

**Split into workflows:**

```bash
# Workflow 1: Process all data, output summary
wfw run 01-summarize
# Config: CONTEXT_PATTERN="data/**/*.csv"

# Workflow 2: Use summary only
wfw run 02-analyze
# Config: DEPENDS_ON=(01-summarize)  # Much smaller context
```

## Debugging Context

### Dry Run

```bash
wfw run analysis --count-tokens
```

Shows exactly what will be included and token estimates.

### Check Glob Expansion

```bash
# Test pattern in shell
ls data/*.csv

# Or use find
find data -name "*.csv"
```

### Verify Dependencies

```bash
# Check workflow exists and has output
wfw list
ls .workflow/dependency-name/output/
```

## Common Patterns

### All Project Documentation

```bash
CONTEXT_PATTERN="**/*.md"
```

### Specific Data Subdirectory

```bash
CONTEXT_PATTERN="experiments/experiment-1/data/*.csv"
```

### Multiple File Types

```bash
CONTEXT_PATTERN="data/*.{csv,json,txt}"
```

### Sequential Dependencies

```bash
DEPENDS_ON=(00-init 01-process 02-analyze)
```

### Parallel Dependencies

```bash
# Both workflows can run independently
wfw run 01-analyze-a --depends-on 00-init
wfw run 01-analyze-b --depends-on 00-init

# Final workflow depends on both
# Config for 02-final:
DEPENDS_ON=(01-analyze-a 01-analyze-b)
```

## Best Practices

### Be Specific

- ✅ **Good:** `data/2024-01/*.csv` - Specific subset
❌ **Poor:** `**/*` - Everything (too much context)

### Order Matters

Arrange context logically:

1. Background/overview first
2. Detailed data second
3. Recent updates last

### Use Dependencies

Instead of copying files or including large outputs directly, use `--depends-on`:

```bash
# Inefficient:
cp .workflow/preprocessing/output.md context/
wfw run analysis -cx context/<name>.md

# Better:
wfw run analysis --depends-on preprocessing
```

### Split Large Context

If context exceeds token limits:

1. Create intermediate summarization workflow
2. Use summary as context for final workflow

```bash
wfw run 01-summarize  # Processes all data
wfw run 02-final --depends-on 01-summarize  # Uses summary only
```

## Troubleshooting

### Pattern Matches Nothing

```bash
# Verify pattern
ls data/*.csv

# Check working directory
pwd

# Remember: config patterns relative to project root
```

### File Not Found

```bash
# CLI paths relative to PWD
pwd
ls relative/path/to/file.txt

# Config paths relative to project root
cd $(workflow root)  # Hypothetical
ls relative/path/to/file.txt
```

### Dependency Not Found

```bash
# Check workflow exists
wfw list

# Check has output
ls .workflow/dependency-name/output/
```

### Too Much Context

```bash
# Estimate first
wfw run analysis --count-tokens

# If too large, reduce:
# - Use more specific patterns
# - Split into smaller workflows
# - Use explicit file list
```

## See Also

- [Execution Guide](../user-guide/execution.md) - Using context options
- [Configuration Guide](../user-guide/configuration.md) - Setting context in configs
- [CLI Reference](cli-reference.md) - Context flags

---

Continue to [Token Estimation](token-estimation.md) →
