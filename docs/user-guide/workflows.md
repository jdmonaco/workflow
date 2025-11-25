# Creating and Managing Workflows

Learn how to create, edit, and manage workflows within your project.

## What is a Workflow?

A workflow is a **named, persistent task configuration** stored in your project's `.workflow/` directory. Each workflow contains:

- **Task description** (`task.txt`) - The prompt/instructions for Claude
- **Configuration** (`config`) - Workflow-specific settings
- **Context directory** (`context/`) - Optional directory for context files
- **Output directory** (`output/`) - Where responses are saved

## Creating Workflows

### Basic Creation

```bash
wfw new analysis-01
```

This creates `.workflow/analysis-01/` with:

```
.workflow/analysis-01/
├── task.txt          # Your task description (empty)
├── config            # Workflow config (empty or defaults)
├── context/          # Optional context files
└── output/           # Response outputs (created on first run)
```

### The Creation Experience

After running `wfw new`, the tool opens your editor (vim by default) with two buffers:

1. **`task.txt`** - Write your task/prompt here
2. **`config`** - Set workflow-specific configuration

### Task.txt XML Skeleton

The `task.txt` file is created with an XML skeleton to help structure your workflow:

```xml
<description>
  Brief 1-2 sentence overview of this workflow's purpose
</description>

<guidance>
  High-level strategic guidance for approaching this task
</guidance>

<instructions>
  Detailed step-by-step instructions or requirements
</instructions>

<output-format>
  Specific formatting requirements or structure for the output
</output-format>
```

**Structure explanation:**
- **`<description>`:** Brief summary of what this workflow does
- **`<guidance>`:** Strategic approach or methodology to use
- **`<instructions>`:** Detailed requirements, steps, or specifications
- **`<output-format>`:** Format requirements for the generated output

Replace the placeholder text with your specific task details. The XML structure helps organize complex workflows and provides clear semantic sections for Claude to follow.

### Example Task Description

Here's an example of a filled-out task for data analysis:

```xml
<description>
  Analyze a dataset and create a comprehensive summary report
</description>

<guidance>
  Focus on statistical rigor and actionable insights. Prioritize identifying patterns that could inform business decisions.
</guidance>

<instructions>
  1. Data overview (rows, columns, data types)
  2. Statistical summary of numerical columns
  3. Identification of missing or anomalous values
  4. Key patterns or correlations
  5. Recommendations for further analysis
</instructions>

<output-format>
  Structured markdown report with sections, tables, and bullet points
</output-format>
```

### Example Workflow Configuration

In `config`, override project defaults if needed:

```bash
# Use a more capable model for complex analysis
MODEL=claude-opus-4-5-20251101

# Lower temperature for more focused output
TEMPERATURE=0.5

# Increase token limit for comprehensive reports
MAX_TOKENS=8192

# Add context pattern
CONTEXT_PATTERN=data/*.csv

# Set output format
OUTPUT_FORMAT=markdown
```

!!! tip "Leave Config Empty for Defaults"
    If you don't specify values, the workflow inherits from project config, which inherits from global config. The cascade makes most configs optional!

## Workflow Naming Conventions

### Recommended Patterns

**Sequential workflows:**
```bash
wfw new 00-context
wfw new 01-analysis
wfw new 02-writeup
wfw new 03-review
```

**Descriptive names:**
```bash
wfw new extract-data
wfw new analyze-results
wfw new generate-figures
wfw new draft-discussion
```

**Categorized workflows:**
```bash
wfw new data-preprocessing
wfw new data-exploratory-analysis
wfw new model-training
wfw new model-evaluation
```

### Naming Rules

- ✅ Use lowercase letters, numbers, hyphens, underscores
- ✅ Make names descriptive and meaningful
- ❌ Avoid spaces (use hyphens or underscores)
- ❌ Avoid special characters

## Editing Workflows

### Edit Workflow Files

```bash
wfw edit analysis-01
```

Opens `task.txt` and `config` in your editor.

### Edit Task Only

```bash
nano .workflow/analysis-01/task.txt
```

### Edit Config Only

```bash
nano .workflow/analysis-01/config
```

### View Workflow Configuration

```bash
wfw config analysis-01
```

Shows the complete configuration cascade:

```
Configuration for workflow: analysis-01

MODEL: claude-opus-4-5-20251101 (project)
TEMPERATURE: 0.5 (workflow)
MAX_TOKENS: 8192 (workflow)
STREAM_MODE: true (default)
SYSTEM_PROMPTS: base (default)
OUTPUT_FORMAT: markdown (workflow)
CONTEXT_FILE_PREFIX: ./ (default)

Workflow-specific settings:
  CONTEXT_PATTERN: data/*.csv
  DEPENDS_ON: (none)
```

The labels show where each value comes from:

- `(default)` - Global default constant
- `(global)` - Global config file
- `(project)` - Project config
- `(workflow)` - This workflow's config

## Listing Workflows

### List All Workflows

```bash
wfw list
```

Output:

```
Available workflows in /path/to/project/.workflow:

  00-context
  01-analysis
  02-writeup
  03-review
  extract-data
  analyze-results
```

### Short Form

```bash
wfw ls
```

Both `list` and `ls` work identically.

## Workflow Configuration

### Available Configuration Options

| Option | Description | Example |
|--------|-------------|---------|
| `MODEL` | Claude model to use | `claude-sonnet-4-5-20250929` |
| `TEMPERATURE` | Response randomness (0-1) | `0.7` |
| `MAX_TOKENS` | Maximum response tokens | `8192` |
| `SYSTEM_PROMPTS` | System prompts (comma-separated) | `base,research` |
| `OUTPUT_FORMAT` | Output file extension | `markdown`, `json`, `txt` |
| `INPUT_FILES` | Primary input documents (comma-separated) | `report.pdf,data.csv` |
| `INPUT_PATTERN` | Glob pattern for input files | `docs/*.md` |
| `CONTEXT_FILES` | Context/reference files (comma-separated) | `intro.md,methods.md` |
| `CONTEXT_PATTERN` | Glob pattern for context files | `data/*.csv` |
| `DEPENDS_ON` | Workflow dependencies (comma-separated) | `00-context,01-analysis` |
| `STREAM_MODE` | Enable streaming | `true` or `false` |

### Configuration Priorities

Lower levels override higher levels:

```
1. Global defaults (hardcoded)
   ↓
2. Global config (~/.config/wireflow/config)
   ↓
3. Project config (.workflow/config)
   ↓
4. Workflow config (.workflow/<name>/config)
   ↓
5. CLI flags (--model, --temperature, etc.)
```

### Setting Workflow Context

**Option 1: In Config File**

```bash
# .workflow/analysis-01/config
CONTEXT_PATTERN=data/*.csv
CONTEXT_FILES=README.md,notes.txt
```

**Option 2: At Runtime**

```bash
wfw run analysis-01 --context-pattern "data/*.csv" --context-file README.md
```

Runtime flags override config file settings.

## Adding Context to Workflows

Workflows can aggregate context from multiple sources.

### Context Directory

Place files in the workflow's `context/` directory:

```bash
cp important-data.csv .workflow/analysis-01/context/
```

Then reference in config:

```bash
CONTEXT_FILES=context/important-data.csv
```

### Glob Patterns

Use patterns to include multiple files:

```bash
# In config
CONTEXT_PATTERN=data/*.csv,results/*.json

# Or at runtime
wfw run analysis-01 --context-pattern "data/*.csv"
```

### Explicit Files

List specific files:

```bash
# In config
CONTEXT_FILES=README.md,data/summary.csv,notes.txt

# Or at runtime
wfw run analysis-01 --context-file README.md --context-file data/summary.csv
```

### Dependencies

Include outputs from other workflows:

```bash
# In config
DEPENDS_ON=00-context,01-preprocessing

# Or at runtime
wfw run analysis-01 --depends-on 00-context
```

See [Execution Guide](execution.md) for details on running workflows with context.

## Organizing Workflows

### Flat Structure (Simple Projects)

```
.workflow/
├── data-cleaning/
├── exploratory-analysis/
├── statistical-tests/
└── generate-report/
```

### Numbered Sequence (Linear Pipelines)

```
.workflow/
├── 00-setup/
├── 01-data-import/
├── 02-preprocessing/
├── 03-analysis/
├── 04-visualization/
└── 05-writeup/
```

### Categorized (Complex Projects)

Use prefixes to group related workflows:

```
.workflow/
├── data-01-import/
├── data-02-clean/
├── data-03-transform/
├── model-01-baseline/
├── model-02-tuning/
├── report-01-methods/
└── report-02-results/
```

## Workflow Dependencies

Create workflow chains using `--depends-on`:

```bash
wfw run 02-analysis --depends-on 01-context
```

This automatically includes the output from `01-context` as context for `02-analysis`.

### Multiple Dependencies

```bash
wfw run 03-synthesis --depends-on 01-context,02-analysis
```

### Dependency Graph Example

```
00-data-import
      ↓
01-data-cleaning
      ↓
      ├──→ 02-exploratory-analysis
      │           ↓
      └──→ 02-statistical-tests
                  ↓
              03-final-report ←── 02-exploratory-analysis
```

Create this with:

```bash
wfw run 01-data-cleaning --depends-on 00-data-import
wfw run 02-exploratory-analysis --depends-on 01-data-cleaning
wfw run 02-statistical-tests --depends-on 01-data-cleaning
wfw run 03-final-report \
  --depends-on 02-exploratory-analysis,02-statistical-tests
```

## Working with Workflow Outputs

### Output Location

Outputs are saved to `.workflow/<name>/output.<format>`:

```
.workflow/analysis-01/
├── task.txt            # Task prompt
├── config              # Workflow config
└── output.md           # Latest output (format depends on OUTPUT_FORMAT)
```

A hardlink copy is also created at `.workflow/output/<name>.<format>` for convenience.

### Output Formats

Specify output format to change file extension:

```bash
# In config
OUTPUT_FORMAT=json

# Or at runtime
wfw run analysis-01 --format json
```

Supported formats: `md`, `markdown`, `txt`, `json`, `html`, `xml`, `csv`, `yaml`, etc.

### Reading Outputs

```bash
# Latest output (either path works)
cat .workflow/analysis-01/output.md
cat .workflow/output/analysis-01.md

# Using wfw cat command
wfw cat analysis-01
```

See [Execution Guide](execution.md#output-files) for complete details on output handling.

## Deleting Workflows

To remove a workflow, simply delete its directory:

```bash
rm -r .workflow/old-workflow
```

!!! warning "No Undo"
    Deleting a workflow removes all its files, config, and outputs permanently. Consider backing up important outputs first.

## Renaming Workflows

To rename a workflow, rename its directory:

```bash
mv .workflow/old-name .workflow/new-name
```

!!! note "Update Dependencies"
    If other workflows depend on the renamed workflow, update their `DEPENDS_ON` configuration.

## Copying Workflows

To duplicate a workflow as a starting point:

```bash
cp -r .workflow/template .workflow/new-workflow
```

Then edit the task and config for the new workflow.

## Best Practices

### Workflow Design

- ✅ **Do:**

- Keep tasks focused and specific
- Use descriptive names
- Document complex workflows in `task.txt` comments
- Set workflow-specific config only when needed
- Use dependencies to chain related workflows

❌ **Don't:**

- Create overly broad, multi-purpose workflows
- Hardcode file paths in tasks (use context options instead)
- Duplicate configuration across workflows (use project config)
- Create deeply nested dependency chains (keep it simple)

### Task Descriptions

- ✅ **Good task descriptions:**

- Clear, specific instructions
- Structured output requirements
- Examples of desired format
- Context about the domain/project

```
Analyze the neural recording data and create a summary including:
1. Recording duration and sampling rate
2. Number of neurons and firing rates
3. Identified response patterns
4. Statistical significance of observations

Format as academic report with methods and results sections.
```

❌ **Poor task descriptions:**

- Vague: "Analyze the data"
- No format guidance: "Look at these files"
- Too broad: "Do everything needed for the project"

## Common Patterns

### Iterative Refinement

Create multiple numbered versions for iterative work:

```bash
wfw new draft-v1
wfw new draft-v2
wfw new draft-v3
```

### Template Workflows

Create reusable templates:

```bash
wfw new template-data-analysis
# Set up general config and task structure
# Copy for specific analyses
cp -r .workflow/template-data-analysis .workflow/experiment-1-analysis
```

### Review Workflows

Create review workflows that analyze other outputs:

```bash
wfw new review-analysis
# Set task: "Review the provided analysis for accuracy and completeness"
wfw run review-analysis --depends-on main-analysis
```

## Next Steps

Now that you understand workflows:

- **[Execute workflows](execution.md)** to generate outputs
- **[Configure workflows](configuration.md)** to customize behavior
- **[See examples](examples.md)** of real-world workflow patterns

---

Continue to [Execution Guide](execution.md) →
