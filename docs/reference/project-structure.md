# Project Structure

Complete reference for Workflow project directory structure and file organization.

## Overview

A Workflow project is identified by the `.workflow/` directory, which contains all configuration, workflows, and outputs.

## Complete Project Structure

```
my-project/
├── .workflow/                           # Workflow project root
│   ├── config                           # Project-level configuration
│   ├── project.txt                      # Project description (optional)
│   ├── prompts/                         # System prompt cache
│   │   └── system.txt                   # Cached composed system prompt
│   ├── output/                          # Hardlinks to workflow outputs
│   │   ├── 00-context.md                # → 00-context/output/<name>.md
│   │   ├── 01-analysis.md               # → 01-analysis/output/<name>.md
│   │   └── 02-report.md                 # → 02-report/output/<name>.md
│   ├── 00-context/                      # Individual workflow
│   │   ├── task.txt                     # Task description
│   │   ├── config                       # Workflow configuration
│   │   ├── context/                     # Optional context files
│   │   └── output/                      # Workflow outputs
│   │       ├── <name>.md              # Latest output
│   │       ├── <name>-20241115143022.md
│   │       └── <name>-20241115141530.md
│   ├── 01-analysis/                     # Individual workflow
│   │   ├── task.txt
│   │   ├── config
│   │   ├── context/
│   │   └── output/
│   │       └── <name>.md
│   └── 02-report/                       # Individual workflow
│       ├── task.txt
│       ├── config
│       ├── context/
│       └── output/
│           └── <name>.md
├── data/                                # Project content (example)
├── references/                          # Project content (example)
└── README.md                            # Project content (example)
```

## Directory Descriptions

### `.workflow/` (Project Root)

The presence of this directory marks a workflow project. All workflow-related files are stored here.

**Created by:** `wfw init`

**Contents:**

- Project configuration files
- Workflow directories
- Output hardlinks
- Prompt cache

### `.workflow/config`

Project-level configuration file.

**Format:** Bash variable assignments

**Purpose:** Set defaults for all workflows in the project

**Example:**

```bash
MODEL=claude-opus-4-5-20251101
TEMPERATURE=0.8
MAX_TOKENS=8192
SYSTEM_PROMPTS=(base research)
OUTPUT_FORMAT=md
```

**See:** [Configuration Guide](../user-guide/configuration.md)

### `.workflow/project.txt`

Optional project description file.

**Format:** Plain text

**Purpose:** Provide context about the project to Claude

**Behavior:** If non-empty, contents are wrapped in `<project>` tags and appended to system prompt for all workflows

**Example:**

```
Research manuscript on neural dynamics.

Directory structure:
- data/ : Neural recordings (HDF5)
- analysis/ : Python analysis scripts
- figures/ : Generated plots (PDF)

Conventions:
- Use SI units
- APA format for statistics
- PEP 8 for code
```

**See:** [System Prompts Guide](../user-guide/system-prompts.md)

### `.workflow/prompts/`

System prompt cache directory.

**Created by:** First workflow run

**Contents:**

- `system.txt` - Cached composed system prompt from last run

**Purpose:** Debug system prompts and provide fallback if rebuild fails

**Note:** This is generated content - safe to delete, will be regenerated

### `.workflow/output/`

Hardlink directory for quick access to workflow outputs.

**Created by:** First workflow run

**Contents:** Hardlinks to `.workflow/<name>/output.<format>`

**Purpose:**

- Quick access to all outputs in one place
- No file duplication (hardlinks reference same data)

**Example:**

```
.workflow/output/
├── 00-context.md      # → 00-context/output/<name>.md
├── 01-analysis.md     # → 01-analysis/output/<name>.md
└── 02-report.json     # → 02-report/output/<name>.json
```

### `.workflow/<name>/`

Individual workflow directories.

**Created by:** `wfw new <name>`

**Contents:** Workflow-specific files (task.txt, config, context/, output/)

**Naming:** Workflow names (alphanumeric, hyphens, underscores)

## Workflow Directory Structure

Each workflow has its own subdirectory under `.workflow/<name>/`.

### `<name>/task.txt`

The task description or prompt for this workflow.

**Format:** Plain text (any length)

**Purpose:** Instructions for Claude on what to do

**Created by:** `wfw new <name>`

**Edited by:** `wfw edit <name>` or direct text editor

**Example:**

```
Analyze the provided data and create a summary report including:

1. Data overview (rows, columns, data types)
2. Statistical summary
3. Missing value analysis
4. Key findings

Format as structured markdown.
```

### `<name>/config`

Workflow-specific configuration.

**Format:** Bash variable assignments

**Purpose:** Configure this workflow's behavior and context

**Created by:** `wfw new <name>`

**Common variables:**

```bash
# Context aggregation
CONTEXT_PATTERN="data/*.csv"
CONTEXT_FILES=("notes.md" "references.txt")
DEPENDS_ON=("00-context" "01-preprocessing")

# API overrides (optional)
MODEL=claude-opus-4-5-20251101
TEMPERATURE=0.5
MAX_TOKENS=8192
SYSTEM_PROMPTS=(base stats)
OUTPUT_FORMAT=json
```

**See:** [Configuration Guide](../user-guide/configuration.md)

### `<name>/context/`

Optional directory for workflow-specific context files.

**Created by:** User (as needed)

**Purpose:** Store context files specific to this workflow

**Usage:** Reference in config with `CONTEXT_FILES=("context/myfile.txt")`

**Note:** Not commonly used - most projects reference files from project root

### `<name>/`

Workflow directory containing all workflow-specific files.

**Created by:** `wfw new <name>` and `wfw run <name>`

**Contents:**

- `config` - Workflow configuration
- `task.txt` - Task description/prompt
- `context/` - Optional context files directory
- `cache/` - Cached processed files (images, Office→PDF conversions)
- `output.<format>` - Latest output
- `output-TIMESTAMP.<format>` - Previous versions (automatic backups)
- `system-blocks.json` - JSON system content blocks (for debugging)
- `user-blocks.json` - JSON user content blocks (for debugging)
- `request.json` - Full API request JSON (dry-run mode)
- `document-map.json` - Citation index mapping (if citations enabled)

**Hardlink:** Output also accessible at `.workflow/output/<name>.<format>`

**Automatic backups:** Each run backs up previous output with timestamp before overwriting

## Global Configuration

### `~/.config/wireflow/`

Global user configuration directory.

**Created by:** First run of any workflow command

**Purpose:** User-wide defaults and shared resources

**Contents:**

```
~/.config/wireflow/
├── config                 # Global configuration
├── prompts/               # System prompts
│   ├── base.txt          # Default prompt (auto-created)
│   ├── research.txt      # Custom prompts (user-created)
│   ├── code.txt
│   └── stats.txt
└── tasks/                 # Named tasks (optional)
    ├── summarize.txt
    └── extract.txt
```

### `~/.config/wireflow/config`

Global configuration file.

**Purpose:** Default settings for all projects

**Auto-created:** First run with sensible defaults

**See:** [Configuration Guide](../user-guide/configuration.md)

### `~/.config/wireflow/prompts/`

System prompt directory.

**Purpose:** Store reusable system prompts

**Auto-created:** First run with `base.txt`

**Custom prompts:** Users can add their own `.txt` files here

**See:** [System Prompts Guide](../user-guide/system-prompts.md)

### `~/.config/wireflow/tasks/`

Optional named task directory.

**Purpose:** Store reusable task templates for `wfw task <name>`

**Created by:** User (as needed)

**Set via:** `WIREFLOW_TASK_PREFIX` environment variable or config

## File Naming Conventions

### Workflow Names

- **Allowed:** Alphanumeric, hyphens, underscores
- **Recommended:** Lowercase with hyphens
- **Examples:** `01-analysis`, `data-preprocessing`, `final-report`

### Output Files

Format: `<name>.<format>`

Where `<format>` is determined by `OUTPUT_FORMAT` config or `--format` flag.

**Examples:**

- `<name>.md` (Markdown)
- `<name>.json` (JSON)
- `<name>.txt` (Plain text)
- `<name>.html` (HTML)

### Backup Files

Format: `<name>.<format>.backup.YYYYMMDD_HHMMSS`

**Example:** `<name>-20241115143022.md`

## Path Resolution Rules

### Config File Paths

Paths in config files are **relative to project root**:

```bash
# In .workflow/config or .workflow/<name>/config
CONTEXT_PATTERN="data/*.csv"          # → <project-root>/data/*.csv
CONTEXT_FILES=("notes/doc.md")        # → <project-root>/notes/doc.md
```

### CLI Paths

Paths from command-line flags are **relative to PWD** (current working directory):

```bash
cd /project/subdir
wfw run analysis -cx local.md
# Looks for: /project/subdir/local.md
```

### System Prompt Paths

System prompts are resolved from `$WIREFLOW_PROMPT_PREFIX`:

```bash
SYSTEM_PROMPTS=(base research)
# Looks for:
#   $WIREFLOW_PROMPT_PREFIX/base.txt
#   $WIREFLOW_PROMPT_PREFIX/research.txt
```

## Project Discovery

The tool finds the project root by walking **up** the directory tree looking for `.workflow/`:

```
/home/user/project/
├── .workflow/              ← Project root found here
├── data/
│   └── subdir/
│       └── [you are here]  ← workflow list still finds .workflow/
└── analysis/
```

Run `workflow` commands from **anywhere** in your project tree.

## Version Control

### Recommended `.gitignore`

```gitignore
# Ignore outputs and caches
.workflow/*/output/
.workflow/prompts/system.txt
.workflow/output/

# Optional: Ignore context directory if it contains large files
# .workflow/*/context/
```

### Files to Commit

```
- ✅ .workflow/config
- ✅ .workflow/project.txt
- ✅ .workflow/*/task.txt
- ✅ .workflow/*/config
❌ .workflow/*/output/
❌ .workflow/prompts/system.txt
❌ .workflow/output/
```

## Nested Projects

Projects can be nested inside other projects:

```
research-project/
├── .workflow/                    # Parent project
│   ├── config
│   └── 01-literature-review/
└── experiment-1/
    ├── .workflow/                # Nested project (independent)
    │   ├── config                # Can inherit from parent
    │   └── 01-preprocess/
    └── data/
```

**Key points:**

- Nested projects have **independent workflow namespaces**
- Can **inherit configuration** from parent on creation
- Workflows **cannot depend** across project boundaries

**See:** [Initialization Guide](../user-guide/initialization.md#nested-projects)

## Disk Space Considerations

### Hardlinks

Output hardlinks do **not** duplicate data:

- `.workflow/<name>/output.md`
- `.workflow/output/<name>.md`

Both files are **hardlinks** pointing to the same data on disk.

### Backups

Each workflow run creates a timestamped backup:

```
output/
├── <name>.md                        # Latest (e.g., 50 KB)
├── <name>-20241115143022.md # Previous (50 KB)
├── <name>-20241115141530.md # Older (48 KB)
└── <name>-20241115135812.md # Oldest (45 KB)
```

**Total:** 193 KB for 4 versions

Disk usage grows with iterations. Periodically clean old backups if needed.

## File Permissions

### Recommended Permissions

```bash
chmod 700 ~/.config/wireflow/           # User-only access to global config
chmod 600 ~/.config/wireflow/config     # Protect API key
chmod 755 .workflow/                    # Project dir
chmod 644 .workflow/config              # Config files
chmod 644 .workflow/*/task.txt
chmod 644 .workflow/*/output/*
```

### API Key Security

**Never commit:** `ANTHROPIC_API_KEY` to version control

**Secure storage options:**

1. Environment variable (add to `~/.bashrc`)
2. Global config with restricted permissions (`chmod 600`)
3. External secret management tool

## Cleanup and Maintenance

### Remove Old Backups

```bash
# Remove backups older than 7 days
find .workflow/*/ -name "output-*.*" -mtime +7 -delete
```

### Remove Workflow

```bash
rm -r .workflow/old-workflow
rm .workflow/output/old-workflow.*  # Remove hardlink
```

### Reset Project

```bash
# Keep config, remove all outputs and workflows
rm -r .workflow/*/output/
rm -r .workflow/output/
# Or start fresh:
rm -r .workflow
wfw init .
```

## See Also

- [Initialization Guide](../user-guide/initialization.md) - Creating projects
- [Configuration Guide](../user-guide/configuration.md) - Configuration files
- [Execution Guide](../user-guide/execution.md) - Running workflows

---

Continue to [Output Formats](output-formats.md) →
