# Prompts & Templates

System prompts and task templates provide reusable instructions for AI workflows.

## System Prompts

System prompts are text files that define the model's behavior, role, and capabilities. They're included at the start of every API request before your task and context.

### Prompt Location

System prompts live in `$WIREFLOW_PROMPT_PREFIX/`:

```
~/.config/wireflow/prompts/
├── base.txt         # Default prompt (always first)
├── research.txt     # Research writing
├── code.txt         # Code analysis
├── stats.txt        # Statistical analysis
└── writing.txt      # Creative writing
```

Default location is `~/.config/wireflow/prompts/`, created automatically on first use.

**Custom location:**
```bash
# In global config
WIREFLOW_PROMPT_PREFIX="$HOME/my-prompts"

# Or as environment variable
export WIREFLOW_PROMPT_PREFIX="$HOME/my-prompts"
```

### The Base Prompt

On first use, WireFlow creates `base.txt`:

```xml
<base-prompt>
You are Claude, an AI assistant helping with research and project development.

Be clear, concise, and thorough in your responses. Follow instructions carefully
and ask for clarification if needed. Format output as requested.
</base-prompt>
```

**Customize for your preferences:**
```bash
wfw edit  # Then edit base.txt
```

### Creating Custom Prompts

**Research Prompt (`research.txt`):**
```xml
<research-prompt>
You are assisting with academic research.

Guidelines:
- Follow scientific method rigorously
- Report statistical tests and p-values
- Note sample sizes and effect sizes
- Identify confounds and limitations

Citation Format: (Author, Year) with DOIs
Writing Style: Formal academic, past tense for methods
</research-prompt>
```

**Code Analysis Prompt (`code.txt`):**
```xml
<code-analysis-prompt>
You are assisting with code analysis.

Review Focus:
- Correctness and edge cases
- Performance and scalability
- Security vulnerabilities
- Code style and documentation

Provide specific improvements with code examples.
</code-analysis-prompt>
```

### Using System Prompts

**Global** (`~/.config/wireflow/config`):
```bash
SYSTEM_PROMPTS=(base)
```

**Project** (`.workflow/config`):
```bash
SYSTEM_PROMPTS=(base research stats)
```

**Workflow** (`.workflow/run/<name>/config`):
```bash
SYSTEM_PROMPTS=(base code)
```

**CLI override:**
```bash
wfw run analysis --system "base,stats,research"
```

### Prompt Order

Prompts concatenate in order specified:

```bash
SYSTEM_PROMPTS=(base research stats)
```

Results in:
```
<base-prompt>...</base-prompt>
<research-prompt>...</research-prompt>
<statistical-analysis-prompt>...</statistical-analysis-prompt>
```

**Best practice:** Always include `base` first.

## Task Templates

Task templates are reusable task prompts for `wfw task` mode.

### Template Location

```
~/.config/wireflow/tasks/
├── summarize.txt    # Summarization template
├── extract.txt      # Data extraction
├── analyze.txt      # Analysis template
└── review.txt       # Code review
```

Set custom location:
```bash
WIREFLOW_TASK_PREFIX="$HOME/my-tasks"
```

### Creating Templates

**summarize.txt:**
```
Summarize the provided content in 3-5 bullet points.
Focus on key findings, conclusions, and action items.
```

**analyze.txt:**
```
Analyze the provided content and identify:
1. Main themes and patterns
2. Key data points or findings
3. Potential issues or concerns
4. Recommendations
```

### Using Templates

```bash
wfw task summarize -cx document.pdf
wfw task analyze -cx data.csv
wfw task review -cx script.py
```

## Project Description

`project.txt` provides project-specific context automatically included in every workflow.

**Location:** `.workflow/project.txt` (created during `wfw init`)

If non-empty, contents are wrapped in `<project>` tags and appended to the system prompt.

**Example:**
```
Research Manuscript: Neural Dynamics in Visual Cortex

Directory Structure:
- data/: Raw spike times (HDF5)
- analysis/: Python scripts
- figures/: Generated plots (PDF)

Conventions:
- Use SI units
- Report statistics in APA format
- Code follows PEP 8
```

## Prompt Composition

When you run a workflow, the system prompt is built:

1. **System prompts** - Each file in `SYSTEM_PROMPTS` array
2. **Project description** - Contents of `project.txt` (if non-empty)

**Example result:**
```xml
<base-prompt>
You are Claude, an AI assistant for research.
</base-prompt>

<research-prompt>
Follow scientific method. Report statistics with p-values.
</research-prompt>

<project>
This is a neuroscience project. All analysis uses Python and NumPy.
</project>
```

## Best Practices

**Writing prompts:**
- Be specific and concrete
- Use clear section headings
- Define expectations explicitly
- Keep under 1000 words per file
- Use XML tags for structure

**Organization:**
```
prompts/
├── base.txt              # General instructions
├── role-researcher.txt   # Research persona
├── role-writer.txt       # Writing persona
├── format-academic.txt   # Academic formatting
└── domain-neuro.txt      # Domain knowledge
```

**Combine as needed:**
```bash
SYSTEM_PROMPTS=(base role-researcher format-academic domain-neuro)
```

## Debugging

### View with Dry Run

```bash
wfw run analysis --dry-run
```

Saves the complete API request including composed system prompt to:

- `.workflow/run/<name>/dry-run-request.json`

---

Continue to [Context & Input](context.md) →
