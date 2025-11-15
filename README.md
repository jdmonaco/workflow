# Workflow - AI-Assisted Writing Tool

A portable CLI tool for managing AI-assisted manuscript development workflows using the Anthropic Messages API. Features git-like project structure, flexible configuration cascading, context aggregation, and workflow chaining.

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

Add to `~/.bashrc` or `~/.bash_profile`:

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export WORKFLOW_PROMPT_PREFIX="$HOME/prompts"  # Path to your system prompt directory
```

## Usage

### Initialize Project

```bash
workflow init [directory]
```

Creates `.workflow/` structure with config and output directories. Opens `project.txt` and `config` in vim for editing.

The optional `project.txt` file lets you describe project goals, folder structure, and conventions. If non-empty, it's automatically appended to the system prompt for all workflows.

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
- `--system-prompts "Root,Custom"` - Override system prompts
- `--output-format EXT` - Output file extension (md, txt, json, html, etc.)

## Configuration

### Project Config (`.workflow/config`)

Project-wide defaults:

```bash
# System prompts to concatenate
SYSTEM_PROMPTS=(Root)

# API defaults
MODEL="claude-sonnet-4-5"
TEMPERATURE=1.0
MAX_TOKENS=4096

# Output format
OUTPUT_FORMAT="md"
```

### Workflow Config (`.workflow/WORKFLOW_NAME/config`)

Workflow-specific overrides:

```bash
# Context from glob pattern (relative to project root)
CONTEXT_PATTERN="References/*.md"

# Or explicit files (relative to project root)
CONTEXT_FILES=(
    "data/results.md"
    "notes/analysis.md"
)

# Or workflow dependencies
DEPENDS_ON=(
    "00-workshop-context"
    "01-outline-draft"
)

# API overrides
MAX_TOKENS=8192

# Output format override
OUTPUT_FORMAT="txt"
```

### Configuration Priority

1. Built-in defaults
2. Project config (`.workflow/config`)
3. Workflow config (`.workflow/NAME/config`)
4. Command-line flags ← highest priority

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

System prompts are XML-formatted text files at `$WORKFLOW_PROMPT_PREFIX/System/{name}.txt`:

```
$WORKFLOW_PROMPT_PREFIX/
└── System/
    ├── Root.txt        # Base prompt (always included first)
    ├── NeuroAI.txt     # Domain-specific
    ├── DataScience.txt
    └── Writing.txt
```

Configure in project or workflow config:

```bash
SYSTEM_PROMPTS=(Root NeuroAI Writing)
```

Or override from command line:

```bash
workflow run my-workflow --system-prompts "Root,DataScience"
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
