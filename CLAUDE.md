# AI-Driven Workflow Framework

## Project Overview

This directory contains `workflow.sh`, a portable CLI tool for managing AI-assisted manuscript development workflows using the Anthropic Messages API. The tool uses a git-like project structure with `.workflow/` directories and supports flexible configuration cascading, context aggregation, and workflow chaining.

## Directory Structure

```
project-root/
├── .workflow/                   # Git-like workflow directory
│   ├── config                   # Project-level configuration
│   ├── project.txt              # Project description (appended to system prompt)
│   ├── prompts/
│   │   └── system.txt          # Generated system prompt
│   ├── output/                  # Hardlinks to workflow outputs
│   │   └── WORKFLOW.md         # Hardlink to WORKFLOW/output.md
│   └── WORKFLOW_NAME/           # Individual workflow directory
│       ├── config              # Workflow-specific configuration
│       ├── task.txt            # Task description
│       ├── context.txt         # Generated context
│       └── output.md           # API response
└── (project files...)
```

## Installation

1. Copy `workflow.sh` to a directory on your PATH (e.g., `~/bin/` or `/usr/local/bin/`)
2. Rename to `workflow`: `mv workflow.sh workflow`
3. Ensure it's executable: `chmod +x workflow`
4. Set required environment variables in `~/.bashrc` or `~/.bash_profile`:
   ```bash
   export ANTHROPIC_API_KEY="your-api-key"
   export WORKFLOW_PROMPT_PREFIX="$HOME/OneDrive/Admin/Prompts"  # Path to system prompts
   ```

## Commands

### Initialize Project

```bash
workflow init [directory]
```

Creates `.workflow/` structure in the specified directory (default: current directory):
- `.workflow/config` - Project-level configuration
- `.workflow/project.txt` - Project description (optional, appended to system prompts)
- `.workflow/prompts/` - For generated system prompts
- `.workflow/output/` - For workflow output hardlinks

Opens `project.txt` and `config` in vim for editing, allowing you to describe the project context, goals, and file structure.

### Create Workflow

```bash
workflow new WORKFLOW_NAME
```

Creates a new workflow in the current project:
- Creates `.workflow/WORKFLOW_NAME/` directory
- Creates empty `task.txt` and template `config` files
- Opens both files in vim for editing

**Requirements:** Must be run within an initialized project (will search upward for `.workflow/`).

### Edit Workflow or Project

```bash
workflow edit [WORKFLOW_NAME]
```

**Without workflow name:** Opens project-level `project.txt` and `config` files for editing.

**With workflow name:** Opens workflow-specific `task.txt` and `config` files for editing.

**Requirements:** Must be run within an initialized project.

### Execute Workflow

```bash
workflow run WORKFLOW_NAME [options]
```

Executes a workflow by:
1. Finding project root (searches upward for `.workflow/`)
2. Loading configuration (3-tier cascade)
3. Building context from configured sources
4. Making API request (single-batch or streaming)
5. Saving output with hardlink in `.workflow/output/`

**Options:**
- `--stream` - Use streaming mode (real-time output)
- `--dry-run` - Estimate tokens without API call
- `--context-pattern GLOB` - Override context pattern
- `--context-file FILE` - Add additional context file (repeatable)
- `--depends-on WORKFLOW` - Add workflow dependency
- `--model MODEL` - Override model
- `--temperature TEMP` - Override temperature
- `--max-tokens NUM` - Override max tokens
- `--system-prompts LIST` - Override system prompts (comma-separated)
- `--output-format EXT` - Override output format/extension (md, txt, json, html, etc.)

## Configuration

### Project Configuration (`.workflow/config`)

Project-wide defaults sourced by all workflows:

```bash
# System prompts to concatenate (in order)
# Each name maps to $WORKFLOW_PROMPT_PREFIX/System/{name}.xml
SYSTEM_PROMPTS=(Root)

# API defaults
MODEL="claude-sonnet-4-5"
TEMPERATURE=1.0
MAX_TOKENS=4096

# Output format (extension without dot)
OUTPUT_FORMAT="md"
```

### Workflow Configuration (`.workflow/WORKFLOW_NAME/config`)

Workflow-specific settings that override project defaults:

```bash
# Context aggregation methods
# Note: Paths are relative to project root

# Method 1: Glob pattern (single pattern, supports brace expansion)
CONTEXT_PATTERN="References/*.md"
CONTEXT_PATTERN="References/{Topic1,Topic2}/*.md"

# Method 2: Explicit file list
CONTEXT_FILES=(
    "References/doc1.md"
    "References/doc2.md"
)

# Method 3: Workflow dependencies
DEPENDS_ON=(
    "00-workshop-context"
    "01-outline-draft"
)

# API overrides (optional)
MODEL="claude-sonnet-4-5"
TEMPERATURE=1.0
MAX_TOKENS=8192
SYSTEM_PROMPTS=(Root NeuroAI DataScience)

# Output format override
OUTPUT_FORMAT="json"
```

### Configuration Priority

Settings are applied in order (later overrides earlier):
1. Built-in defaults (Root prompt, standard API parameters)
2. Project config (`.workflow/config`)
3. Workflow config (`.workflow/WORKFLOW_NAME/config`)
4. Command-line flags (highest priority)

### Path Resolution

The workflow tool distinguishes between paths specified in configuration files versus command-line flags to enable the "work from anywhere" feature.

#### Config File Paths

**Context**: Paths in `CONTEXT_PATTERN` and `CONTEXT_FILES` within config files (`.workflow/config` or `.workflow/WORKFLOW_NAME/config`) are resolved **relative to the project root** (`PROJECT_ROOT`).

**Implementation**:
- `CONTEXT_PATTERN`: Executed in subshell with `cd "$PROJECT_ROOT"` before glob expansion
- `CONTEXT_FILES`: Each path prepended with `$PROJECT_ROOT/` before validation

**Benefits**:
- Workflows can be executed from any subdirectory within the project
- Config files remain location-independent
- Consistent with git-like project structure

**Example**:
```bash
# In .workflow/my-workflow/config
CONTEXT_PATTERN="References/*.md"
CONTEXT_FILES=("data/results.md")

# Works identically from:
# - /project/
# - /project/subdir/
# - /project/.workflow/my-workflow/
```

#### Command-Line Paths

**Context**: Paths provided via `--context-file` and `--context-pattern` flags are resolved **relative to the current working directory** (PWD where the command is executed).

**Implementation**:
- Stored separately in `CLI_CONTEXT_FILES` and `CLI_CONTEXT_PATTERN`
- Processed without path modification (standard shell behavior)

**Benefits**:
- Standard CLI tool behavior (matches git, ls, cat, etc.)
- Enables ad-hoc context inclusion from anywhere
- Flexible for one-off workflow runs

**Example**:
```bash
# From /project/subdir/
workflow run NAME --context-file ./local.md
# Resolves to: /project/subdir/local.md

workflow run NAME --context-file ../data/external.md
# Resolves to: /project/data/external.md
```

#### Glob Pattern Features

**Brace Expansion**: `CONTEXT_PATTERN` supports bash brace expansion for multiple directories:
```bash
CONTEXT_PATTERN="References/{Topic1,Topic2,Topic3}/*.md"
# Expands to: References/Topic1/*.md References/Topic2/*.md References/Topic3/*.md
```

**Spaces in Directory Names**: Escape with backslash:
```bash
CONTEXT_PATTERN="References/{Modeling\ Topic,Testing\ Topic}/*.md"
```

**Single Pattern Only**: `CONTEXT_PATTERN` accepts one glob pattern (with brace expansion). For multiple independent patterns or complex selection, use `CONTEXT_FILES` array.

#### Technical Details

**Processing Order**:
1. Config-sourced `CONTEXT_PATTERN` (relative to `PROJECT_ROOT`)
2. CLI-provided `CLI_CONTEXT_PATTERN` (relative to PWD)
3. Config-sourced `CONTEXT_FILES` array (relative to `PROJECT_ROOT`)
4. CLI-provided `CLI_CONTEXT_FILES` array (relative to PWD)

**Error Handling**:
- Config paths: Error message includes both user-provided path and resolved absolute path
- CLI paths: Error message shows path as provided (user knows their PWD)
- Missing files halt execution immediately

**Performance**:
- Paths validated in loop, then single `filecat` call per array (efficient)
- Glob expansion happens once in appropriate directory context

## System Prompts

System prompts are XML-formatted text files concatenated in the specified order:
- Located at `$WORKFLOW_PROMPT_PREFIX/System/{name}.txt`
- `Root` prompt typically included first (baseline instructions)
- Additional prompts add domain-specific context
- Concatenated into `.workflow/prompts/system.txt`
- **Rebuilt on every workflow run** to ensure current configuration is used
- Cached version used as fallback if rebuild fails

### Project Description

Optional `.workflow/project.txt` file provides project-specific context:
- Created during `workflow init` and opened in vim for editing
- If non-empty, automatically appended to system prompt for all workflows
- Wrapped in XML tags via `filecat` (e.g., `<project>...</project>`)
- Useful for describing codebase structure, project goals, conventions, etc.
- Leave empty if not needed (no impact on system prompt)

**Example use cases:**
- Describe manuscript goals and target journal
- Document folder structure and file organization
- Specify writing style or formatting requirements
- Provide background on collaborators or stakeholders

## Output Formats

Workflows can generate output in any text-based format:
- Specify via `OUTPUT_FORMAT` in config (extension without dot)
- Default: `md` (Markdown)
- Common formats: `txt`, `json`, `html`, `xml`, `csv`, etc.
- Output files: `.workflow/NAME/output.{format}`
- Hardlinks: `.workflow/output/NAME.{format}`

### Format Hint in User Prompt

For non-markdown formats, the tool automatically appends an XML tag to guide the LLM:
- **Markdown** (`md`): No tag added (default behavior)
- **Other formats**: Appends `<output-format>{format}</output-format>` to user prompt
- Example: If `OUTPUT_FORMAT="json"`, prompt includes `<output-format>json</output-format>`
- Helps ensure LLM generates output in the requested format

### Format-Specific Post-Processing

The tool automatically applies format-specific formatting when available:
- **Markdown** (`md`): Runs `mdformat` if installed
- **JSON** (`json`): Runs `jq` for pretty-printing if installed
- **Other formats**: No automatic formatting (raw output)

### Cross-Format Dependencies

Dependencies can use different output formats:
- Dependency resolution uses glob pattern (`.workflow/output/NAME.*`)
- Allows mixing formats (e.g., JSON data + Markdown text)
- All formats concatenated into context using `filecat` XML tags

## Context Aggregation

Three methods for building workflow context (can be combined):

### 1. Glob Patterns

```bash
CONTEXT_PATTERN="References/*.md"
```

Uses `filecat` to concatenate all matching files with visual separators. Paths are relative to project root.

### 2. Explicit Files

```bash
CONTEXT_FILES=(
    "data/results.md"
    "notes/analysis.md"
)
```

Maintains exact ordering of specified files. Paths are relative to project root.

### 3. Workflow Dependencies

```bash
DEPENDS_ON=(
    "01-outline-draft"
    "02-intro"
)
```

Includes outputs from previously executed workflows. Reads from `.workflow/output/` hardlinks.

## Usage Examples

### Initialize and Create First Workflow

```bash
# Navigate to project directory
cd ~/projects/my-manuscript

# Initialize workflow project
workflow init .

# Create first workflow
workflow new 00-context-analysis

# Edit opens automatically - configure context sources and task
```

### Execute Workflows

```bash
# Execute with default settings (from config)
workflow run 00-context-analysis

# Execute with streaming output
workflow run 00-context-analysis --stream

# Execute with overrides
workflow run 01-outline --depends-on 00-context-analysis --max-tokens 8192
```

### Chain Workflows

```bash
# Workflow 1: Analyze workshop materials
workflow new 00-workshop-context
# In config: CONTEXT_PATTERN="Workshops/*.md"
workflow run 00-workshop-context

# Workflow 2: Draft outline using workshop analysis
workflow new 01-outline-draft
# In config: DEPENDS_ON=("00-workshop-context")
workflow run 01-outline-draft

# Workflow 3: Draft introduction using both
workflow new 02-intro-draft
# In config: DEPENDS_ON=("00-workshop-context" "01-outline-draft")
workflow run 02-intro-draft
```

### Work from Anywhere

```bash
# Can run from project root
cd ~/projects/my-manuscript
workflow run 01-outline

# Or from subdirectory - finds .workflow/ automatically
cd ~/projects/my-manuscript/drafts
workflow run 01-outline

# Or from workflow directory
cd ~/projects/my-manuscript/.workflow/01-outline
workflow run 01-outline
```

## Token Estimation

Estimates displayed before each API call:
```
Estimated system tokens: 6633
Estimated task tokens: 4294
Estimated context tokens: 12450
Estimated total input tokens: 23377
```

Formula: `(word_count * 1.3) + 4096`

Use `--dry-run` to estimate without making API request.

## Output Management

- Workflow output saved to `.workflow/WORKFLOW_NAME/output.md`
- Hardlink created at `.workflow/output/WORKFLOW_NAME.md`
- Hardlinks visible in Finder/Obsidian (unlike symlinks)
- Previous outputs backed up with timestamps (YYYYMMDDHHMMSS)
- Optional `mdformat` post-processing if available

## Dependencies

### Required
- `bash` 4.0+
- `curl` - API requests
- `jq` - JSON processing

### Environment Variables
- `ANTHROPIC_API_KEY` - Anthropic API access
- `WORKFLOW_PROMPT_PREFIX` - Base path to system prompt directory

### Optional
- `mdformat` - Markdown formatting
- `EDITOR` - Text editor (default: `vim`)

## Key Features

### Portable
- Single script, can be on PATH
- Works from any directory within project
- Project root auto-discovery (like git)

### Flexible Configuration
- Three-tier configuration cascade
- Command-line overrides
- Per-workflow customization

### Workflow Chaining
- Depends-on mechanism
- Hardlinked outputs
- DAG-style dependencies

### Context Management
- Multiple aggregation methods
- Glob patterns with `filecat`
- Explicit file lists
- Workflow output dependencies

### User Experience
- Streaming or batch API modes
- Token estimation before calls
- Automatic output backup
- Helpful error messages

## Migration from Previous Version

If you have an existing project with the old structure:

```bash
# In your Work/ directory:
mkdir .workflow
mv config prompts output .workflow/
mv 00-workshop-context .workflow/

# Convert run.sh to config
cd .workflow/00-workshop-context
# Extract config variables from run.sh into config file
# Delete run.sh

# Test
cd ../..
workflow run 00-workshop-context --dry-run
```

## Troubleshooting

### "Not in workflow project"
- Run `workflow init` to initialize
- Or navigate to directory containing `.workflow/`

### "Workflow not found"
- Use `workflow new NAME` to create
- Check workflow exists: `ls .workflow/`

### "WORKFLOW_PROMPT_PREFIX not set"
- Set in `~/.bashrc`: `export WORKFLOW_PROMPT_PREFIX="path/to/prompts"`
- Reload shell: `source ~/.bashrc`

### Context files not found
- Paths in config are relative to project root
- Use `--dry-run` to test without API call
- Check glob patterns expand correctly

## Notes

- System prompts use XML formatting for structured instructions
- The `filecat()` function adds visual separators between files
- Workflow configs are bash scripts - can include shell logic
- Command-line context options augment (not replace) config
- Hardlinks updated atomically for safe concurrent access
