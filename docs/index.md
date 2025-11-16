# Workflow

**A CLI tool for persistent, configurable AI-assisted project development**

Workflow is a portable bash-based tool for managing AI-assisted research and project development workflows using the Anthropic Messages API. It provides a git-like project structure with flexible configuration, context aggregation, and workflow chaining capabilities.

## Key Features

- **🎯 Git-like Structure** - Uses `.workflow/` directories with automatic project root discovery
- **🔧 Flexible Configuration** - Four-tier cascade: global → project → workflow → CLI overrides
- **🔗 Workflow Dependencies** - Chain workflows with `--depends-on` for sequential processing
- **📦 Context Aggregation** - Glob patterns, explicit files, or workflow outputs as context
- **🚀 Portable** - Modular bash-based tool, works from anywhere in project tree
- **💾 Safe Output** - Automatic backups with timestamps, hardlinked outputs
- **⚡ Dual Execution Modes** - Persistent workflows or lightweight one-off tasks
- **📊 Token Estimation** - Cost estimation before API calls
- **🌊 Flexible API Modes** - Single-request and streaming modes (batch processing planned)

## Quick Start

```bash
# Clone repository
git clone https://github.com/jdmonaco/workflow.git
cd workflow

# Add to PATH (example using ~/.local/bin)
ln -s "$(pwd)/workflow.sh" ~/.local/bin/workflow

# Set up environment
export ANTHROPIC_API_KEY="your-key"

# Initialize project
cd ~/my-manuscript
workflow init .

# Create and run first workflow
workflow new 00-context-analysis
workflow run 00-context-analysis --stream
```

## What You Can Do

**Persistent Workflows** - Create reusable workflows for iterative development:

```bash
workflow new analyze-data
workflow run analyze-data --context-pattern "data/*.csv" --stream
```

**One-Off Tasks** - Execute lightweight tasks without workflow persistence:

```bash
workflow task -i "Extract key points" --context-file notes.md
workflow task summarize --context-pattern "*.md"
```

**Workflow Chains** - Build dependent pipelines with automatic context passing:

```bash
workflow run 02-analysis --depends-on 01-context --stream
```

## Use Cases

- **Research manuscripts** - Iterative analysis and writing assistance
- **Code analysis** - Systematic code review and refactoring workflows
- **Documentation** - Generate and update documentation from source code
- **Data processing** - Multi-stage data analysis pipelines
- **Content generation** - Structured content creation with context reuse

## Documentation Structure

- **[Getting Started](getting-started/installation.md)** - Installation, quick start, and your first workflow
- **[User Guide](user-guide/initialization.md)** - Complete guide to using workflow effectively
- **[Reference](reference/cli-reference.md)** - Comprehensive CLI and feature reference
- **[Technical Documentation](technical/architecture.md)** - Implementation details and internals
- **[Troubleshooting](troubleshooting.md)** - Common issues and solutions
- **[Migration Guide](migration.md)** - Upgrading from previous versions

## Requirements

- Bash 4.0+
- `curl` and `jq` for API interaction
- Anthropic API key ([get one here](https://console.anthropic.com/))

## License

MIT License - see repository for details

## Getting Help

```bash
workflow help              # Show all subcommands
workflow help <subcommand> # Show detailed help for a subcommand
workflow <subcommand> -h   # Quick help for a subcommand
```

---

Ready to get started? Head to the [Installation Guide](getting-started/installation.md) →
