# Projects

Initialize a wireflow project and understand what gets created.

## Basic Initialization

```bash
# Initialize in current directory
cd my-project
wfw init .

# Or initialize in a new directory
wfw init ~/research/my-analysis
```

### What Gets Created

```
your-project/
└── .workflow/
    ├── config              # Project-level configuration
    ├── project.txt         # Project description (appended to system prompt)
    ├── cache/              # Cached file conversions
    ├── output/             # Hardlinks to workflow outputs
    └── run/                # Workflow directories
        └── <name>/         # Individual workflows (via `wfw new`)
```

After initialization, use `wfw edit` to open `project.txt` and `config` in your editor. You can leave both empty initially.

## Project Description (`project.txt`)

Optional but powerful. Contents are **automatically appended to the system prompt** for every workflow, providing persistent context about your project.

**Good for:**

- Project goals and directory structure
- Naming conventions and coding standards
- Technical constraints or writing guidelines

**Example:**

```
Research Manuscript: Neural Dynamics in Visual Cortex

Directory Structure:
- data/: Raw neural recordings (HDF5)
- analysis/: Processing scripts
- figures/: Generated visualizations
- manuscript/: LaTeX source

Conventions:
- Python: snake_case, PEP 8
- Figures: PDF format for LaTeX
- Writing: Academic tone, Nature Neuroscience style
```

**Skip if:** Quick one-off analyses or simple, self-explanatory tasks.

## Project Configuration

The project `config` file sets defaults for all workflows:

```bash
MODEL=claude-sonnet-4-20250514
TEMPERATURE=1.0
MAX_TOKENS=8192
SYSTEM_PROMPTS=(base)
OUTPUT_FORMAT=md
```

### Configuration Cascade

```
Global Config (~/.config/wireflow/config)
    ↓
Project Config (.workflow/config)
    ↓
Workflow Config (.workflow/run/<name>/config)
    ↓
CLI Flags (--model, --temperature, etc.)
```

Lower levels override upper levels. See [Configuration Guide](configuration.md) for details.

## Nested Projects

Create wireflow projects inside existing wireflow projects for subprojects needing separate workflow namespaces.

```bash
cd my-research        # Parent project with .workflow/
mkdir sub-analysis
cd sub-analysis
wfw init .            # Creates independent nested project
```

When initializing inside an existing project, you'll be prompted to inherit configuration from the parent. Nested projects are **independent**—you cannot use `--depends-on` across project boundaries.

```
my-research/                    # Parent project
├── .workflow/
│   ├── config
│   └── run/
│       └── literature-review/
└── sub-analysis/               # Nested project
    ├── .workflow/              # Independent
    │   └── run/
    │       └── analysis-01/
    └── data/
```

## Project Discovery

WireFlow automatically finds your project root by walking up the directory tree looking for `.workflow/`. Run commands from anywhere in your project:

```bash
cd my-project/data/processed/
wfw list  # Still finds .workflow/ at project root
```

With multiple projects, WireFlow uses the **closest** `.workflow/` directory.

## Editing Project Files

```bash
wfw edit            # Opens project.txt and config
wfw config          # Shows current configuration
wfw list            # Shows all workflows
```

## Best Practices

- One `.workflow/` per logical project
- Document conventions in `project.txt` (keep under 1000 words)
- Don't put sensitive information in `project.txt` (it's sent to the API)
- Use nested projects only when you need separate workflow namespaces

---

Continue to [Workflows](workflows.md) →
