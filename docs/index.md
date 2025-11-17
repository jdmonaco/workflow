# Workflow

**A CLI tool for building AI workflows anywhere**

Workflow is a text-configurable, bash-based tool for building and managing AI workflows in the terminal. It provides a git-like project structure with flexible configuration, context aggregation, and workflow chaining capabilities.

## Key Features

- 🎯 **Git-like Structure:** Uses `.workflow/` directories with automatic project root discovery, allowing you to run workflow commands from anywhere within your project tree.

- 🔧 **Flexible Configuration:** Four-tier cascade system (global → project → workflow → CLI overrides) with pass-through inheritance, enabling centralized defaults with granular customization where needed.

- 🔗 **Workflow Dependencies:** Chain workflows together with `--depends-on` for sequential processing, automatically passing outputs as context to dependent workflows.

- 📦 **Context Aggregation:** Powerful context management using glob patterns, explicit file lists, or workflow outputs, giving Claude comprehensive project awareness.

- 🚀 **Portable:** Modular bash-based tool that works anywhere in your project tree, with automatic project root discovery similar to git.

- 💾 **Safe Output:** Automatic timestamped backups of all workflow outputs with hardlinked copies for convenient access, ensuring no work is ever lost.

- ⚡ **Dual Execution Modes:** Choose between persistent workflows for iterative development or lightweight one-off tasks for quick queries, each optimized for its use case.

- 📊 **Token Estimation:** Built-in cost estimation before API calls with detailed breakdowns showing token contribution from each context source.

- 🌊 **Flexible API Modes:** Support for single-request and streaming modes with real-time output, with batch processing mode planned for future releases.

## Quick Start

To install `workflow`, clone the [repo](https://github.com/jdmonaco/workflow) and link the script into your `PATH`. For example:

```bash
# Clone repository
git clone https://github.com/jdmonaco/workflow.git
cd workflow

# Add to PATH (example using ~/.local/bin)
ln -s "$(pwd)/workflow.sh" ~/.local/bin/workflow
```

For Anthropic requests, ensure your API key is set in your shell environment:

```bash
# Set up environment
export ANTHROPIC_API_KEY="your-key"
```

Try out initializing `workflow` in any folder containing a project or files you want to process:

```bash
# Initialize project
cd ~/my-manuscript
workflow init .

# Create and run first workflow
workflow new 00-context-analysis
workflow run 00-context-analysis --stream
```

Your project files and folders are treated as read-only. All `workflow` files are maintained in a `.workflow/` subfolder.

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

- **Research manuscripts:** Iterative analysis and writing assistance
- **Code analysis:** Systematic code review and refactoring workflows
- **Documentation:** Generate and update documentation from source code
- **Data processing:** Multi-stage data analysis pipelines
- **Content generation:** Structured content creation with context reuse

## Documentation Structure

- **[Getting Started](getting-started/installation.md):** Installation, quick start, and your first workflow
- **[User Guide](user-guide/initialization.md):** Complete guide to using workflow effectively
- **[Reference](reference/cli-reference.md):** Comprehensive CLI and feature reference
- **[Troubleshooting](troubleshooting.md):** Common issues and solutions
- **[Contributing](contributing.md):** Contribution guidelines

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
