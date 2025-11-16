# Workflow - AI-Assisted Development Tool

A portable CLI tool for managing AI-assisted research and project development workflows using the Anthropic Messages API.

## Features

- 🎯 **Git-like Structure** - Uses `.workflow/` directories with automatic project root discovery
- 🔧 **Flexible Configuration** - Four-tier cascade: global → project → workflow → CLI overrides
- 🔗 **Workflow Dependencies** - Chain workflows with `--depends-on` for sequential processing
- 📦 **Context Aggregation** - Glob patterns, explicit files, or workflow outputs as context
- 🚀 **Portable** - Modular bash-based tool, works from anywhere in project tree
- 💾 **Safe Output** - Automatic backups with timestamps, hardlinked outputs
- ⚡ **Dual Execution Modes** - Persistent workflows or lightweight one-off tasks
- 📊 **Token Estimation** - Cost estimation before API calls
- 🌊 **Flexible API Modes** - Single-request and streaming modes (batch processing planned)

## Quick Start

### Install

To install `workflow`, clone the [repo](https://github.com/jdmonaco/workflow) and link the script into your `PATH`. For example:

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

**📚 Complete documentation:** [https://docs.example.com](https://docs.example.com)

### Quick Links

- **[Installation Guide](docs/getting-started/installation.md)** - Detailed setup instructions
- **[Quick Start Guide](docs/getting-started/quickstart.md)** - Get running in 5 minutes
- **[User Guide](docs/user-guide/initialization.md)** - Complete usage documentation
- **[CLI Reference](docs/reference/cli-reference.md)** - All commands and options
- **[Examples](docs/user-guide/examples.md)** - Real-world usage patterns
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions

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

Four-tier cascade with pass-through:

```
Global (~/.config/workflow/config)
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

Contributions welcome! See [CONTRIBUTING.md](docs/contributing.md) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Resources

- **GitHub:** [https://github.com/jdmonaco/workflow](https://github.com/jdmonaco/workflow)
- **Issues:** [GitHub Issues](https://github.com/jdmonaco/workflow/issues)
- **Anthropic API:** [https://docs.anthropic.com/](https://docs.anthropic.com/)
- **Technical Details:** [CLAUDE.md](CLAUDE.md)

---

Made with [Claude Code](https://claude.com/claude-code)
