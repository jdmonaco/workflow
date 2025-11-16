# Your First Workflow

This detailed tutorial walks you through creating a real-world workflow from start to finish. You'll build a documentation generation workflow that analyzes code and creates README content.

## Scenario

You have a Python module with several functions but no documentation. You want to:

1. Analyze the code structure and purpose
2. Generate comprehensive documentation
3. Create usage examples

We'll build this as a chain of workflows, each building on the previous output.

## Setup (5 minutes)

### 1. Create Project Directory

```bash
mkdir ~/code-docs-demo
cd ~/code-docs-demo
```

### 2. Create Sample Python Module

Let's create a sample module to document:

```bash
cat > string_utils.py << 'EOF'
def titlecase(text):
    """Convert text to title case."""
    return ' '.join(word.capitalize() for word in text.split())

def slugify(text):
    """Convert text to URL-safe slug."""
    import re
    text = text.lower().strip()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[-\s]+', '-', text)
    return text

def truncate(text, length, suffix='...'):
    """Truncate text to specified length with suffix."""
    if len(text) <= length:
        return text
    return text[:length - len(suffix)] + suffix

def word_count(text):
    """Count words in text."""
    return len(text.split())
EOF
```

### 3. Initialize Workflow Project

```bash
workflow init .
```

This creates `.workflow/` with default configuration.

## Workflow 1: Analyze Code Structure (10 minutes)

### Create the Workflow

```bash
workflow new 01-analyze-code
```

### Define the Task

Edit the task file:

```bash
workflow edit 01-analyze-code
```

Add this task description:

```
Analyze the provided Python module and create a detailed analysis including:

1. **Module Purpose**: What is the overall purpose of this module?
2. **Function Inventory**: List each function with a brief description
3. **API Patterns**: What patterns or conventions does it follow?
4. **Use Cases**: What are the likely use cases for this module?
5. **Dependencies**: What external dependencies does it use?

Format the output as structured markdown with clear sections.
```

### Configure for Code Analysis

Edit the workflow config to optimize for code analysis:

```bash
nano .workflow/01-analyze-code/config
```

Add these settings:

```bash
MODEL=claude-3-5-sonnet-20241022
TEMPERATURE=0.3
MAX_TOKENS=4000
```

!!! note "Why These Settings?"
    - Lower temperature (0.3) for more focused, analytical output
    - Higher token limit (4000) for comprehensive analysis
    - Sonnet model for good balance of quality and cost

### Run the Analysis

```bash
workflow run 01-analyze-code --context-file string_utils.py --stream
```

Watch as Claude analyzes the code in real-time!

### Review the Output

```bash
cat .workflow/01-analyze-code/output/response.md
```

You should see a structured analysis of your module.

## Workflow 2: Generate Documentation (10 minutes)

Now let's use the analysis to generate actual documentation.

### Create the Workflow

```bash
workflow new 02-generate-docs
```

### Define the Task

```bash
workflow edit 02-generate-docs
```

Add this task:

```
Based on the code and analysis provided, create comprehensive README documentation including:

1. **Title and Description**: Clear, concise module description
2. **Installation**: How to use this module (assume standalone Python file)
3. **API Reference**: Detailed documentation for each function including:
   - Function signature
   - Parameters with types
   - Return value
   - Examples
4. **Usage Examples**: Real-world code examples showing common use cases
5. **License**: Suggest MIT license

Format as a complete, professional README.md suitable for GitHub.
Use proper markdown formatting with code blocks and clear headings.
```

### Run with Dependencies

This is where it gets powerful. Use `--depends-on` to automatically include the previous workflow's output:

```bash
workflow run 02-generate-docs \
  --context-file string_utils.py \
  --depends-on 01-analyze-code \
  --stream
```

!!! tip "Automatic Context Chaining"
    The `--depends-on` flag automatically includes the output from `01-analyze-code` as context. No need to manually copy files!

### Review the Generated Documentation

```bash
cat .workflow/02-generate-docs/output/response.md
```

You now have a complete README draft!

## Workflow 3: Generate Usage Examples (10 minutes)

Let's create a separate workflow for generating example code.

### Create the Workflow

```bash
workflow new 03-usage-examples
```

### Define the Task

```bash
workflow edit 03-usage-examples
```

Add this task:

```
Create a comprehensive set of usage examples demonstrating all functions in this module.

Requirements:
1. Real-world scenarios (not just toy examples)
2. Show input and expected output
3. Demonstrate edge cases
4. Include comments explaining what each example does
5. Format as executable Python code

Organize examples from simple to complex.
Output should be ready to copy into a Python file or Jupyter notebook.
```

### Run with Multiple Dependencies

Include both the original analysis and the documentation:

```bash
workflow run 03-usage-examples \
  --context-file string_utils.py \
  --depends-on 01-analyze-code \
  --depends-on 02-generate-docs \
  --stream
```

### Save the Examples

```bash
cat .workflow/03-usage-examples/output/response.md > examples.py
```

## Understanding What You Built

### Project Structure

Let's look at what you created:

```bash
tree -a -I '.git'
```

```
code-docs-demo/
├── string_utils.py                   # Original code
├── examples.py                        # Generated examples
└── .workflow/
    ├── config                         # Project config
    └── workflows/
        ├── 01-analyze-code/
        │   ├── task.txt               # Analysis task
        │   ├── config                 # Workflow config
        │   └── output/
        │       └── response.md        # Analysis output
        ├── 02-generate-docs/
        │   ├── task.txt               # Documentation task
        │   ├── config                 # Workflow config
        │   └── output/
        │       └── response.md        # README content
        └── 03-usage-examples/
            ├── task.txt               # Examples task
            ├── config                 # Workflow config
            └── output/
                └── response.md        # Example code
```

### The Workflow Chain

You created a **Directed Acyclic Graph (DAG)** of workflows:

```
01-analyze-code
       ↓
       ├─────→ 02-generate-docs
       ↓              ↓
       └──────────────┴─────→ 03-usage-examples
```

Each workflow builds on previous outputs using `--depends-on`.

### Token Estimation

Before running, check estimated costs:

```bash
workflow run 03-usage-examples \
  --context-file string_utils.py \
  --depends-on 01-analyze-code \
  --depends-on 02-generate-docs \
  --estimate-tokens
```

This shows estimated input tokens and cost without making an API call.

## Iterating on Outputs

### Re-running with Changes

If you want to refine the documentation, just edit the task and re-run:

```bash
# Edit the task
workflow edit 02-generate-docs

# Re-run (automatically backs up previous output)
workflow run 02-generate-docs \
  --context-file string_utils.py \
  --depends-on 01-analyze-code \
  --stream
```

The previous output is automatically saved as `response.md.backup.TIMESTAMP`.

### View Output History

```bash
ls -lt .workflow/02-generate-docs/output/
```

### Compare Outputs

```bash
diff .workflow/02-generate-docs/output/response.md \
     .workflow/02-generate-docs/output/response.md.backup.20241115_143022
```

## Advanced Techniques

### Using Custom System Prompts

Create a specialized prompt for code documentation:

```bash
cat > .workflow/prompts/code-documenter.txt << 'EOF'
You are a technical documentation specialist. When analyzing code and creating
documentation, prioritize:
- Clarity and precision
- Practical examples
- Following language-specific conventions
- Including edge cases and common pitfalls

Format all output in clean, professional markdown.
EOF
```

Update project config to use this prompt:

```bash
echo "SYSTEM_PROMPTS=base,code-documenter" >> .workflow/config
```

### Using Glob Patterns

If you had multiple Python files:

```bash
workflow run 01-analyze-code --context-pattern "*.py" --stream
```

### Different Output Formats

Request JSON output:

```bash
workflow run 01-analyze-code \
  --context-file string_utils.py \
  --format-hint json \
  --stream
```

The response will be saved as `response.json` instead of `response.md`.

## What You Learned

You now know how to:

✅ Initialize workflow projects
✅ Create multiple related workflows
✅ Chain workflows with `--depends-on`
✅ Add context from files
✅ Configure model parameters
✅ Use streaming for real-time feedback
✅ Iterate on outputs with automatic backups
✅ Estimate costs before running
✅ Use format hints for structured output

## Try It Yourself

Now practice by:

1. **Adding More Context**: Include a test file or usage documentation
2. **Creating New Workflows**: Try generating API documentation or migration guides
3. **Experimenting with Models**: Try different Claude models
4. **Using Task Mode**: Quick doc queries without full workflows

## Next Steps

Now that you understand workflows, explore:

- **[Configuration Guide](../user-guide/configuration.md):** Master the four-tier configuration cascade
- **[Execution Guide](../user-guide/execution.md):** Learn all execution options and modes
- **[Examples](../user-guide/examples.md):** More real-world patterns
- **[CLI Reference](../reference/cli-reference.md):** Complete command reference

---

Ready to dive deeper? Continue to the [User Guide](../user-guide/initialization.md) →
