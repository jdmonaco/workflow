# WireFlow

**Reproducible AI Workflows for Research & Development**

Version 0.5.0 (pre-release)

A terminal-based tool for building reproducible AI workflows with the Anthropic API. Process documents, chain workflows, and manage context—all from the command line.

## Key Features

- 🎯 **Git-like Discovery:** Run from anywhere in your project tree. WireFlow walks up to find `.workflow/` automatically.

- 📄 **Native Documents:** PDFs, Office files, images (including HEIC, TIFF, SVG) handled natively with automatic conversion.

- 🧠 **Model Profiles:** Switch between `fast`, `balanced`, and `deep` reasoning. Enable extended thinking for complex tasks.

- 📦 **Batch Processing:** Process hundreds of documents at 50% cost savings with the Message Batches API.

- 🔧 **Config Cascade:** Global → project → workflow → CLI. Set once, override where needed.

- 🏗️ **Nested Projects:** Inherit settings from parent projects. Perfect for monorepos.

- 🔗 **Workflow Chains:** Build pipelines with `--depends-on`. Outputs feed into dependent workflows.

- 📥 **Input vs Context:** Separate primary documents from supporting materials for cleaner prompts.

- 💰 **90% Cache Savings:** Smart prompt caching puts stable content first. Pay less for repeated runs.

- 📚 **Citations:** Enable source attribution with `--enable-citations`. Get references you can verify.

- ⚡ **Three Modes:** Persistent workflows for iteration, quick `task` mode for one-offs, or `batch` for bulk processing.

- 💾 **Safe Outputs:** Timestamped backups, hardlinked copies, atomic writes. Never lose work.

## Quick Start

To install `wireflow`, clone the [repo](https://github.com/jdmonaco/wireflow) and link the script into your `PATH`. For example:

```bash
# Clone repository
git clone https://github.com/jdmonaco/wireflow.git
cd wireflow

# Add to PATH (example using ~/.local/bin)
ln -s "$(pwd)/wireflow.sh" ~/.local/bin/wfw
```

For Anthropic requests, ensure your API key is set in your shell environment:

```bash
# Set up environment
export ANTHROPIC_API_KEY="your-key"
```

Try out initializing `wireflow` in any folder containing a project or files you want to process:

```bash
# Initialize project
cd ~/my-manuscript
wfw init .

# Create and run first workflow
wfw new 00-context-analysis
wfw run 00-context-analysis --stream
```

Your project files and folders are treated as read-only. All WireFlow files are maintained in a `.workflow/` subfolder.

## What You Can Do

**Persistent Workflows:** Create reusable workflows for iterative development:

```bash
wfw new analyze-data
wfw run analyze-data -cx "data/*.csv" --stream
```

**One-Off Tasks:** Execute lightweight tasks without workflow persistence:

```bash
wfw task -i "Extract key points" -cx notes.md
wfw task summarize -cx "*.md"
```

**Workflow Chains:** Build dependent pipelines with automatic context passing:

```bash
wfw run 02-analysis --depends-on 01-context --stream
```

## Use Cases

- **Research manuscripts:** Iterative analysis and writing assistance
- **Code analysis:** Systematic code review and refactoring workflows
- **Documentation:** Generate and update documentation from source code
- **Data processing:** Multi-stage data analysis pipelines
- **Content generation:** Structured content creation with context reuse

## Documentation Structure

- **[Getting Started](getting-started/installation.md):** Installation, quick start, and your first workflow
- **[User Guide](user-guide/projects.md):** Complete guide to using WireFlow effectively
- **[Reference](reference/cli-reference.md):** Comprehensive CLI and feature reference
- **[Troubleshooting](troubleshooting.md):** Common issues and solutions
- **[Contributing](contributing/index.md):** Contribution guidelines

## Requirements

- Bash 4.0+
- `curl` and `jq` for API interaction
- Anthropic API key ([get one here](https://console.anthropic.com/))

## License

MIT License - see repository for details

## Getting Help

```bash
wfw help              # Show all subcommands
wfw help <subcommand> # Show detailed help for a subcommand
wfw <subcommand> -h   # Quick help for a subcommand
```

---

Ready to get started? Head to the [Installation Guide](getting-started/installation.md) →
