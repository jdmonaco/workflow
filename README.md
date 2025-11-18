# A CLI Tool for AI Workflows in the Terminal

A flexible, configurable CLI tool for building and managing AI workflows for research and project development using the Anthropic API.

## Features

- 🎯 **Git-like Structure:** Uses `.workflow/` directories with automatic project root discovery, allowing you to run workflow commands from anywhere within your project tree.
- 🔧 **Flexible Configuration:** Multi-tier cascade with pass-through inheritance (global → ancestors → project → workflow → CLI), enabling centralized defaults with granular overrides.
- 🔗 **Workflow Dependencies:** Chain workflows together with `--depends-on` for sequential processing, automatically passing outputs as context to dependent workflows.
- 📦 **Context Aggregation:** Powerful context management using glob patterns, explicit file lists, or workflow outputs, giving Claude comprehensive project awareness.
- 🚀 **Portable:** Modular bash-based tool works anywhere in your project tree, with automatic project root discovery just like git.
- 💾 **Safe Output:** Automatic timestamped backups of all workflow outputs with hardlinked copies for convenient access, ensuring no work is ever lost.
- ⚡ **Dual Execution Modes:** Choose between persistent workflows for iterative development or lightweight one-off tasks for quick queries, each optimized for its use case.
- 📊 **Token Estimation:** Built-in cost estimation before API calls with detailed breakdowns showing token contribution from each context source.
- 🌊 **Flexible API Modes:** Support for single-request and streaming modes with real-time output, with batch processing mode planned for future releases.

## Quick Start

### Install

First, clone the [repo](https://github.com/jdmonaco/workflow) and then link the script into your `PATH`. For example:

```bash
# Clone repository
git clone https://github.com/jdmonaco/workflow.git
cd workflow

# Add to PATH (example using ~/.local/bin)
ln -s "$(pwd)/workflow.sh" ~/.local/bin/workflow
```

### Setup

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export PATH="$HOME/.local/bin:$PATH"
```

### Create Your First Workflow

```bash
# Initialize project
cd my-project
workflow init .

# Create workflow
workflow new analyze-data

# Edit workflow config
workflow edit analyze-data

# Run with context
workflow run analyze-data --context-file data.csv --stream
```

Your project files and folders are treated as read-only. All `workflow` files are maintained in a `.workflow/` subfolder.

## Documentation

**📚 Complete documentation:** [https://docs.joemona.co/workflow/](https://docs.joemona.co/workflow/)

### Quick Links

- **[Installation Guide](https://docs.joemona.co/workflow/getting-started/installation/):** Detailed setup instructions
- **[Quick Start Guide](https://docs.joemona.co/workflow/getting-started/quickstart/):** Get running in 5 minutes
- **[User Guide](https://docs.joemona.co/workflow/user-guide/initialization/):** Complete usage documentation
- **[CLI Reference](https://docs.joemona.co/workflow/reference/cli-reference/):** All commands and options
- **[Examples](https://docs.joemona.co/workflow/user-guide/examples/):** Real-world usage patterns
- **[Troubleshooting](https://docs.joemona.co/workflow/troubleshooting/):** Common issues and solutions

## Core Concepts

### Workflows

Persistent, named tasks with configuration and outputs:

```bash
workflow new 01-analysis
workflow run 01-analysis --stream
```

### Tasks

Lightweight, one-off execution without persistence:

```bash
workflow task -i "Summarize these notes" --context-file notes.md
```

### Dependencies

Chain workflows to build pipelines:

```bash
workflow run 02-report --depends-on 01-analysis --stream
```

### Configuration

Multi-tier cascade with pass-through:

```
Global (~/.config/workflow/config)
    ↓
Ancestor Projects (grandparent → parent)
    ↓
Project (.workflow/config)
    ↓
Workflow (.workflow/<workflow_name>/config)
    ↓
CLI Flags (--model, --temperature, etc.)
```

## Usage Examples

### Simple Analysis

```bash
workflow init my-analysis
workflow new analyze-data
workflow run analyze-data --context-file data.csv --stream
```

### Workflow Chain

```bash
workflow run 00-context --stream
workflow run 01-outline --depends-on 00-context --stream
workflow run 02-draft --depends-on 00-context,01-outline --stream
```

### Quick Query

```bash
workflow task -i "Extract action items" --context-file meeting-notes.md
```

## Requirements

- Bash 4.0+
- `curl` and `jq`
- Anthropic API key ([get one here](https://console.anthropic.com/))

## Configuration

### Global Configuration

Auto-created on first use at `~/.config/workflow/`:

- `config` - Global defaults for all projects
- `prompts/base.txt` - Default system prompt
- `tasks/` - Named task templates (optional)

### Project Configuration

Created by `workflow init`:

- `.workflow/config` - Project-level settings
- `.workflow/project.txt` - Project description (optional)
- `.workflow/<workflow-name>/` - Individual workflows

## Help

```bash
workflow help              # Show all subcommands
workflow help <subcommand> # Detailed subcommand help
workflow <subcommand> -h   # Quick help
```

## Contributing

Contributions welcome! See [CONTRIBUTING.md](https://docs.joemona.co/workflow/contributing/) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Resources

- **GitHub:** [https://github.com/jdmonaco/workflow](https://github.com/jdmonaco/workflow)
- **Issues:** [GitHub Issues](https://github.com/jdmonaco/workflow/issues)
- **Anthropic API:** [https://docs.anthropic.com/](https://docs.anthropic.com/)
- **Technical Details:** [CLAUDE.md](CLAUDE.md)

---

Made with [Claude Code](https://claude.com/claude-code)
