# System Prompts

System prompts provide persistent instructions to Claude that apply across all workflows. Learn how to create and manage reusable prompt templates.

## What Are System Prompts?

System prompts are XML-formatted text files that define Claude's behavior, role, and capabilities. They're included at the start of every API request before your task and context.

### Why Use System Prompts?

✅ **Consistency** - Same behavior across all workflows
✅ **Reusability** - Define once, use everywhere
✅ **Modularity** - Combine multiple prompts
✅ **Specialization** - Domain-specific expertise

## System Prompt Structure

### Location

System prompts live in `$WORKFLOW_PROMPT_PREFIX/`:

```
~/.config/workflow/prompts/
├── base.txt         # Default prompt (always first)
├── research.txt     # Research writing
├── code.txt         # Code analysis
├── stats.txt        # Statistical analysis
└── writing.txt      # Creative writing
```

### Default Prompt Directory

The default location is `~/.config/workflow/prompts/`, created automatically on first use.

### Custom Prompt Directory

Set a custom location:

```bash
# In global config
WORKFLOW_PROMPT_PREFIX="$HOME/my-prompts"

# Or as environment variable
export WORKFLOW_PROMPT_PREFIX="$HOME/my-prompts"
```

## The Base Prompt

### Auto-Created

On first use, Workflow creates `base.txt` with general-purpose instructions:

```xml
<base-prompt>
You are Claude, an AI assistant helping with research and project development.

Be clear, concise, and thorough in your responses. Follow instructions carefully
and ask for clarification if needed. Format output as requested.
</base-prompt>
```

### Customizing Base

Edit the base prompt for your personal preferences:

```bash
nano ~/.config/workflow/prompts/base.txt
```

Example customization:

```xml
<base-prompt>
You are Claude, an AI assistant specializing in scientific research and technical writing.

Guidelines:
- Use precise, technical language
- Cite reasoning and assumptions
- Format mathematical notation in LaTeX
- Follow academic writing conventions
- Be thorough but concise

When analyzing data:
- Report statistical details
- Note limitations and uncertainties
- Suggest appropriate methods

When writing:
- Use active voice when possible
- Define technical terms on first use
- Organize with clear section headings
</base-prompt>
```

## Creating Custom Prompts

### Domain-Specific Prompts

Create specialized prompts for different domains:

**Research prompt** (`research.txt`):

```xml
<research-prompt>
You are assisting with academic research in computational neuroscience.

Research Guidelines:
- Follow scientific method rigorously
- Report statistical tests and p-values
- Note sample sizes and effect sizes
- Identify confounds and limitations
- Suggest appropriate controls

Citation Format:
- Use author-year format: (Smith et al., 2023)
- Include DOIs when referencing papers

Writing Style:
- Formal academic tone
- Past tense for completed work
- Present tense for established facts
</research-prompt>
```

**Code analysis prompt** (`code.txt`):

```xml
<code-analysis-prompt>
You are assisting with code analysis and software development.

Code Review Focus:
- Correctness and edge cases
- Performance and scalability
- Security vulnerabilities
- Code style and conventions
- Documentation quality

Recommendations:
- Suggest specific improvements with code examples
- Explain trade-offs of different approaches
- Reference relevant design patterns
- Note testing requirements
</code-analysis-prompt>
```

**Statistical analysis prompt** (`stats.txt`):

```xml
<statistical-analysis-prompt>
You are assisting with statistical data analysis.

Statistical Practices:
- Verify assumptions before applying tests
- Report exact p-values and confidence intervals
- Note effect sizes (Cohen's d, r², etc.)
- Flag potential multiple comparison issues
- Recommend appropriate corrections

Reporting:
- Use APA format for statistics
- Include degrees of freedom
- Report both parametric and non-parametric tests when appropriate
- Note violations of assumptions
</statistical-analysis-prompt>
```

## Using System Prompts

### Configuration

#### Global Default

Set in `~/.config/workflow/config`:

```bash
SYSTEM_PROMPTS=(base)
```

#### Project Default

Set in `.workflow/config`:

```bash
SYSTEM_PROMPTS=(base research stats)
```

#### Workflow Specific

Set in `.workflow/<name>/config`:

```bash
SYSTEM_PROMPTS=(base code)
```

#### CLI Override

```bash
workflow run analysis --system-prompts "base,stats,research"
```

### Prompt Order

Prompts are concatenated in the order specified:

```bash
SYSTEM_PROMPTS=(base research stats)
```

Results in:

```
<base-prompt>...</base-prompt>
<research-prompt>...</research-prompt>
<statistical-analysis-prompt>...</statistical-analysis-prompt>
```

**Best practice:** Always include `base` first for general instructions.

### Array Syntax

In config files, use bash array syntax:

```bash
# Single prompt
SYSTEM_PROMPTS=(base)

# Multiple prompts
SYSTEM_PROMPTS=(base research stats)
```

In CLI, use comma-separated list:

```bash
--system-prompts "base,research,stats"
```

## Project Description

### What Is `project.txt`?

`project.txt` provides project-specific context automatically included in every workflow.

### Location

`.workflow/project.txt` (created during `workflow init`)

### When It's Included

If `project.txt` is **non-empty**, its contents are wrapped in `<project>` tags and appended to the system prompt.

### Example `project.txt`

```
Research Manuscript: Neural Dynamics in Visual Cortex

This project analyzes spike train recordings from mouse V1 during visual
stimulation. The goal is to characterize response dynamics and publish in
a computational neuroscience journal.

Directory Structure:
- data/ : Raw spike times (HDF5 format)
- analysis/ : Python analysis scripts
- figures/ : Generated plots (PDF)
- manuscript/ : LaTeX source

Conventions:
- Use SI units throughout
- Report statistics in APA format
- All figures require figure panels (A, B, C, ...)
- Code follows PEP 8

Analysis Approach:
- Use non-parametric tests (data is not normally distributed)
- Bootstrap confidence intervals (10,000 iterations)
- Multiple comparison correction via FDR

Writing Style:
- Computational neuroscience audience
- Define terms specific to visual neuroscience
- Emphasize mechanistic interpretation
```

### When to Use `project.txt`

✅ **Use when:**

- Workflows need consistent project context
- Project has domain-specific conventions
- Directory structure needs explanation
- Technical constraints apply across workflows
- Style guidelines must be followed

❌ **Skip when:**

- Simple, self-explanatory projects
- One-off analysis
- No recurring patterns

### Editing `project.txt`

```bash
workflow edit  # Opens project.txt and config
```

Or directly:

```bash
nano .workflow/project.txt
```

## System Prompt Composition

### How It Works

When you run a workflow, the system prompt is built in this order:

1. **System prompts** - Each file in `SYSTEM_PROMPTS` array
2. **Project description** - Contents of `project.txt` (if non-empty)

### Full Example

**Configuration:**

```bash
# In .workflow/config
SYSTEM_PROMPTS=(base research)
```

**Files:**

`base.txt`:
```xml
<base-prompt>
You are Claude, an AI assistant for research.
Be thorough and precise.
</base-prompt>
```

`research.txt`:
```xml
<research-prompt>
Follow scientific method. Report statistics with p-values.
</research-prompt>
```

`project.txt`:
```
This is a neuroscience project. All analysis uses Python and NumPy.
```

**Resulting system prompt:**

```xml
<base-prompt>
You are Claude, an AI assistant for research.
Be thorough and precise.
</base-prompt>

<research-prompt>
Follow scientific method. Report statistics with p-values.
</research-prompt>

<project>
This is a neuroscience project. All analysis uses Python and NumPy.
</project>
```

## Prompt Best Practices

### Writing Effective Prompts

✅ **Do:**

- Be specific and concrete
- Use clear section headings
- Provide examples when helpful
- Define expectations explicitly
- Use XML tags for structure

❌ **Don't:**

- Make prompts too long (under 1000 words per file)
- Include contradictory instructions
- Overspecify trivial details
- Duplicate content across prompts

### Organizing Prompts

**Modular approach:**

```
prompts/
├── base.txt              # General instructions
├── role-researcher.txt   # Research persona
├── role-writer.txt       # Writing persona
├── format-academic.txt   # Academic formatting
├── format-technical.txt  # Technical doc formatting
└── domain-neuroscience.txt  # Domain knowledge
```

Combine as needed:

```bash
# Research writing
SYSTEM_PROMPTS=(base role-researcher format-academic domain-neuroscience)

# Technical documentation
SYSTEM_PROMPTS=(base role-writer format-technical)
```

### Prompt Libraries

Create shareable prompt libraries:

```bash
# Personal prompts
~/.config/workflow/prompts/

# Shared team prompts
~/shared/team-prompts/

# Project-specific
.workflow/prompts/  # Override WORKFLOW_PROMPT_PREFIX for project
```

## Debugging Prompts

### View Composed Prompt

The final system prompt is cached at `.workflow/prompts/system.txt`:

```bash
cat .workflow/prompts/system.txt
```

This shows exactly what was sent to the API in the last run.

### Rebuilding

System prompts are rebuilt on every run, so:

- Changes to prompt files take effect immediately
- Configuration changes apply instantly
- No caching issues

### Fallback Behavior

If rebuild fails (file not found, etc.), the cached version at `.workflow/prompts/system.txt` is used as fallback.

## Advanced Patterns

### Conditional Prompts

Use different prompts for different workflows:

```bash
# .workflow/exploratory/config
SYSTEM_PROMPTS=(base research)

# .workflow/writeup/config
SYSTEM_PROMPTS=(base writing)

# .workflow/code-review/config
SYSTEM_PROMPTS=(base code)
```

### Prompt Inheritance

Projects can build on global prompts:

```bash
# Global: ~/.config/workflow/config
SYSTEM_PROMPTS=(base)

# Project: .workflow/config
SYSTEM_PROMPTS=(base research)  # Adds research

# Workflow: .workflow/stats-analysis/config
SYSTEM_PROMPTS=(base research stats)  # Adds stats
```

### Version-Specific Prompts

Maintain different versions:

```
prompts/
├── base.txt
├── research-v1.txt
└── research-v2.txt
```

Switch between versions:

```bash
SYSTEM_PROMPTS=(base research-v2)
```

## Common Prompt Templates

### Generic Research

```xml
<research-prompt>
You are assisting with academic research. Follow scientific standards:
- Report methods and statistics completely
- Note limitations and assumptions
- Use appropriate citation format
- Maintain objectivity
</research-prompt>
```

### Code Review

```xml
<code-review-prompt>
You are conducting code review. Focus on:
- Correctness and edge cases
- Performance implications
- Security considerations
- Code clarity and maintainability
- Testing requirements

Provide specific, actionable feedback with examples.
</code-review-prompt>
```

### Technical Writing

```xml
<technical-writing-prompt>
You are writing technical documentation. Follow these guidelines:
- Write for the target audience (developers)
- Use clear, active voice
- Provide concrete examples
- Structure with headings and lists
- Include edge cases and gotchas
</technical-writing-prompt>
```

### Data Analysis

```xml
<data-analysis-prompt>
You are analyzing data. Best practices:
- Verify data quality and assumptions
- Use appropriate statistical methods
- Report effect sizes and confidence intervals
- Visualize patterns clearly
- Note limitations and uncertainties
</data-analysis-prompt>
```

## Next Steps

Now that you understand system prompts:

- **[See examples](examples.md)** of complete workflow configurations
- **[Learn about output formats](../reference/output-formats.md)** for different output types
- **[Explore technical details](../technical/system-prompts.md)** of prompt implementation

---

Continue to [Examples](examples.md) →
