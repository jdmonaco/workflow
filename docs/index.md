# Workflow

**A flexible CLI tool for building persistent AI workflows anywhere you want**

*Build reproducible, configurable workflows for research, development, and analysis with intelligent document processing and sophisticated context management.*

**Version:** 0.2.0 (pre-release)

Workflow is a bash-based command-line tool that lets you easily create and run reproducible AI workflows for research, development, and analysis. Key features include flexible configuration cascades, native document processing (PDFs, Office, images), workflow chaining and dependencies, and sophisticated context management with cost-optimized prompt caching.

## Key Features

- 🎯 **Git-like Project Discovery:**
    Automatic `.workflow/` directory detection by walking up the directory tree from your current location, enabling project-aware execution from anywhere within your project hierarchy. Stops at `$HOME` for safety and respects filesystem boundaries.

- 📄 **Native Document Processing:**
    Unified handling of PDFs (32MB limit, joint text and visual analysis via Claude PDF API), Microsoft Office files (.docx and .pptx automatically converted to PDF via LibreOffice with intelligent mtime-based caching), images (Vision API support with automatic validation, resizing, and base64 encoding), and text files. Automatic format detection, conversion, and optimal ordering (PDFs before text per Anthropic optimization guidelines).

- 🔧 **Configuration Cascade with Pass-Through:**
    Sophisticated multi-tier inheritance system (global → ancestors → project → workflow → CLI) where empty configuration values automatically inherit from parent tiers while explicit values override and become decoupled from upstream changes. This enables centralized defaults that cascade down while maintaining granular control, supporting change-once affect-many configuration management patterns.

- 🏗️ **Nested Project Support:**
    Automatic discovery and configuration inheritance from all ancestor projects in the directory hierarchy. When running workflows in nested projects, the tool walks up the tree to find all `.workflow/` directories, loads their configs from oldest to newest, and provides transparent source tracking showing exactly which ancestor (or tier) set each configuration value.

- 🔗 **Workflow Dependencies & Chaining:**
    Create multi-stage processing pipelines by declaring dependencies on other workflow outputs via `DEPENDS_ON` configuration. Outputs are managed via hardlinks for efficient storage and atomic updates, with automatic context passing enabling complex DAG-based orchestration. Cross-format dependencies work seamlessly (JSON → Markdown → HTML pipelines).

- 📦 **Semantic Content Aggregation:**
    Distinguish between INPUT documents (primary materials to analyze or transform) and CONTEXT materials (supporting information and references) with three aggregation methods: glob patterns for flexible file matching, explicit file lists for precision, and workflow dependencies for pipeline orchestration. Intelligent stable-to-volatile ordering within each category optimizes prompt caching effectiveness.

- 💰 **Prompt Caching Architecture:**
    JSON-first content block architecture with strategic cache breakpoint placement (maximum 4 per API limits) at semantic boundaries enables 90% cost reduction on cached content. Sophisticated ordering strategy places stable content first (system prompts → project descriptions → PDFs → text documents → images → task) with PDFs positioned before text per Anthropic optimization guidelines. Date-only timestamps (not datetime) prevent minute-by-minute cache invalidation while maintaining daily freshness.

- 📚 **Citations Support:**
    Optional Anthropic citations API integration via `--enable-citations` flag provides source attribution for AI-generated content. Automatically generates document index mapping for citable sources (text files and PDFs, excluding images), parses citation responses from the API, and creates sidecar citation files for reference tracking and verification.

- ⚡ **Dual Execution Modes:**
    Run mode provides persistent workflows with full configuration, context aggregation, workflow dependencies, and managed outputs for iterative development. Task mode offers lightweight one-off execution without workflow directories for quick queries. Both modes share core execution logic but are optimized for their specific use cases, providing flexibility between structure and speed.

- 💾 **Safe Output Management:**
    Automatic timestamped backups before overwriting any existing output, hardlinked copies in `.workflow/output/` for convenient access without duplication, atomic file operations with trap-based cleanup, and format-specific post-processing (mdformat for Markdown, jq for JSON pretty-printing). Every workflow run preserves previous results with clear timestamps.

- 📊 **Dual Token Estimation:**
    Fast heuristic character-based token estimation (4 chars per token) provides immediate feedback during workflow preparation, supplemented by exact counts via Anthropic's Token Counting API when API key is available. Detailed breakdowns show token contribution from system prompts, task, input documents, context materials, and images (~1600 tokens per image), with comparison between heuristic and actual counts for calibration.

- 🌊 **Streaming & Batch Modes:**
    Real-time streaming output with Server-Sent Events (SSE) parsing provides immediate feedback as the model generates responses, ideal for interactive development. Single-request batch mode buffers the entire response and opens in a pager when complete, suitable for long-form generation. Both modes support identical configuration, context aggregation, and prompt caching strategies.

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

**Persistent Workflows:** Create reusable workflows for iterative development:

```bash
workflow new analyze-data
workflow run analyze-data --context-pattern "data/*.csv" --stream
```

**One-Off Tasks:** Execute lightweight tasks without workflow persistence:

```bash
workflow task -i "Extract key points" --context-file notes.md
workflow task summarize --context-pattern "*.md"
```

**Workflow Chains:** Build dependent pipelines with automatic context passing:

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
- **[Contributing](contributing/index.md):** Contribution guidelines

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
