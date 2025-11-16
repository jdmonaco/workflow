# Usage Examples

Real-world examples demonstrating common workflow patterns and use cases.

## Example 1: Simple Data Analysis

### Scenario

You have CSV files with experimental results and need to analyze them.

### Setup

```bash
# Create and initialize project
mkdir data-analysis-project
cd data-analysis-project
workflow init .
```

### Create Workflow

```bash
workflow new analyze-results
```

In `task.txt`:

```
Analyze the provided CSV data and create a comprehensive report including:

1. Data overview (rows, columns, data types)
2. Statistical summary (mean, std, min, max for numerical columns)
3. Missing value analysis
4. Key patterns and correlations
5. Visualizations recommendations

Format as structured markdown with tables.
```

In `config`:

```bash
CONTEXT_PATTERN="data/*.csv"
TEMPERATURE=0.3  # Lower for analytical tasks
```

### Execute

```bash
workflow run analyze-results --stream
```

### View Output

```bash
cat .workflow/analyze-results/output/response.md
```

## Example 2: Chained Workflows

### Scenario

Multi-stage document creation: gather context → outline → draft → review.

### Create Workflows

```bash
cd manuscript-project
workflow init .

# Stage 1: Context gathering
workflow new 00-gather-context
```

In `00-gather-context/config`:

```bash
CONTEXT_PATTERN="references/*.pdf"
```

In `00-gather-context/task.txt`:

```
Review the provided reference materials and create a structured summary of:
- Main topics and themes
- Key findings and contributions
- Gaps in current knowledge
- Potential research directions
```

```bash
# Stage 2: Create outline
workflow new 01-outline
```

In `01-outline/config`:

```bash
DEPENDS_ON=(00-gather-context)
```

In `01-outline/task.txt`:

```
Based on the context summary, create a detailed outline for a research manuscript
including: Introduction, Methods, Results, Discussion sections with bullet points.
```

```bash
# Stage 3: Draft introduction
workflow new 02-draft-intro
```

In `02-draft-intro/config`:

```bash
DEPENDS_ON=(00-gather-context 01-outline)
SYSTEM_PROMPTS=(base research)
MAX_TOKENS=8192
```

In `02-draft-intro/task.txt`:

```
Write a comprehensive Introduction section following the provided outline.
Include appropriate background, rationale, and clear research objectives.
```

### Execute Pipeline

```bash
workflow run 00-gather-context --stream
workflow run 01-outline --stream
workflow run 02-draft-intro --stream
```

Each step builds on previous outputs automatically via `DEPENDS_ON`.

## Example 3: Task Mode for Quick Queries

### Scenario

Quick ad-hoc analyses without creating persistent workflows.

### Named Tasks

Create reusable task templates:

```bash
mkdir -p ~/.config/workflow/tasks

# Summary task
cat > ~/.config/workflow/tasks/summarize.txt << 'EOF'
Create a concise summary with:
1. Main points (3-5 bullets)
2. Key takeaways
3. Action items if any
EOF

# Extract task
cat > ~/.config/workflow/tasks/extract-data.txt << 'EOF'
Extract structured data from the provided content and format as JSON.
Include all relevant fields and maintain data types appropriately.
EOF
```

### Use Named Tasks

```bash
# Summarize meeting notes
workflow task summarize --context-file meeting-notes.md

# Extract data from report
workflow task extract-data --context-file report.txt --output-file data.json
```

### Inline Tasks

```bash
# Quick question about code
workflow task -i "What does this function do?" --context-file script.py

# Compare files
workflow task -i "Compare these approaches and recommend the best one" \
  --context-file approach-a.md \
  --context-file approach-b.md

# Analyze pattern
workflow task -i "What are the common themes across these files?" \
  --context-pattern "reports/202401/*.md"
```

## Example 4: Code Documentation

### Scenario

Generate documentation for a Python module.

### Setup

```bash
mkdir code-docs
cd code-docs
workflow init .
```

### Workflow 1: Analyze Code

```bash
workflow new 01-analyze
```

In `task.txt`:

```
Analyze the provided Python code and describe:
1. Module purpose and functionality
2. Each function's signature and purpose
3. Dependencies and requirements
4. Example use cases
```

In `config`:

```bash
CONTEXT_PATTERN="src/*.py"
MODEL=claude-3-5-sonnet-20241022
TEMPERATURE=0.3
```

### Workflow 2: Generate README

```bash
workflow new 02-generate-readme
```

In `task.txt`:

```
Based on the code and analysis, create a comprehensive README.md including:
- Project description
- Installation instructions
- API documentation with examples
- Usage guide
- License information

Use professional markdown formatting with code blocks.
```

In `config`:

```bash
CONTEXT_PATTERN="src/*.py"
DEPENDS_ON=(01-analyze)
```

### Execute

```bash
workflow run 01-analyze --stream
workflow run 02-generate-readme --stream

# Copy generated README
cp .workflow/02-generate-readme/output/response.md README.md
```

## Example 5: Nested Projects

### Scenario

Large research project with independent subprojects that should share configuration.

### Parent Project

```bash
cd ~/research/neuroai-study
workflow init .
```

Edit parent `.workflow/config`:

```bash
MODEL=claude-3-opus-4-20250514
TEMPERATURE=0.8
MAX_TOKENS=8192
SYSTEM_PROMPTS=(base research neuroscience)
```

### Create Nested Subproject

```bash
cd experiments/mouse-behavior
workflow init .
```

You'll be prompted:

```
Found parent workflow project at: /Users/name/research/neuroai-study/.workflow

Inherit configuration from parent?
- MODEL: claude-3-opus-4-20250514
- TEMPERATURE: 0.8
- MAX_TOKENS: 8192
- SYSTEM_PROMPTS: base, research, neuroscience

Inherit? [y/N] y

Inheriting configuration from parent...
```

Now the nested project has:

- **Independent workflow namespace** (separate `.workflow/`)
- **Inherited configuration defaults** (same MODEL, TEMPERATURE, etc.)
- **Option to override** at project or workflow level

### Use Nested Project

```bash
cd experiments/mouse-behavior

# Create workflows specific to this experiment
workflow new 01-preprocess-data
workflow new 02-behavioral-analysis
workflow new 03-generate-figures

# Runs use inherited config
workflow run 01-preprocess-data --stream
```

## Example 6: Configuration Overrides

### Scenario

Experiment with different models and parameters without changing configs.

### Testing Models

```bash
# Test with Haiku (fast, economical)
workflow run analysis --model claude-3-5-haiku-20241022 --dry-run

# Test with Sonnet (balanced)
workflow run analysis --model claude-3-5-sonnet-20241022 --dry-run

# Test with Opus (most capable)
workflow run analysis --model claude-3-opus-4-20250514 --dry-run

# Choose best and run
workflow run analysis --model claude-3-5-sonnet-20241022 --stream
```

### Testing Parameters

```bash
# Creative output (high temperature)
workflow run brainstorm --temperature 1.0 --stream

# Focused output (low temperature)
workflow run analysis --temperature 0.3 --stream

# Long-form content (high tokens)
workflow run writeup --max-tokens 16384 --stream
```

### Adding Context Dynamically

```bash
# Add new context without changing config
workflow run analysis \
  --context-file new-data.csv \
  --context-file updated-notes.md \
  --stream

# Override context pattern
workflow run analysis \
  --context-pattern "data/2024-01/*.csv" \
  --stream
```

## Example 7: Multiple Output Formats

### Scenario

Generate outputs in different formats for different purposes.

### Setup Workflows

```bash
# Data extraction (JSON)
workflow new extract-metrics
```

In `extract-metrics/config`:

```bash
OUTPUT_FORMAT=json
CONTEXT_PATTERN="logs/*.txt"
```

In `extract-metrics/task.txt`:

```
Extract performance metrics from logs and format as JSON with fields:
- timestamp
- operation
- duration_ms
- success
- error_message (if applicable)
```

```bash
# Summary report (Markdown)
workflow new summary-report
```

In `summary-report/config`:

```bash
OUTPUT_FORMAT=md
DEPENDS_ON=(extract-metrics)
```

In `summary-report/task.txt`:

```
Create a summary report of the performance metrics including:
- Overall statistics
- Performance trends
- Error analysis
- Recommendations

Format as professional markdown with tables and charts recommendations.
```

```bash
# HTML presentation
workflow new presentation
```

In `presentation/config`:

```bash
OUTPUT_FORMAT=html
DEPENDS_ON=(summary-report)
```

### Execute

```bash
workflow run extract-metrics --stream      # Creates response.json
workflow run summary-report --stream        # Creates response.md
workflow run presentation --stream          # Creates response.html
```

Cross-format dependencies work seamlessly - JSON feeds into Markdown, Markdown feeds into HTML.

## Example 8: Iterative Refinement

### Scenario

Iteratively improve a document draft.

### Initial Draft

```bash
workflow new draft-v1
```

In `task.txt`:

```
Write a 500-word introduction to machine learning for beginners.
Focus on core concepts without technical jargon.
```

```bash
workflow run draft-v1 --context-file outline.md --stream
```

### Review Output

```bash
cat .workflow/draft-v1/output/response.md
# Read, identify issues
```

### Refine Task

```bash
workflow edit draft-v1
```

Update `task.txt`:

```
Write a 500-word introduction to machine learning for beginners.

Requirements:
- Start with a relatable real-world example
- Define key terms (algorithm, training, model)
- Use analogies to explain complex concepts
- Include 2-3 concrete use cases
- End with an encouraging call to action

Tone: Friendly but informative
```

### Re-run

```bash
workflow run draft-v1 --stream
```

Previous output is automatically backed up to `response.md.backup.TIMESTAMP`.

### Compare Versions

```bash
ls -lt .workflow/draft-v1/output/
diff .workflow/draft-v1/output/response.md \
     .workflow/draft-v1/output/response.md.backup.20241115_143022
```

## Example 9: Research Pipeline

### Complete Research Workflow

```bash
cd ~/research/study-2024
workflow init .

# Configure project
cat > .workflow/project.txt << 'EOF'
Longitudinal study of cognitive training effects.

Data: Pre/post test scores, demographics, training logs
Methods: Mixed-effects models, effect sizes, visualization
Reporting: APA format, journal submission
EOF

cat > .workflow/config << 'EOF'
MODEL=claude-3-opus-4-20250514
SYSTEM_PROMPTS=(base research stats)
TEMPERATURE=0.4
MAX_TOKENS=8192
EOF
```

### Create Analysis Pipeline

```bash
# Data preprocessing
workflow new 01-preprocess
# task: Clean data, handle missing values, compute derived variables

# Exploratory analysis
workflow new 02-exploratory
# config: DEPENDS_ON=(01-preprocess)
# task: Generate descriptive statistics, check assumptions

# Statistical tests
workflow new 03-statistical-tests
# config: DEPENDS_ON=(01-preprocess)
# task: Mixed-effects models, post-hoc tests

# Figures
workflow new 04-generate-figures
# config: DEPENDS_ON=(02-exploratory 03-statistical-tests)
# task: Create publication-quality figures

# Methods section
workflow new 05-write-methods
# config: DEPENDS_ON=(01-preprocess)
# task: Write methods section

# Results section
workflow new 06-write-results
# config: DEPENDS_ON=(02-exploratory 03-statistical-tests 04-generate-figures)
# task: Write results section with statistics
```

### Execute Pipeline

```bash
for wf in 01-preprocess 02-exploratory 03-statistical-tests 04-generate-figures 05-write-methods 06-write-results; do
  workflow run "$wf" --stream
done
```

## Example 10: Code Review Workflow

### Setup

```bash
mkdir code-review
cd code-review
workflow init .

# Use code-specific system prompt
echo "SYSTEM_PROMPTS=(base code)" > .workflow/config
```

### Create Review Workflows

```bash
# Security review
workflow new security-review
```

In `task.txt`:

```
Conduct security review of the provided code focusing on:
- Input validation and sanitization
- Authentication and authorization
- SQL injection vulnerabilities
- XSS vulnerabilities
- Sensitive data exposure
- Error handling

Provide specific line references and remediation suggestions.
```

```bash
# Performance review
workflow new performance-review
```

In `task.txt`:

```
Analyze code performance focusing on:
- Algorithm complexity (Big O notation)
- Database query efficiency
- Memory usage patterns
- Caching opportunities
- Bottlenecks

Suggest specific optimizations with code examples.
```

### Execute

```bash
workflow run security-review --context-pattern "src/**/*.py" --stream
workflow run performance-review --context-pattern "src/**/*.py" --stream
```

## Common Patterns Summary

### Pattern: Context Gathering

```bash
CONTEXT_PATTERN="references/*.md"
# or
CONTEXT_FILES=("doc1.md" "doc2.pdf" "notes.txt")
```

### Pattern: Sequential Dependencies

```bash
DEPENDS_ON=(00-step1 01-step2 02-step3)
```

### Pattern: Configuration Specialization

```bash
# Global: Balanced defaults
# Project: Domain-specific
# Workflow: Task-specific overrides
```

### Pattern: Quick Iteration

```bash
# Edit task
workflow edit workflow-name

# Re-run
workflow run workflow-name --stream

# Compare
diff output/response.md output/response.md.backup.*
```

## Tips for Effective Workflows

### Use Descriptive Names

✅ Good: `01-preprocess-data`, `02-exploratory-analysis`, `03-statistical-tests`
❌ Poor: `workflow1`, `test`, `tmp`

### Chain Related Work

Use `--depends-on` to build on previous outputs instead of manually copying context.

### Start Simple

Begin with basic workflows, then add complexity:

1. Single workflow with basic task
2. Add context files
3. Chain multiple workflows
4. Specialize configurations

### Version Control

Add to `.gitignore`:

```
.workflow/*/output/
.workflow/prompts/system.txt
```

Commit:

```
.workflow/config
.workflow/project.txt
.workflow/*/task.txt
.workflow/*/config
```

### Use Task Mode for Exploration

Before creating full workflows, use task mode to experiment:

```bash
workflow task -i "Try analyzing this" --context-file data.csv
# If useful, create persistent workflow
workflow new analysis
```

## Next Steps

- **[Configuration Guide](configuration.md)** - Master the configuration cascade
- **[Execution Guide](execution.md)** - Learn all execution options
- **[CLI Reference](../reference/cli-reference.md)** - Complete command reference

---

Ready for detailed references? Continue to [CLI Reference](../reference/cli-reference.md) →
