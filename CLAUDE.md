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

#### Config Inheritance

When initializing a project inside an existing workflow project, the tool automatically detects the parent and offers config inheritance:

**Detection:**
- Uses `find_project_root()` from target directory to search upward for parent `.workflow/`
- Stops at HOME or root directory (same boundaries as normal project discovery)

**Inheritance Process:**
1. Detects parent project and warns about nested namespace
2. Asks user for confirmation
3. If confirmed, extracts inheritable config values from parent:
   - `extract_parent_config()`: Sources parent config in isolated subshell
   - Extracts: MODEL, TEMPERATURE, MAX_TOKENS, SYSTEM_PROMPTS, OUTPUT_FORMAT
   - Does NOT inherit: project.txt, workflows, context settings
4. Displays inherited values to user
5. Creates new project config with inherited defaults

**Benefits:**
- Multi-project workflows maintain consistent configuration
- Related subprojects automatically use parent settings
- User can still edit config afterward to customize
- Safe: Subshell isolation prevents side effects

**Example:**
```bash
# In /research/neuroai-project with custom config
cd subprojects/experiment-1
workflow init .
# Prompts user, inherits MODEL, SYSTEM_PROMPTS, etc.
```

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

### View Configuration

```bash
workflow config [WORKFLOW_NAME]
```

Display current configuration with source tracking and option to edit.

**Without workflow name (project config):**
- Shows effective project configuration (defaults + project overrides)
- Lists all workflows with last-run timestamps
- Indicates source for each parameter: (default) or (project)
- Interactive prompt to edit project.txt and config

**With workflow name (workflow config):**
- Shows full configuration cascade (default → project → workflow)
- Indicates source for each parameter: (default), (project), or (workflow)
- Shows workflow-specific settings (CONTEXT_PATTERN, CONTEXT_FILES, DEPENDS_ON)
- Interactive prompt to edit workflow task.txt and config

**Source indicators:**
- `(default)` - Using global DEFAULT_* constant (transparent pass-through)
- `(project)` - Set explicitly in `.workflow/config`
- `(workflow)` - Set explicitly in `.workflow/WORKFLOW_NAME/config`

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

### Execute Task (Lightweight Mode)

```bash
workflow task NAME [options]
workflow task --inline TEXT [options]
workflow task -i TEXT [options]
```

Execute one-off tasks without creating workflow directories. Designed for quick, temporary requests that don't need to be persisted.

**Task Mode Execution Flow:**
1. Optional project discovery (non-fatal if not found)
2. Load config: global → project (if found) → CLI overrides
3. Load task from file or inline specification
4. Build system prompt (same as run mode, uses project cache if available)
5. Aggregate context from CLI flags only (temporary file)
6. Estimate tokens
7. Execute API request (streaming by default)
8. Optional: Save to file if `--output-file` specified

**Task Specification:**
- **Named tasks:** Load from `$WORKFLOW_TASK_PREFIX/<NAME>.txt` file
  - Requires `WORKFLOW_TASK_PREFIX` environment variable
  - Useful for frequently-used task templates
- **Inline tasks:** Specify directly with `--inline` or `-i` flag
  - No environment setup required
  - Ideal for one-time requests

**Key Differences from Run Mode:**

| Aspect | Run Mode | Task Mode |
|--------|----------|-----------|
| **Project required** | Yes | No (optional) |
| **Workflow directory** | Required | Not used |
| **Task source** | `.workflow/NAME/task.txt` | `$WORKFLOW_TASK_PREFIX/<NAME>.txt` or inline |
| **Config tiers** | Global → Project → Workflow | Global → Project only |
| **Context sources** | Config + CLI (5 sources) | CLI only (2 sources) |
| **Default output** | File in workflow dir | Stream to stdout |
| **Output file** | Always created | Optional via `--output-file` |
| **Streaming** | Opt-in via `--stream` | Default (opt-out via `--no-stream`) |
| **Dependencies** | Supported | Not supported |

**Options:**
- `--inline TEXT`, `-i TEXT` - Inline task (alternative to NAME)
- `--output-file PATH` - Save output to file (optional)
- `--stream` - Stream output (default: true)
- `--no-stream` - Use single-batch mode
- `--context-file FILE` - Add context file (repeatable, relative to PWD)
- `--context-pattern GLOB` - Add files matching pattern (relative to PWD)
- `--model MODEL` - Override model
- `--temperature TEMP` - Override temperature
- `--max-tokens NUM` - Override max tokens
- `--system-prompts LIST` - Override system prompts (comma-separated)
- `--output-format EXT` - Output format (md, txt, json, etc.)
- `--dry-run` - Estimate tokens without API call

**Implementation Details:**
- Located in `lib/task_mode.sh`, sourced when `TASK_MODE=true`
- Uses temporary files for context and output (unless `--output-file` specified)
- Reuses all core functionality: system prompt building, token estimation, API execution
- Gracefully handles missing project (uses global config only)
- Cleans up temp files via trap on exit

## Configuration

### Global User Configuration

The workflow tool automatically creates a global configuration directory at `~/.config/workflow/` on first use:

**Auto-created files:**
- `config` - Global defaults for API settings
- `prompts/base.txt` - Default system prompt

This makes the tool self-contained and immediately usable without requiring environment variable setup.

**Location:** `~/.config/workflow/config`

**Default contents:**
```bash
# Global Workflow Configuration
MODEL="claude-sonnet-4-5"
TEMPERATURE=1.0
MAX_TOKENS=4096
OUTPUT_FORMAT="md"
SYSTEM_PROMPTS=(base)

# System prompt directory - points to included prompts
WORKFLOW_PROMPT_PREFIX="$HOME/.config/workflow/prompts"

# Optional: API key (env var preferred for security)
# ANTHROPIC_API_KEY=""
```

**Benefits:**
- Change global config once to affect all uncustomized projects
- Tool works out-of-the-box without environment variable setup
- Clear distinction between inherited and customized values
- Easy reset: set to empty to restore pass-through
- View effective config with source tracking via `workflow config`

### Configuration Pass-Through

The tool uses **transparent pass-through** for configuration parameters. Empty values inherit from parent tier, while explicit values "own" the parameter.

**The Rule:**
- **Empty value** (`MODEL=`): Passes through to parent tier (transparent)
- **Explicit value** (`MODEL="claude-opus-4"`): Owns parameter (decoupled from parent changes)

**Example:**
```bash
# Global ~/.config/workflow/config:
MODEL="claude-sonnet-4-5"

# Project .workflow/config (empty = pass-through):
MODEL=

# Workflow config (empty = pass-through):
MODEL=

# Result: Uses claude-sonnet-4-5
# Change global config → all empty configs update automatically
```

### Project Configuration (`.workflow/config`)

Project-wide settings (empty values pass through to global defaults):

```bash
# Leave empty to use global defaults (recommended):
MODEL=
TEMPERATURE=
MAX_TOKENS=
SYSTEM_PROMPTS=()
OUTPUT_FORMAT=

# Or set explicit values to override globally:
# MODEL="claude-opus-4"
# TEMPERATURE=0.7
# MAX_TOKENS=8192
# SYSTEM_PROMPTS=(Root NeuroAI)
# OUTPUT_FORMAT="json"
```

**Note:** Project configs do NOT have CONTEXT_PATTERN, CONTEXT_FILES, or DEPENDS_ON (those are workflow-specific).

### Workflow Configuration (`.workflow/WORKFLOW_NAME/config`)

Workflow-specific settings:

```bash
# Context sources (workflow-specific, not inherited from project)
# Paths are relative to project root
CONTEXT_PATTERN="References/*.md"
CONTEXT_PATTERN="References/{Topic1,Topic2}/*.md"
CONTEXT_FILES=("References/doc1.md" "References/doc2.md")
DEPENDS_ON=("00-workshop-context" "01-outline-draft")

# API parameters (leave empty to inherit from project/global defaults)
# MODEL="claude-opus-4"
# TEMPERATURE=0.7
# MAX_TOKENS=8192
# SYSTEM_PROMPTS=(Root NeuroAI)
# OUTPUT_FORMAT="json"
```

### Configuration Priority

Settings cascade through four tiers (empty values pass through, non-empty override):
1. Global config (`~/.config/workflow/config`) - User defaults, with fallback to hard-coded defaults
2. Project config (`.workflow/config`) - Inherits from #1 if empty
3. Workflow config (`.workflow/WORKFLOW_NAME/config`) - Inherits from #2 if empty
4. Command-line flags - Always override (highest priority)

**Graceful degradation:** If global config is unavailable (permissions issues, etc.), the tool falls back to hard-coded defaults and continues to function.

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
- Located at `$WORKFLOW_PROMPT_PREFIX/{name}.txt`
- `base` prompt typically included first (baseline instructions)
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
