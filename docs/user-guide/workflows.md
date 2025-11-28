# Creating and Managing Workflows

Create, edit, and manage workflows within your wireflow project.

## What is a Workflow?

A workflow is a **named, persistent task configuration** stored in `.workflow/run/`. Each workflow contains:

- **Task description** (`task.txt`) - The prompt/instructions for the task
- **Configuration** (`config`) - Workflow-specific settings
- **Output directory** (`output/`) - Where responses are saved

## Creating Workflows

```bash
wfw new analysis-01
```

Creates `.workflow/run/analysis-01/` with:

```
.workflow/run/analysis-01/
├── task.txt          # Your task description
├── config            # Workflow config (optional)
└── output/           # Response outputs (created on first run)
```

After creation, use `wfw edit analysis-01` to open the workflow files in your editor.

### Task.txt Structure

The `task.txt` file uses an optional XML skeleton:

```xml
<description>
  Brief overview of this workflow's purpose
</description>

<instructions>
  Detailed step-by-step instructions or requirements
</instructions>

<output-format>
  Specific formatting requirements for the output
</output-format>
```

**Example:**

```xml
<description>
  Analyze a dataset and create a summary report
</description>

<instructions>
  1. Data overview (rows, columns, data types)
  2. Statistical summary of numerical columns
  3. Key patterns or correlations
  4. Recommendations for further analysis
</instructions>

<output-format>
  Structured markdown with sections and tables
</output-format>
```

### Workflow Configuration

Override project defaults in `config`:

```bash
MODEL=claude-opus-4-5-20251101
TEMPERATURE=0.5
MAX_TOKENS=8192
CONTEXT_PATTERN=data/*.csv
OUTPUT_FORMAT=md
```

Leave empty to inherit from project config.

## Naming Conventions

**Sequential:** `00-context`, `01-analysis`, `02-writeup`

**Descriptive:** `extract-data`, `analyze-results`, `generate-figures`

**Rules:** Use lowercase, hyphens, underscores. No spaces or special characters.

## Editing Workflows

```bash
wfw edit analysis-01          # Opens task.txt and config
wfw config analysis-01        # Shows configuration cascade
```

Configuration sources (lower overrides higher):

- `(default)` - Global defaults
- `(global)` - `~/.config/wireflow/config`
- `(project)` - `.workflow/config`
- `(workflow)` - `.workflow/run/<name>/config`

## Listing Workflows

```bash
wfw list      # or: wfw ls
```

## Configuration Options

| Option | Description | Example |
|--------|-------------|---------|
| `MODEL` | Model identifier | `claude-sonnet-4-20250514` |
| `TEMPERATURE` | Randomness (0-1) | `0.7` |
| `MAX_TOKENS` | Max response tokens | `8192` |
| `SYSTEM_PROMPTS` | System prompts (array) | `(base research)` |
| `OUTPUT_FORMAT` | Output extension | `md`, `json` |
| `INPUT_FILES` | Primary inputs (array) | `(report.pdf data.csv)` |
| `INPUT_PATTERN` | Input glob pattern | `docs/*.md` |
| `CONTEXT_FILES` | Context files (array) | `(intro.md methods.md)` |
| `CONTEXT_PATTERN` | Context glob pattern | `data/*.csv` |
| `DEPENDS_ON` | Dependencies (array) | `(00-context 01-analysis)` |

## Adding Context

**In config:**
```bash
CONTEXT_PATTERN=data/*.csv
CONTEXT_FILES=(README.md notes.txt)
```

**At runtime:**
```bash
wfw run analysis-01 -cx "data/*.csv" -cx README.md
```

Runtime flags override config settings.

## Workflow Dependencies

Chain workflows with `--depends-on`:

```bash
wfw run 02-analysis --depends-on 01-context
```

This includes output from `01-context` as context for `02-analysis`.

**Multiple dependencies:**
```bash
wfw run 03-synthesis --depends-on 01-context 02-analysis
```

**Dependency graph example:**
```
00-data-import → 01-cleaning → 02-analysis → 03-report
                           └→ 02-tests ────┘
```

## Output Files

Outputs saved to `.workflow/run/<name>/output.<format>`:

```
.workflow/run/analysis-01/
├── task.txt
├── config
└── output.md      # Latest output
```

Hardlink also created at `.workflow/output/analysis-01.md` for convenience.

**View output:**
```bash
wfw cat analysis-01
cat .workflow/run/analysis-01/output.md
cat .workflow/output/analysis-01.md
```

## Managing Workflows

**Delete:**
```bash
rm -r .workflow/run/old-workflow
```

**Rename:**
```bash
mv .workflow/run/old-name .workflow/run/new-name
# Update DEPENDS_ON in dependent workflows
```

**Copy:**
```bash
cp -r .workflow/run/template .workflow/run/new-workflow
```

## Best Practices

**Do:**
- Keep tasks focused and specific
- Use descriptive workflow names
- Set workflow-specific config only when needed
- Use dependencies to chain related workflows

**Don't:**
- Create overly broad, multi-purpose workflows
- Hardcode file paths (use context options)
- Duplicate config across workflows (use project config)

**Good task descriptions:**
- Clear, specific instructions
- Structured output requirements
- Context about the domain

---

Continue to [Execution Guide](execution.md) →
