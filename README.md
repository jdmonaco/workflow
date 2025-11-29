# WireFlow

**Reproducible AI Workflows for Research & Development**

Version 0.5.0 (pre-release) · [Documentation](https://docs.joemona.co/wireflow/) · [GitHub](https://github.com/jdmonaco/wireflow)

## Key Features

- 🎯 **Git-like Discovery:** Run from anywhere in your project tree. WireFlow walks up to find `.workflow/` automatically.
- 📄 **Native Documents:** PDFs, Office files, images (including HEIC, TIFF, SVG) handled natively with automatic conversion.
- 📎 **Obsidian Embeds:** `![[file]]` syntax auto-resolves. Embedded images and PDFs become content blocks.
- 🧠 **Model Profiles:** Switch between `fast`, `balanced`, and `deep` reasoning. Enable extended thinking for complex tasks.
- 📦 **Batch Processing:** Process hundreds of documents at 50% cost savings with the Message Batches API.
- 🔧 **Config Cascade:** Global → project → workflow → CLI. Set once, override where needed.
- 🏗️ **Nested Projects:** Inherit settings from parent projects. Perfect for monorepos.
- 🔗 **Workflow Chains:** Build pipelines with `--depends-on`. Stale dependencies auto-execute before the target.
- 📥 **Input vs Context:** Separate primary documents from supporting materials for cleaner prompts.
- 💰 **90% Cache Savings:** Smart prompt caching puts stable content first. Pay less for repeated runs.
- 📚 **Citations:** Enable source attribution with `--enable-citations`. Get references you can verify.
- ⚡ **Three Modes:** Persistent workflows for iteration, quick `task` mode for one-offs, or `batch` for bulk processing.
- 💾 **Safe Outputs:** Timestamped backups, hardlinked copies, atomic writes. Never lose work.

## Quick Start

### Install

Clone the [repo](https://github.com/jdmonaco/wireflow) and run the installer:

```bash
# Clone repository
git clone https://github.com/jdmonaco/wireflow.git
cd wireflow

# Install (creates symlinks to ~/.local/bin and bash completions)
./wireflow.sh shell install
```

### Setup

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export PATH="$HOME/.local/bin:$PATH"  # if not already in PATH
```

### Create Your First Workflow

```bash
# Initialize project
cd my-project
wfw init .

# Create workflow
wfw new analyze-data

# Edit workflow config
wfw edit analyze-data

# Run with context
wfw run analyze-data -cx data.csv --stream
```

Your project files and folders are treated as read-only. All WireFlow files are maintained in a `.workflow/` subfolder.

## Documentation

**📚 Complete documentation:** [https://docs.joemona.co/wireflow/](https://docs.joemona.co/wireflow/)

### Quick Links

- **[Installation Guide](https://docs.joemona.co/wireflow/getting-started/installation/):** Detailed setup instructions
- **[Quick Start Guide](https://docs.joemona.co/wireflow/getting-started/quickstart/):** Get running in 5 minutes
- **[User Guide](https://docs.joemona.co/wireflow/user-guide/projects/):** Complete usage documentation
- **[CLI Reference](https://docs.joemona.co/wireflow/reference/):** All commands and options
- **[Troubleshooting](https://docs.joemona.co/wireflow/troubleshooting/):** Common issues and solutions

## Core Concepts

### Workflows

Persistent, named tasks with configuration and outputs:

```bash
wfw new 01-analysis
wfw run 01-analysis --stream
```

### Tasks

Lightweight, one-off execution without persistence:

```bash
wfw task -i "Summarize these notes" -cx notes.md
```

### Dependencies

Chain workflows to build pipelines:

```bash
wfw run 02-report --depends-on 01-analysis --stream
```

### Configuration

Multi-tier cascade with pass-through:

```
Global (~/.config/wireflow/config)
    ↓
Ancestor Projects (grandparent → parent)
    ↓
Project (.workflow/config)
    ↓
Workflow (.workflow/run/<name>/config)
    ↓
CLI Flags (--model, --temperature, etc.)
```

## Usage Examples

### Simple Analysis

```bash
wfw init my-analysis
wfw new analyze-data
wfw run analyze-data -cx data.csv --stream
```

### Workflow Chain

```bash
wfw run 00-context --stream
wfw run 01-outline --depends-on 00-context --stream
wfw run 02-draft --depends-on 00-context 01-outline --stream
```

### Quick Query

```bash
wfw task -i "Extract action items" -cx meeting-notes.md
```

## Requirements

- Bash 4.0+
- `curl` and `jq`
- Anthropic API key ([get one here](https://console.anthropic.com/))

## Configuration

### Global Configuration

Auto-created on first use at `~/.config/wireflow/`:

- `config` - Global defaults for all projects
- `prompts/base.txt` - Default system prompt
- `tasks/` - Named task templates (optional)

### Project Configuration

Created by `wfw init`:

- `.workflow/config` - Project-level settings
- `.workflow/project.txt` - Project description (optional)
- `.workflow/run/<name>/` - Individual workflows

## Help

```bash
wfw help              # Show all subcommands
wfw help <subcommand> # Detailed subcommand help
wfw <subcommand> -h   # Quick help
```

## Contributing

Contributions welcome! See the [Developer Guide](https://docs.joemona.co/wireflow/developer-guide/) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Resources

- **GitHub:** [https://github.com/jdmonaco/wireflow](https://github.com/jdmonaco/wireflow)
- **Issues:** [GitHub Issues](https://github.com/jdmonaco/wireflow/issues)
- **Anthropic API:** [https://docs.anthropic.com/](https://docs.anthropic.com/)
- **Technical Details:** [CLAUDE.md](CLAUDE.md)

---

Made with [Claude Code](https://claude.com/claude-code)
