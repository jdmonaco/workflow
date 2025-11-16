# Workflow - A CLI Tool for Persistent, Configurable AI-Assisted Project Development

A portable CLI tool for managing AI-assisted research and project development workflows using the Anthropic Messages API. Features git-like project structure, flexible configuration cascading, context aggregation, and workflow chaining.

## Features

- **🎯 Git-like Structure** - Uses `.workflow/` directories with automatic project root discovery
- **🔧 Flexible Configuration** - Three-tier cascade: defaults → project → workflow → CLI
- **🔗 Workflow Chaining** - Build pipelines with `--depends-on` dependencies
- **📦 Context Aggregation** - Glob patterns, explicit files, or workflow outputs
- **🚀 Portable** - Single bash script, works from anywhere in project tree
- **💾 Safe Output** - Automatic backups with timestamps, hardlinked outputs
- **⚡ Streaming Support** - Real-time or batch API modes
- **📊 Token Estimation** - Cost estimation before API calls

## Quick Start

```bash
# Install
curl -o ~/bin/workflow https://raw.githubusercontent.com/username/workflow/main/workflow.sh
chmod +x ~/bin/workflow

# Set up environment
export ANTHROPIC_API_KEY="your-key"
export WORKFLOW_PROMPT_PREFIX="$HOME/path/to/prompts"

# Initialize project
cd my-manuscript
workflow init .

# Create and run first workflow
workflow new 00-context-analysis
# Edit task and config in vim...
workflow run 00-context-analysis --stream
```

## Installation

### Prerequisites

- `bash` 4.0+
- `curl`, `jq` (for API interaction)
- Anthropic API key

### Install Script

```bash
# Download
curl -o ~/bin/workflow https://raw.githubusercontent.com/username/workflow/main/workflow.sh
chmod +x ~/bin/workflow

# Or clone repo
git clone https://github.com/username/workflow.git
cp workflow/workflow.sh ~/bin/workflow
chmod +x ~/bin/workflow
```

### Environment Setup

**Required:** Set your API key (or store in global config):

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

**Optional:** Override the default system prompt directory:

```bash
export WORKFLOW_PROMPT_PREFIX="$HOME/custom/prompts"
```

**Note:** On first use, workflow automatically creates `~/.config/workflow/` with default configuration and a system prompt, so WORKFLOW_PROMPT_PREFIX is only needed if you want to use custom prompts.

## Usage

### Getting Help

```bash
# Show main help
workflow help
workflow --help
workflow -h

# Show subcommand-specific help
workflow help <subcommand>
workflow <subcommand> -h
```

Examples:
```bash
workflow help run      # Detailed help for 'run' subcommand
workflow task -h       # Quick help for 'task' subcommand
```

### Initialize Project

```bash
workflow init [directory]
```

Creates `.workflow/` structure with config and output directories. Opens `project.txt` and `config` in vim for editing.

The optional `project.txt` file lets you describe project goals, folder structure, and conventions. If non-empty, it's automatically appended to the system prompt for all workflows.

**Config Inheritance:** When initializing a project inside an existing workflow project, the tool detects the parent and offers to inherit configuration defaults (MODEL, TEMPERATURE, MAX_TOKENS, SYSTEM_PROMPTS, OUTPUT_FORMAT). This creates a nested project with a separate workflow namespace but consistent configuration.

### Create Workflow

```bash
workflow new WORKFLOW_NAME
```

Creates workflow directory with `task.txt` and `config` files. Opens both in vim for editing.

### Edit Workflow or Project

```bash
workflow edit [WORKFLOW_NAME]
```

Opens files in vim for editing:
- **Without name:** Edits project-level `project.txt` and `config`
- **With name:** Edits workflow-specific `task.txt` and `config`

### View Configuration

```bash
workflow config [WORKFLOW_NAME]
```

Display current configuration with option to edit:
- **Without name:** Shows project configuration, lists workflows, prompts to edit project
- **With name:** Shows workflow configuration with cascade (default → project → workflow), prompts to edit workflow

**Source tracking:** Each parameter shows where its value comes from:
- `(default)` - Using global DEFAULT_* constant (transparent pass-through)
- `(project)` - Set explicitly in `.workflow/config`
- `(workflow)` - Set explicitly in `.workflow/WORKFLOW_NAME/config`

**Workflow-specific settings:** Displays CONTEXT_PATTERN, CONTEXT_FILES, DEPENDS_ON if configured.

### Execute Workflow

```bash
workflow run WORKFLOW_NAME [options]
```

**Common Options:**
- `--stream` - Stream output in real-time
- `--dry-run` - Estimate tokens without API call
- `--context-pattern "pattern"` - Override context glob pattern
- `--depends-on OTHER_WORKFLOW` - Add dependency
- `--max-tokens NUM` - Override max tokens
- `--system-prompts "base,Custom"` - Override system prompts
- `--output-format EXT` - Output file extension (md, txt, json, html, etc.)

### Execute Task (Lightweight Mode)

```bash
workflow task NAME [options]
workflow task --inline TEXT [options]
workflow task -i TEXT [options]
```

Execute one-off tasks without creating workflow directories. Task mode is designed for quick, temporary requests.

**Task specification (mutually exclusive):**
- **Named task:** `task NAME` loads from `$WORKFLOW_TASK_PREFIX/<NAME>.txt`
- **Inline task:** `task --inline "text"` or `task -i "text"` uses provided text directly

**Behavior:**
- Streams to stdout by default (no files created)
- Optional `--output-file PATH` to save response
- Uses project context if run from within a project (optional)
- Only supports CLI-provided context (`--context-file`, `--context-pattern`)
- No workflow dependencies, no workflow config

**Options:**
- `--inline TEXT`, `-i TEXT` - Inline task specification
- `--output-file PATH` - Save output to file
- `--no-stream` - Use single-batch mode instead of streaming
- All run mode options except `--depends-on`

**Examples:**
```bash
# Named task with context
workflow task summarize --context-file notes.md

# Inline task with pattern matching
workflow task -i "Extract action items" --context-pattern "meetings/*.md"

# Save output to file
workflow task -i "Analyze data" --context-file data.csv --output-file analysis.md

# Override model
workflow task summarize --model claude-opus-4 --context-file report.md
```

**Environment:**
- `WORKFLOW_TASK_PREFIX` - Directory containing named task .txt files (optional, only needed for named tasks)

## Configuration

### Global User Configuration

On first use, workflow automatically creates a global configuration directory at `~/.config/workflow/` with:

- **`config`** - Default API settings for all projects
- **`prompts/base.txt`** - Default system prompt

This makes the tool self-contained and ready to use out-of-the-box. You can customize these defaults once and affect all your projects.

**Location:** `~/.config/workflow/config`

**Contents:**
```bash
# Global Workflow Configuration
MODEL="claude-sonnet-4-5"
TEMPERATURE=1.0
MAX_TOKENS=4096
OUTPUT_FORMAT="md"
SYSTEM_PROMPTS=(base)

# System prompt directory - points to included prompts
WORKFLOW_PROMPT_PREFIX="$HOME/.config/workflow/prompts"

# Optional: Store API key here (environment variable preferred)
# ANTHROPIC_API_KEY="sk-ant-..."
```

**Four-tier configuration cascade:**
1. **Global config** (`~/.config/workflow/config`) - User defaults for all projects
2. **Project config** (`.workflow/config`) - Project-wide overrides
3. **Workflow config** (`.workflow/NAME/config`) - Workflow-specific overrides
4. **Command-line flags** - Highest priority

### Configuration Pass-Through

Project and workflow configs use **empty values** for transparent pass-through. This allows changing global defaults to affect all uncustomized projects.

**The rule:** Empty values inherit from parent tier. Explicit values "own" the parameter (decoupled from changes above).

**Example - Transparent cascading:**
```bash
# Global ~/.config/workflow/config: MODEL="claude-sonnet-4-5"
# Project .workflow/config: MODEL= (empty, passes through)
# Workflow config: MODEL= (empty, passes through)
# Result: Uses claude-sonnet-4-5

# Change global config: MODEL="claude-opus-4"
# Result: All empty configs now use claude-opus-4 automatically
```

**Example - Explicit ownership:**
```bash
# Project .workflow/config: MODEL="claude-opus-4"
# Workflow config: MODEL= (empty)
# Result: Uses claude-opus-4 from project (ignores global changes)
```

### Project Config (`.workflow/config`)

Project-wide settings (leave empty for global default pass-through):

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

### Workflow Config (`.workflow/WORKFLOW_NAME/config`)

Workflow-specific settings:

```bash
# Context sources (workflow-specific, not inherited)
# Paths are relative to project root
CONTEXT_PATTERN="References/*.md"
CONTEXT_FILES=("data/results.md" "notes/analysis.md")
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

1. **Global config** (`~/.config/workflow/config`) - User defaults, fallback to hard-coded defaults if unavailable
2. **Project config** (`.workflow/config`) - Inherits from #1 if empty
3. **Workflow config** (`.workflow/NAME/config`) - Inherits from #2 if empty
4. **Command-line flags** - Always override (highest priority)

### Path Resolution

**Config File Paths** (in `.workflow/config` or `.workflow/NAME/config`):
- `CONTEXT_PATTERN` and `CONTEXT_FILES` are **relative to project root**
- Allows workflow to run from any subdirectory
- Example: `CONTEXT_PATTERN="References/*.md"` always finds `<project-root>/References/*.md`

**Command-Line Paths** (from `--context-file` or `--context-pattern`):
- Paths are **relative to your current working directory** (PWD)
- Standard CLI behavior
- Example: Running from `project/subdir/` with `--context-file notes.md` finds `project/subdir/notes.md`

**Glob Pattern Features**:
- Supports brace expansion: `References/{Topic1,Topic2}/*.md`
- Single pattern only (use `CONTEXT_FILES` array for multiple explicit files)
- Spaces in directory names: escape with backslash `{Name\ One,Name\ Two}`

**Examples**:
```bash
# In config file (relative to project root):
CONTEXT_PATTERN="References/*.md"
CONTEXT_FILES=("data/results.md" "notes/analysis.md")

# From command line (relative to current directory):
cd project/subdir
workflow run NAME --context-file ./local.md  # Finds project/subdir/local.md
```

## Examples

### Simple Workflow

```bash
# Initialize
cd my-project
workflow init .
# Edit opens automatically - configure project.txt and config

# Edit project configuration later if needed
workflow edit

# Create workflow
workflow new analyze-data
```

In vim, edit **task.txt**:
```
Analyze the experimental results and summarize key findings.
```

Edit **config**:
```bash
CONTEXT_PATTERN="data/*.md"
```

```bash
# Run
workflow run analyze-data
```

### Chained Workflows

```bash
# Step 1: Gather context
workflow new 00-gather-context
# config: CONTEXT_PATTERN="references/*.md"
workflow run 00-gather-context

# Step 2: Create outline
workflow new 01-outline
# config: DEPENDS_ON=("00-gather-context")
workflow run 01-outline

# Step 3: Draft introduction
workflow new 02-intro
# config: DEPENDS_ON=("00-gather-context" "01-outline")
workflow run 02-intro --stream
```

### Nested Projects with Config Inheritance

```bash
# Parent project
cd ~/research/neuroai-project
workflow init .
# Configure: MODEL=claude-opus-4, SYSTEM_PROMPTS=(Root NeuroAI)

# Create nested subproject (inherits config)
cd experiments/experiment-1
workflow init .
# Output:
#   Initializing nested project inside existing project at:
#     /Users/name/research/neuroai-project
#
#   This will:
#     - Create a separate workflow namespace
#     - Inherit configuration defaults from parent
#   Continue? [y/N] y
#
#   Inheriting configuration from parent...
#     MODEL: claude-opus-4
#     SYSTEM_PROMPTS: Root NeuroAI
#     ...

# Nested project now has separate workflows but same config defaults
workflow new 01-analysis
```

### Override Settings

```bash
# Use different model
workflow run analyze-data --model claude-opus-4

# Increase max tokens
workflow run generate-draft --max-tokens 16384

# Add additional context
workflow run revise-section \
  --context-file ../new-data.md \
  --max-tokens 8192 \
  --stream
```

### Different Output Formats

```bash
# Generate JSON structured data
workflow new extract-data
# In config: OUTPUT_FORMAT="json"
workflow run extract-data

# Generate plain text summary
workflow run summarize-findings --output-format txt

# Mix formats in dependencies (markdown outline, JSON data, text summary)
workflow new final-report
# In config: DEPENDS_ON=("01-outline" "extract-data" "summarize-findings")
workflow run final-report
```

## Project Structure

```
my-manuscript/
├── .workflow/
│   ├── config                      # Project configuration
│   ├── project.txt                 # Project description (optional)
│   ├── prompts/
│   │   └── system.txt             # Generated system prompt
│   ├── output/
│   │   ├── 00-gather-context.md   # Hardlink to workflow output
│   │   ├── 01-outline.md
│   │   └── 02-intro.md
│   ├── 00-gather-context/
│   │   ├── config                 # Workflow config
│   │   ├── task.txt              # Task description
│   │   ├── context.txt           # Generated context
│   │   └── output.md             # API response
│   ├── 01-outline/
│   │   ├── config
│   │   ├── task.txt
│   │   ├── context.txt
│   │   └── output.md
│   └── 02-intro/
│       ├── config
│       ├── task.txt
│       ├── context.txt
│       └── output.md
├── references/
├── data/
└── ...
```

## System Prompts

System prompts are XML-formatted text files at `$WORKFLOW_PROMPT_PREFIX/{name}.txt`:

```
$WORKFLOW_PROMPT_PREFIX/
├── base.txt        # Base prompt (always included first)
├── NeuroAI.txt     # Domain-specific
├── DataScience.txt
└── Writing.txt
```

Configure in project or workflow config:

```bash
SYSTEM_PROMPTS=(base NeuroAI Writing)
```

Or override from command line:

```bash
workflow run my-workflow --system-prompts "base,DataScience"
```

**Note:** System prompts are rebuilt on every workflow run to ensure current configuration is used. The concatenated result is cached at `.workflow/prompts/system.txt` for debugging and as a fallback if rebuild fails.

### Project Description

Add project-specific context via `.workflow/project.txt`:

- Created during `workflow init` (opened in vim for editing)
- Describe project goals, folder structure, conventions, etc.
- If non-empty, automatically appended to system prompt for all workflows
- Wrapped in XML tags: `<project>...</project>`
- Leave empty if not needed

**Example project.txt:**
```
This manuscript project develops a brief commentary for submission to the
Journal of Neural Engineering. The References/ folder contains background 
materials and Templates/ contains LaTeX templates provided by the journal.
All drafts should emphasize high-level opportunities and challenges.
```

## Output Formats

Workflows support any text-based output format (default: `md`):

**Configure in workflow config:**
```bash
OUTPUT_FORMAT="json"  # or txt, html, xml, csv, etc.
```

**Override from command line:**
```bash
workflow run extract-data --output-format json
```

**Automatic format hints:**
- For non-markdown formats, `<output-format>{format}</output-format>` is appended to the user prompt
- Guides the LLM to generate output in the requested format

**Format-specific post-processing:**
- **Markdown** (`md`): Auto-formatted with `mdformat` if available
- **JSON** (`json`): Pretty-printed with `jq` if available

**Cross-format dependencies:**
- Dependencies work regardless of format
- Mix JSON data + Markdown text + plain text in the same workflow

## Advanced Features

### Context Aggregation Methods

Combine multiple methods in a single workflow:

```bash
# In .workflow/my-workflow/config (paths relative to project root)
CONTEXT_PATTERN="references/*.md"         # Glob pattern
CONTEXT_FILES=("data/specific.md")        # Explicit files
DEPENDS_ON=("previous-workflow")          # Workflow output
```

Plus add more from command line:

```bash
workflow run my-workflow --context-file ../extra.md
```

### Workflow Dependencies (DAG)

```
00-gather-context
    ↓
01-outline ←──────┐
    ↓             │
02-intro          │
    ↓             │
03-methods        │
    ↓             │
04-results ───────┘
    ↓
05-discussion
```

Each workflow's `DEPENDS_ON` reads from `.workflow/output/` hardlinks.

### Token Estimation

Before each API call:

```
Building context...
  Adding dependencies...
    - 00-gather-context (00-gather-context.md)
  Adding files from config pattern: references/*.md
Estimated system tokens: 6633
Estimated task tokens: 4294
Estimated context tokens: 12450
Estimated total input tokens: 23377

Sending Messages API request...
```

Use `--dry-run` to estimate without calling API.

### Streaming vs Batch

**Batch mode (default):**
- Blocks until complete
- Displays in `less` when done
- Reliable for long outputs

**Streaming mode (`--stream`):**
- Real-time output to terminal
- See progress as text generates
- Better for interactive use

## Troubleshooting

### "Not in workflow project"

Run `workflow init` or navigate to a directory containing `.workflow/`.

### "Workflow not found"

Create with `workflow new NAME`. Check existing: `ls .workflow/`.

### "WORKFLOW_PROMPT_PREFIX not set"

```bash
export WORKFLOW_PROMPT_PREFIX="$HOME/path/to/prompts"
```

Add to `~/.bashrc` to persist.

### Context files not aggregating

- Paths relative to project root (not `.workflow/`)
- Test patterns: `workflow run NAME --dry-run`
- Check glob expands: `echo ../references/*.md`

## Tips

- Use `--dry-run` to test configuration without API calls
- Workflow names like `00-first`, `01-second` maintain order
- Store `.workflow/config` in git for team collaboration
- Individual `.workflow/NAME/` dirs can be `.gitignore`d
- Hardlinks in `.workflow/output/` visible in file browsers
- Delete `.workflow/prompts/system.txt` to regenerate

## Contributing

Issues and pull requests welcome! See [CLAUDE.md](CLAUDE.md) for development details.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Related

- [Anthropic API Documentation](https://docs.anthropic.com/)
- [Claude Models](https://docs.anthropic.com/en/docs/models-overview)

---

Made with Claude Code
