# Project Initialization

Learn how to initialize workflow projects and understand the project structure that gets created.

## Basic Initialization

### Initialize in Current Directory

```bash
cd my-project
workflow init .
```

### Initialize in New Directory

```bash
workflow init ~/research/my-analysis
cd ~/research/my-analysis
```

### What Gets Created

When you run `workflow init`, it creates:

```
your-project/
└── .workflow/
    ├── config           # Project-level configuration
    ├── project.txt      # Optional project description
    ├── prompts/         # Project-specific system prompts (optional)
    └── workflows/       # Directory for individual workflows
```

## Initial Setup Flow

After running `workflow init`, the tool:

1. **Creates `.workflow/` structure** with necessary directories
2. **Opens editor** (vim by default) with two files:
   - `project.txt` - Describe your project (optional)
   - `config` - Set project-level configuration

### The Editor Experience

```
# First buffer: project.txt
[Describe your project here]

# Second buffer: config
# Default values are shown as comments
MODEL=claude-3-5-sonnet-20241022
TEMPERATURE=1.0
MAX_TOKENS=8192
SYSTEM_PROMPTS=base
```

!!! tip "Skip if You're in a Hurry"
    You can leave both files empty and edit them later with `workflow edit`. The tool works with all defaults!

## Project Description (`project.txt`)

The `project.txt` file is optional but powerful. Use it to describe:

- **Project goals and objectives**
- **Directory structure and organization**
- **Naming conventions and standards**
- **Technical constraints or requirements**
- **Coding style or writing guidelines**

### Why Use `project.txt`?

If the file is non-empty, its contents are **automatically appended to the system prompt** for every workflow in the project. This gives Claude persistent context about your project.

### Example `project.txt`

```
Research Manuscript: "Neural Dynamics in Visual Cortex"

This project analyzes neural recordings and generates manuscript sections.

Directory Structure:
- data/ : Raw neural recordings (HDF5 format)
- analysis/ : Processing scripts and results
- figures/ : Generated visualizations
- manuscript/ : LaTeX source files

Conventions:
- Use snake_case for Python variables
- Follow PEP 8 style guidelines
- All figures in PDF format for LaTeX
- Reference data files relative to project root

Writing Style:
- Academic, formal tone
- Follow Nature Neuroscience formatting
- Include statistical details in methods
- Reference figures as "Figure 1A" format
```

### When to Use `project.txt`

✅ **Good use cases:**

- Research projects with specific domain knowledge
- Code projects with architectural patterns
- Documentation projects with style guidelines
- Any project where consistent context improves results

❌ **Skip if:**

- Quick one-off analyses
- Simple, self-explanatory tasks
- Projects without recurring patterns

## Project-Level Configuration

The project `config` file sets defaults for all workflows in the project.

### Common Configuration Options

```bash
# Model selection
MODEL=claude-3-5-sonnet-20241022

# Response parameters
TEMPERATURE=1.0
MAX_TOKENS=8192

# System prompts (comma-separated)
SYSTEM_PROMPTS=base,research

# Default output format
OUTPUT_FORMAT=markdown

# Context file prefix (relative paths resolved from here)
CONTEXT_FILE_PREFIX=./
```

### Configuration Cascade

Project configuration provides defaults that individual workflows can override:

```
Global Config (~/.config/workflow/config)
    ↓
Project Config (.workflow/config)
    ↓
Workflow Config (.workflow/<name>/config)
    ↓
CLI Flags (--model, --temperature, etc.)
```

Lower levels override upper levels. See [Configuration Guide](configuration.md) for details.

## Nested Projects

You can create workflow projects inside existing workflow projects!

### Why Nested Projects?

Use nested projects when you have:

- **Subprojects** within larger projects
- **Different contexts** needing separate workflow namespaces
- **Modular components** that should be independent

### Creating Nested Projects

```bash
cd my-research  # Parent project with .workflow/
mkdir sub-analysis
cd sub-analysis
workflow init .
```

### Configuration Inheritance

When initializing inside an existing project, you'll be prompted:

```
Found parent workflow project at: /path/to/my-research/.workflow

Inherit configuration from parent?
- MODEL: claude-3-5-sonnet-20241022
- TEMPERATURE: 0.8
- MAX_TOKENS: 4096
- SYSTEM_PROMPTS: base,research
- OUTPUT_FORMAT: markdown

Inherit? (y/n)
```

If you answer **yes**:

- Configuration values are copied to the new project's config
- You can still override them later
- The nested project is **independent** but starts with consistent settings

If you answer **no**:

- The new project gets default configuration
- No connection to parent project

### Nested Project Structure

```
my-research/                    # Parent project
├── .workflow/
│   ├── config
│   ├── project.txt
│   └── workflows/
│       ├── 01-literature-review/
│       └── 02-data-analysis/
│
└── sub-analysis/               # Nested project
    ├── .workflow/              # Independent workflow project
    │   ├── config              # Can inherit from parent
    │   ├── project.txt         # Separate context
    │   └── workflows/
    │       └── analysis-01/
    └── data/
```

!!! warning "Independent Workflow Namespaces"
    Workflows in nested projects are **separate**. You cannot use `--depends-on` across project boundaries. Each project has its own workflow namespace.

## Project Discovery

The tool automatically finds your project root by walking up the directory tree looking for `.workflow/`.

### From Anywhere in Your Project

```bash
cd my-project/data/processed/
workflow list  # Still finds .workflow/ at project root
```

### Multiple Projects

If you have multiple projects, the tool finds the **closest** `.workflow/` directory:

```
home/
├── project-a/
│   └── .workflow/        # Used when in project-a/
└── project-b/
    └── .workflow/        # Used when in project-b/
    └── sub/
        └── .workflow/    # Used when in project-b/sub/
```

## Editing Project Files

### Edit Project Configuration

```bash
workflow edit
```

Opens `project.txt` and `config` in your editor.

### View Project Structure

```bash
workflow list
```

Shows all workflows in the current project.

### View Project Configuration

```bash
workflow config
```

Shows current project configuration values.

## Best Practices

### Project Organization

✅ **Do:**

- One `.workflow/` per logical project
- Use descriptive project names
- Document conventions in `project.txt`
- Set project defaults in `config`
- Use nested projects for clear boundaries

❌ **Don't:**

- Initialize multiple `.workflow/` directories in the same hierarchy (unless nesting intentionally)
- Put sensitive information in `project.txt` (it's sent to the API)
- Make `project.txt` too long (keep under 1000 words)

### When to Re-Initialize

You typically initialize once per project. Re-initialize if:

- You want to start fresh (move or delete old `.workflow/` first)
- You're migrating from an old workflow version
- You want to restructure your workflow organization

### Migration from Existing Projects

If you have an existing project and want to add workflows:

```bash
cd existing-project
workflow init .
# .workflow/ is created alongside your existing files
```

The tool doesn't modify existing files - it only creates `.workflow/`.

## Common Tasks

### Change Project Description

```bash
nano .workflow/project.txt
```

### Change Project Configuration

```bash
nano .workflow/config
# Or use: workflow edit
```

### See All Workflows

```bash
workflow list
```

### Move Project

Just move the entire directory - `.workflow/` moves with it:

```bash
mv ~/old-location/my-project ~/new-location/
cd ~/new-location/my-project
workflow list  # Still works!
```

### Share Project (Without Outputs)

```bash
# Copy project without outputs
rsync -av --exclude='.workflow/*/output/' my-project/ shared-project/
```

Or add `.workflow/*/output/` to `.gitignore`.

## Troubleshooting

### "No workflow project found"

You're not in a workflow project. Run:

```bash
workflow init .
```

### "Permission denied"

Ensure you have write permissions:

```bash
chmod u+w .workflow/config
```

### Editor Not Opening

Set your preferred editor:

```bash
export EDITOR=nano
workflow init .
```

## Next Steps

Now that you have a project initialized:

- **[Create workflows](workflows.md)** to organize your tasks
- **[Configure the project](configuration.md)** to customize behavior
- **[Run workflows](execution.md)** to start generating outputs

---

Continue to [Creating Workflows](workflows.md) →
