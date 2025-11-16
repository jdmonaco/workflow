# Quick Start

Get up and running with Workflow in 5 minutes. This guide assumes you've already [installed](installation.md) Workflow and configured your API key.

## Your First Project (5 Minutes)

Let's create a simple project that uses AI to analyze a text file.

### Step 1: Initialize a Project

Create a new directory and initialize it as a Workflow project:

```bash
mkdir my-analysis
cd my-analysis
workflow init .
```

This creates a `.workflow/` directory with default configuration.

### Step 2: Create Sample Content

Let's create a file to analyze:

```bash
cat > notes.txt << 'EOF'
Meeting Notes - Project Planning

Key Discussion Points:
- Need to refactor the authentication module
- API rate limiting causing issues in production
- Documentation is outdated
- Team wants to adopt TypeScript

Action Items:
- Review authentication code for security issues
- Implement exponential backoff for API calls
- Update README with new configuration options
- Create migration plan for TypeScript

Timeline: Complete by end of Q2
EOF
```

### Step 3: Create Your First Workflow

Create a workflow to extract action items:

```bash
workflow new extract-actions
```

This creates `.workflow/extract-actions/` with:

- `task.txt` - Your prompt/task description
- `config` - Workflow-specific configuration
- `context/` - Directory for context files

### Step 4: Define the Task

Edit the task file (opens in your `$EDITOR`):

```bash
workflow edit extract-actions
```

Or edit it manually:

```bash
cat > .workflow/extract-actions/task.txt << 'EOF'
Extract all action items from the meeting notes and format them as a checklist.
For each item, identify:
1. What needs to be done
2. Any relevant deadlines or priorities
3. Dependencies on other tasks

Format the output as a markdown checklist with clear priorities.
EOF
```

### Step 5: Add Context

Add your notes file as context:

```bash
workflow run extract-actions --context-file notes.txt --stream
```

!!! tip "Streaming Mode"
    The `--stream` flag enables real-time output as the API generates the response. Omit it for batch mode (response saved to file after completion).

### Step 6: View the Output

The response is saved to `.workflow/extract-actions/output/response.md`:

```bash
cat .workflow/extract-actions/output/response.md
```

## What Just Happened?

Let's break down what you did:

1. **`workflow init .`** - Created a `.workflow/` project structure
2. **`workflow new extract-actions`** - Created a new workflow subdirectory
3. **`workflow edit extract-actions`** - Opened the task prompt for editing
4. **`workflow run extract-actions`** - Executed the workflow with the Anthropic API

The workflow:

- Read your task from `task.txt`
- Gathered context from `notes.txt`
- Sent everything to Claude
- Saved the response to `output/response.md`
- Kept a backup of any previous output

## Key Concepts

### Project Structure

```
my-analysis/
├── notes.txt                  # Your content
└── .workflow/                 # Workflow project root
    ├── config                 # Project-level config
    └── workflows/
        └── extract-actions/   # Individual workflow
            ├── task.txt       # Task/prompt
            ├── config         # Workflow config
            ├── context/       # Context files
            └── output/        # Generated outputs
```

### Modes of Operation

**Workflow Mode** (what you just used):

- Creates persistent directory structure
- Stores task, config, and outputs
- Ideal for iterative development

**Task Mode** (quick one-offs):

```bash
workflow task -i "Summarize these notes" --context-file notes.txt
```

- No persistent directories
- Output streams to stdout
- Great for quick queries

## Try These Next

### Run with More Context

Use glob patterns to add multiple files:

```bash
workflow run extract-actions --context-pattern "*.txt" --stream
```

### Modify the Configuration

Change the AI model or parameters:

```bash
# View current config
workflow config extract-actions

# Edit workflow config
nano .workflow/extract-actions/config
```

Add configuration like:

```bash
MODEL=claude-3-5-sonnet-20241022
TEMPERATURE=0.7
MAX_TOKENS=2000
```

### Create a Dependent Workflow

Create a second workflow that uses the first's output:

```bash
# Create new workflow
workflow new prioritize-actions

# Edit task
workflow edit prioritize-actions
# Add task: "Take these action items and create a prioritized implementation plan"

# Run with dependency
workflow run prioritize-actions --depends-on extract-actions --stream
```

The `--depends-on` flag automatically includes the output of `extract-actions` as context!

### Try Task Mode

For quick queries without creating workflows:

```bash
# Inline task
workflow task -i "What are the main themes in these notes?" --context-file notes.txt

# Named task (create reusable task templates)
mkdir -p ~/.config/workflow/tasks
echo "Summarize the key points in bullet format" > ~/.config/workflow/tasks/summarize.txt
workflow task summarize --context-file notes.txt
```

## Common Commands

```bash
# List all workflows in project
workflow list

# View configuration cascade
workflow config extract-actions

# Get help
workflow help
workflow help run
workflow run -h
```

## Next Steps

You now know the basics! Here's what to explore next:

1. **[First Workflow Tutorial](first-workflow.md)** - Detailed walkthrough of a real-world workflow
2. **[Configuration Guide](../user-guide/configuration.md)** - Master the four-tier configuration system
3. **[Execution Guide](../user-guide/execution.md)** - Learn all the options for running workflows and tasks
4. **[Examples](../user-guide/examples.md)** - See real-world usage patterns

## Quick Reference

| Command | What It Does |
|---------|-------------|
| `workflow init <dir>` | Initialize a workflow project |
| `workflow new <name>` | Create a new workflow |
| `workflow list` | List all workflows |
| `workflow edit <name>` | Edit workflow task |
| `workflow run <name>` | Execute a workflow |
| `workflow task -i "<text>"` | Quick one-off task |
| `workflow config <name>` | View configuration |
| `workflow help` | Show help |

---

Ready for a more detailed tutorial? Continue to [First Workflow](first-workflow.md) →
