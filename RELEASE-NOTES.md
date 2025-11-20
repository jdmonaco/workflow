# Release Notes

## Version 0.2.0 (2025-01-20)

This release marks a significant milestone with comprehensive document processing capabilities and architectural maturity.

### Major Features

- **PDF Document Support:** Native processing via Claude API with joint text and visual analysis (32MB limit)
- **Microsoft Office Support:** Automatic conversion of .docx and .pptx files with intelligent caching
- **Image Processing:** Vision API integration with automatic resizing and validation
- **Enhanced Documentation:** Complete user guides for document types and LibreOffice setup

### Core Architecture & Unique Innovations

#### 1. Git-like Project Discovery with Configuration Cascade

The tool implements a sophisticated multi-tier configuration cascade (global → ancestors → project → workflow → CLI) with **pass-through inheritance**. Empty values automatically inherit from parent tiers, while explicit values override and become decoupled. This enables centralized defaults that cascade down but can be overridden at any level. Nested projects automatically inherit ALL ancestor configurations in the hierarchy.

**Innovation:** Unlike most tools with simple config hierarchies, this provides transparent inheritance where changing a global default automatically affects all empty configs downstream.

#### 2. Semantic Content Separation

Distinguishes between **INPUT documents** (primary materials to analyze/transform) and **CONTEXT materials** (supporting information) with three aggregation methods: glob patterns, explicit file lists, and workflow dependencies.

**Innovation:** This semantic separation enables precise control over what the AI analyzes vs what provides background, with automatic ordering optimization.

#### 3. Workflow Chaining and Dependencies

Workflows can declare dependencies on other workflow outputs via `DEPENDS_ON`. Outputs are managed via hardlinks for efficient storage and atomic updates. Cross-format dependencies work seamlessly (JSON → Markdown → HTML pipelines).

**Innovation:** Creates a DAG of processing stages where outputs automatically feed as context into dependent workflows, enabling complex multi-stage pipelines.

#### 4. Dual Execution Modes

- **Run mode:** Persistent workflows with configuration, context, dependencies, outputs
- **Task mode:** Lightweight one-off execution without workflow directories

Both modes share execution logic but optimized for different use cases.

**Innovation:** One tool handles both persistent iterative development and quick ad-hoc queries.

#### 5. Advanced Document Processing

- Automatic detection and processing of PDFs (32MB limit, ~2000 tokens/page)
- Office file conversion (.docx, .pptx) via LibreOffice with smart caching
- Vision API support for images (5MB limit, automatic resizing, base64 encoding)
- Text files with embedded metadata

**Innovation:** Unified handling of text, PDFs, Office files, and images with automatic format detection, conversion, caching, and optimal ordering.

#### 6. Prompt Caching Architecture

JSON-first content block architecture with strategic cache breakpoint placement (max 4) at semantic boundaries. Stable-to-volatile ordering: system prompts → project descriptions → PDFs → text → images → task. Date-only timestamps (not datetime) to prevent minute-by-minute cache invalidation.

**Innovation:** Sophisticated caching strategy that can achieve 90% cost reduction by carefully ordering content from most stable (system prompts) to most volatile (task), with PDFs placed before text per Anthropic optimization guidelines.

#### 7. Citations Support

Optional Anthropic citations API support via `--enable-citations` flag. Generates document map for citable sources (text and PDFs, not images). Parses citation responses and formats them appropriately. Creates sidecar citations files for reference.

**Innovation:** Enables AI-generated content with proper source attribution.

### Complete Feature List

#### Core Workflow Management

- `init` - Initialize project with .workflow/ structure
- `new` - Create workflows with XML task skeleton
- `edit` - Open workflow/project files in editor
- `config` - View configuration cascade with source tracking
- `run` - Execute workflows with full context aggregation
- `task` - Lightweight one-off task execution
- `cat` - Display output to stdout
- `open` - Open output in default application (macOS)
- `list` - List all workflows in project

#### Configuration System

- Multi-tier cascade: global → ancestors → project → workflow → CLI
- Pass-through inheritance (empty values inherit, non-empty override)
- Nested project support with automatic ancestor discovery
- Subshell isolation for safe config sourcing
- Source tracking (shows where each value comes from)
- Cross-platform editor detection

#### Context Aggregation

- Three methods: glob patterns, explicit file lists, workflow dependencies
- Semantic separation: INPUT vs CONTEXT materials
- Project-relative paths in configs, PWD-relative in CLI
- Brace expansion and recursive glob patterns
- Automatic file type detection (text, PDF, Office, images)

#### Document Processing

- PDFs: Native support via Claude PDF API (32MB limit)
- Office files: Automatic conversion via LibreOffice (.docx, .pptx)
- Images: Vision API support with validation, resizing, caching
- Text files: Multiple formats with metadata embedding
- Smart caching with mtime validation

#### API Integration

- Anthropic Messages API with streaming and batch modes
- Prompt caching with strategic breakpoint placement
- Token estimation: dual approach (heuristic + exact API count)
- Citations support with document mapping
- Dry-run mode for prompt inspection
- Large payload handling via jq --slurpfile

#### Output Management

- Automatic timestamped backups
- Hardlinked copies for convenient access
- Format-specific post-processing (mdformat, jq)
- Multiple output formats (md, json, txt, html, etc.)
- Atomic updates with trap-based cleanup

#### Safety and Robustness

- Automatic backups before overwriting
- Atomic file operations
- Trap-based cleanup on exit
- Subshell isolation for config extraction
- Git-like project boundary detection (stops at $HOME)

#### Developer Experience

- XML task skeleton with structured sections
- Named task templates (reusable task definitions)
- Token estimation before API calls
- Comprehensive help system (git-style)
- 205+ test suite using Bats
- Detailed documentation with MkDocs

### Current API Support & Extensibility

#### Anthropic API Support

- Messages API (single and streaming)
- Prompt Caching API (ephemeral cache control)
- Token Counting API (exact token estimation)
- PDF API (native document support)
- Vision API (image processing)
- Citations API (source attribution)

#### Extensibility Architecture

**Modular library structure** (lib/):
- `api.sh` - API interaction
- `config.sh` - Configuration loading
- `core.sh` - Subcommand implementations
- `execute.sh` - Shared execution logic
- `utils.sh` - File processing utilities
- `task.sh` - Task mode logic
- `help.sh` - Help text
- `edit.sh` - Editor selection

**Configuration as code:**
- Config files are bash scripts (can include logic)
- Easy to extend with new variables
- Pass-through mechanism scales automatically

**Content block architecture:**
- JSON-first design
- Each file becomes a separate content block
- Enables future format support (e.g., more document types)
- Custom converter for pseudo-XML convenience views

**Custom system prompts:**
- User-definable prompts in ~/.config/workflow/prompts/
- Composable via SYSTEM_PROMPTS array
- Project and workflow overrides

**Named task templates:**
- Reusable task definitions in ~/.config/workflow/tasks/
- Shareable across projects

### Target Users & Use Cases

#### Primary Audience

Technical users with high AI/LLM familiarity and shell proficiency who need:
- Reproducible AI workflows
- Complex multi-stage processing pipelines
- Project-aware context management
- Cost-effective prompt caching
- Integration with existing tools

#### Key User Profiles

**Research Scientists:**
- Multi-stage analysis pipelines
- Paper writing with context management
- Data analysis and visualization workflows
- Citation tracking for AI-generated content

**Software Developers:**
- Code review workflows
- Documentation generation
- Multi-file refactoring analysis
- Architecture and design assistance

**Technical Writers:**
- Structured content generation
- Document transformation (Office → PDF → Markdown)
- Multi-stage editing workflows
- Cross-referencing and citations

**Data Scientists:**
- Exploratory data analysis
- Report generation from datasets
- Multi-format output (JSON, Markdown, HTML)
- Pipeline orchestration

#### Enabled Workflows

**Research Pipelines:**
Context gathering from PDFs/papers → Outline generation → Section drafting → Review/refinement

**Code Analysis:**
Codebase exploration → Architecture analysis → Documentation generation → Review

**Data Processing:**
Data ingestion → Exploratory analysis → Statistical testing → Report generation → Visualization

**Content Creation:**
Research/context → Outline → Draft → Edit → Format conversion

**Iterative Development:**
Initial attempt → Review output → Refine task → Re-run (with automatic backup)

### Pain Points Solved

**Context Management Complexity:**
- **Problem:** Managing large codebases/datasets as context for AI
- **Solution:** Glob patterns, explicit files, and workflow dependencies with semantic separation

**Cost of Repetitive Prompts:**
- **Problem:** Paying for same system prompts and context repeatedly
- **Solution:** Prompt caching with 90% cost reduction on cached content

**Configuration Sprawl:**
- **Problem:** Repeating settings across projects and workflows
- **Solution:** Pass-through cascade enables change-once, affect-many

**Multi-Stage Processing:**
- **Problem:** Manually copying outputs between stages
- **Solution:** Workflow dependencies with automatic context passing

**Output Management:**
- **Problem:** Losing previous versions when iterating
- **Solution:** Automatic timestamped backups with hardlinked access

**Format Fragmentation:**
- **Problem:** Different tools for PDFs, images, Office files, text
- **Solution:** Unified document processing with automatic detection and conversion

**One-Off vs Persistent Workflows:**
- **Problem:** Need both quick queries and persistent workflows
- **Solution:** Dual execution modes optimized for each use case

**Source Attribution:**
- **Problem:** AI-generated content lacks proper citations
- **Solution:** Citations API integration with document mapping

### Unique Selling Points vs Other AI CLI Tools

**vs aider/cursor/copilot:**
- Not code-focused; document and workflow-focused
- Multi-stage pipelines with dependencies
- Sophisticated context aggregation beyond current file
- Prompt caching for cost optimization

**vs chatgpt-cli/claude-cli:**
- Persistent workflows with configuration
- Project-aware with automatic discovery
- Multi-tier config cascade
- Workflow chaining and dependencies
- Native document processing (PDFs, Office, images)

**vs custom scripts:**
- Structured configuration system
- Built-in prompt caching
- Safe output management
- Cross-platform compatibility
- Comprehensive documentation and testing

#### Key Differentiators

1. **Configuration sophistication:** Pass-through cascade is unique
2. **Workflow chaining:** DAG-based pipeline orchestration
3. **Document processing breadth:** Unified handling of text, PDFs, Office, images
4. **Cost optimization:** Strategic prompt caching architecture
5. **Git-like UX:** Familiar project discovery and structure
6. **Dual execution modes:** Both persistent and ad-hoc in one tool
7. **Citations support:** Source attribution for generated content

### Technical Highlights

- **205+ comprehensive test suite** using Bats testing framework
- **Modular architecture** with 8 separate library modules
- **Cross-platform support** (macOS, Linux, WSL)
- **Safe execution** with atomic operations and automatic backups
- **Efficient caching** for images and Office file conversions
- **Robust error handling** with graceful degradation

### Installation & Requirements

**Required:**
- Bash 4.0+
- curl
- jq
- Anthropic API key

**Optional:**
- LibreOffice (for .docx/.pptx support)
- ImageMagick (for optimal image resizing)
- mdformat (for Markdown formatting)

### What's Next

This pre-release (0.2.0) represents a mature foundation with comprehensive document processing. The tool is production-ready for personal and research use. Future directions may include:

- Additional API provider support (OpenAI-compatible endpoints)
- Batch API integration for cost-effective processing
- Enhanced citation formatting options
- Additional document format support
- Web-based workflow visualization

### Commits in This Release

- bc12145: feat: Add PDF document support with optimized API ordering
- 5023475: feat: Add Microsoft Office file support with PDF conversion
- 45cac86: docs: Add comprehensive document type support documentation
- 8af897e: fix: Correct context aggregation order in execution guide

### Acknowledgments

This tool represents a sophisticated approach to AI workflow management, built with attention to cost optimization, reproducibility, and developer experience. Special thanks to the Anthropic team for their excellent API documentation and the LibreOffice project for enabling Office file conversion.
