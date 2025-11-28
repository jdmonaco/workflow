# Output Formats

Reference for supported output formats and format handling in WireFlow.

## Overview

Workflows support any text-based output format. The format determines:

- Output file extension
- Optional format hints to Claude
- Post-processing (if tools available)

## Supported Formats

### Common Formats

| Format | Extension | Description | Post-Processing |
|--------|-----------|-------------|-----------------|
| Markdown | `.md` | Default, structured documents | `mdformat` (if available) |
| Plain Text | `.txt` | Unformatted text | None |
| JSON | `.json` | Structured data | Pretty-print with `jq` |
| HTML | `.html` | Web pages, formatted output | None |
| XML | `.xml` | Structured markup | None |
| CSV | `.csv` | Tabular data | None |
| YAML | `.yaml`, `.yml` | Configuration, data | None |
| LaTeX | `.tex` | Academic documents | None |
| Code | `.py`, `.js`, `.sh`, etc. | Source code | None |

### Custom Formats

Any text-based format works - just specify the extension:

```bash
OUTPUT_FORMAT=rst      # RestructuredText
OUTPUT_FORMAT=sql      # SQL scripts
OUTPUT_FORMAT=dot      # Graphviz
OUTPUT_FORMAT=mermaid  # Mermaid diagrams
```

## Specifying Output Format

### In Workflow Config

```bash
# .workflow/extract-data/config
OUTPUT_FORMAT=json
```

### In Project Config

```bash
# .workflow/config
OUTPUT_FORMAT=md  # Default for all workflows
```

### Via CLI Flag

```bash
wfw run extract-data --format json
```

CLI flags override config files.

## Format Hints

For non-markdown formats, WireFlow automatically appends a format hint to the task:

```xml
<output-format>json</output-format>
```

This guides Claude to generate output in the requested format.

### Example

**Task:**

```
Extract user data from the logs.
```

**With `OUTPUT_FORMAT=json`, becomes:**

```
Extract user data from the logs.

<output-format>json</output-format>
```

Claude understands to format the response as JSON.

## Post-Processing

### Markdown (`.md`)

If `mdformat` is installed:

```bash
pip install mdformat
```

Output is automatically formatted for consistency.

### JSON (`.json`)

If `jq` is installed:

```bash
# macOS
brew install jq

# Linux
sudo apt install jq
```

Output is automatically pretty-printed:

```json
{
  "users": [
    {
      "id": 1,
      "name": "Alice"
    }
  ]
}
```

### Other Formats

No automatic post-processing. Output is saved as-is from Claude.

## Output File Naming

Format: `<name>.<format>`

### Examples

| Format | Filename |
|--------|----------|
| `md` | `<name>.md` |
| `json` | `<name>.json` |
| `txt` | `<name>.txt` |
| `html` | `<name>.html` |
| `py` | `response.py` |

### Location

```
.workflow/<name>/output.<format>
```

Also hardlinked to:

```
.workflow/output/<name>.<format>
```

## Cross-Format Dependencies

Workflows can depend on workflows with different formats:

```bash
# Workflow 1: Extract data as JSON
wfw new extract-metrics
# Config: OUTPUT_FORMAT=json
wfw run extract-metrics --stream

# Workflow 2: Analyze JSON data, output markdown report
wfw new analyze-metrics
# Config: OUTPUT_FORMAT=md, DEPENDS_ON=(extract-metrics)
wfw run analyze-metrics --stream

# Workflow 3: Generate HTML presentation from markdown
wfw new presentation
# Config: OUTPUT_FORMAT=html, DEPENDS_ON=(analyze-metrics)
wfw run presentation --stream
```

The dependency mechanism works regardless of format - the content is included as context.

## Format Examples

### JSON Data Extraction

**Config:**

```bash
OUTPUT_FORMAT=json
CONTEXT_PATTERN="logs/*.txt"
```

**Task:**

```
Extract performance metrics from logs as JSON array with fields:
- timestamp (ISO 8601)
- operation (string)
- duration_ms (number)
- success (boolean)
```

**Output** (`<name>.json`):

```json
[
  {
    "timestamp": "2024-01-15T10:30:00Z",
    "operation": "query",
    "duration_ms": 245,
    "success": true
  }
]
```

### CSV Tabular Data

**Config:**

```bash
OUTPUT_FORMAT=csv
```

**Task:**

```
Create CSV of experiment results with columns: trial_id, condition, response_time, accuracy
```

**Output** (`response.csv`):

```csv
trial_id,condition,response_time,accuracy
1,control,523,0.94
2,experimental,489,0.97
3,control,556,0.91
```

### HTML Report

**Config:**

```bash
OUTPUT_FORMAT=html
DEPENDS_ON=(data-analysis)
```

**Task:**

```
Create an HTML report with embedded CSS, tables for statistics, and visualization recommendations.
```

**Output** (`<name>.html`):

```html
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial; margin: 40px; }
    table { border-collapse: collapse; }
    td, th { border: 1px solid #ddd; padding: 8px; }
  </style>
</head>
<body>
  <h1>Analysis Report</h1>
  <table>
    <tr><th>Metric</th><th>Value</th></tr>
    <tr><td>Mean</td><td>45.2</td></tr>
  </table>
</body>
</html>
```

### LaTeX Academic Writing

**Config:**

```bash
OUTPUT_FORMAT=tex
```

**Task:**

```
Write the Methods section for a neuroscience paper in LaTeX, including equations for statistical tests.
```

**Output** (`response.tex`):

```latex
\section{Methods}

\subsection{Statistical Analysis}

We performed a repeated-measures ANOVA with the test statistic:

\begin{equation}
F = \frac{MS_{between}}{MS_{within}}
\end{equation}

Post-hoc comparisons used Tukey's HSD test ($\alpha = 0.05$).
```

### Python Code

**Config:**

```bash
OUTPUT_FORMAT=py
```

**Task:**

```
Create a Python class for managing workflow configurations with methods for loading and validation.
```

**Output** (`response.py`):

```python
class WorkflowConfig:
    def __init__(self, config_path):
        self.config_path = config_path
        self.data = {}

    def load(self):
        """Load configuration from file."""
        with open(self.config_path) as f:
            # Implementation
            pass
```

## Best Practices

### Choose Appropriate Formats

| Use Case | Recommended Format |
|----------|-------------------|
| General documentation | `md` |
| Structured data extraction | `json` |
| Reports and writeups | `md` or `html` |
| Data tables | `csv` |
| Code generation | `.py`, `.js`, etc. |
| Academic writing | `tex` |
| Configuration | `yaml` or `json` |

### Format Hints

Explicit task instructions work better than relying solely on format hints:

- ✅ **Good:**

```
Extract data as JSON array with fields: id, name, value
```

❌ **Relies on hint:**

```
Extract the data
```

### Validation

For structured formats (JSON, CSV), validate outputs:

```bash
# Validate JSON
jq empty .workflow/extract/output.json

# Check CSV structure
head .workflow/export/output.csv
```

### Version Control

Format choice affects diff readability:

- **JSON:** Use pretty-printing for readable diffs
- **Markdown:** Native git-friendly format
- **Binary/minified:** Consider excluding from version control

## Changing Format

### For Single Run

```bash
wfw run analysis --format json
```

Original config unchanged, applies only to this run.

### For Workflow

Edit workflow config:

```bash
nano .workflow/analysis/config
# Change: OUTPUT_FORMAT=json
```

### For Project

Edit project config:

```bash
nano .workflow/config
# Set default: OUTPUT_FORMAT=md
```

## Output Management

### Multiple Formats from Same Content

Create separate workflows for different formats:

```bash
# Data as JSON
wfw new data-json
# Config: OUTPUT_FORMAT=json, CONTEXT_PATTERN="raw/*.txt"

# Same data as CSV
wfw new data-csv
# Config: OUTPUT_FORMAT=csv, CONTEXT_PATTERN="raw/*.txt"

# Both with same task but different format hints
```

### Format Conversion

Use dependencies for format conversion:

```bash
# Extract as JSON
wfw run extract-data --format json

# Convert to markdown table
wfw new format-as-table
# Config: DEPENDS_ON=(extract-data), OUTPUT_FORMAT=md
# Task: "Convert the JSON data to a markdown table"
wfw run format-as-table
```

## Troubleshooting

### Format Not Applied

Check configuration cascade:

```bash
wfw config workflow-name
# Look for OUTPUT_FORMAT value and source
```

### Post-Processing Fails

If `mdformat` or `jq` are unavailable, output is saved without post-processing. Install tools for automatic formatting:

```bash
pip install mdformat
brew install jq  # or apt install jq
```

### Wrong Format Generated

Claude may not follow format hints perfectly. Improve task instructions:

```
Create valid JSON with this exact structure:
{
  "results": [...]
}

Ensure proper JSON syntax with quoted strings and no trailing commas.
```

## See Also

- [Execution Guide](../user-guide/execution.md) - Running workflows
- [Configuration Guide](../user-guide/configuration.md) - Setting formats
- [Examples](../user-guide/examples.md#example-7-multiple-output-formats) - Format examples

---

Continue to [Context Aggregation](context-aggregation.md) →
