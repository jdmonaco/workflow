# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2025-11-25

### Added
- Test runner script `tests/run-tests.sh` with unit/integration/all/quick commands (6686886)
- Unit test files for each lib/*.sh module: api, config, core, edit, execute, help, utils (6686886)
- Integration test files for each CLI command: cat, config, help, init, list, new, run, task (6686886)
- Enhanced test helpers: mock_env.sh, fixtures.sh, assertions.sh (6686886)
- Bash completion script `share/bash-completion.bash` (b2bde30)
- OUTPUT_FILE workflow configuration parameter (33189fc)
- lib/run.sh module for run mode execution (f4afcfb)

### Changed
- Migrated test suite from flat structure (280+ tests) to unit/integration architecture (~137 tests) (6686886)
- Streamlined Key Features in README.md and docs/index.md with punchier descriptions (6937f0a)
- Updated CLI help text with concise descriptions and `--long, -s` option formatting (45ff128)
- Refreshed all documentation for recent refactors (8dacf5a)
- Fixed workflow paths to use `.workflow/run/<name>/` consistently
- Updated contributing guides for new test structure
- Refactored lib/core.sh with function fixes and naming improvements (d05cf0a)
- Refactored wireflow.sh with bug fixes (51774fe)

### Fixed
- Circular dependency handling in lib/execute.sh (43328e9)
- Config cascade behavior in lib/config.sh (fb911ce)
- Task mode execution and critical fixes in lib/task.sh (696cff7)
- API error handling in lib/api.sh (9a2dd46)
- Path resolution and utility enhancements in lib/utils.sh (293857d)
- Task subcommand description display and fallback (6a977a5)
- Editor detection in lib/edit.sh (d6527cd)
- Help documentation and path fixes in lib/help.sh (0a62bca)
- Test failures after renaming (01f5087, 38f3ac8, d29b649)
- Remaining workflow to wireflow renaming issues (bbfce00, e9fc82c)

## [0.3.0] - 2025-11-20

### Added
- Built-in task templates system with 8 generic reusable templates (f6da1b2, ebde182, 93af20c)
- `wfw tasks` subcommand for managing task templates (list, show, edit)
- `wfw new --task <template>` flag to create workflows from templates
- Fallback search for prompts and tasks to preserve built-ins when using custom PREFIX (97827f7)
- Meta system prompt for automatic workflow context orientation (0ed05c1)
- Adaptive cache-control strategy respecting 4-breakpoint API limit (f6da1b2)

### Changed
- **BREAKING:** Renamed project from Workflow to WireFlow (81223c4)
- **BREAKING:** Environment variables: WORKFLOW_*_PREFIX → WIREFLOW_*_PREFIX
- **BREAKING:** Script name: workflow.sh → wireflow.sh
- **BREAKING:** Command name: workflow → wireflow (alias wfw recommended)
- Refactored CLAUDE.md into 3 focused files (74% size reduction) (0c8174a)
- Reorganized contributing docs under docs/contributing/ (534aed0)
- Updated Key Features to reflect v0.2.0 capabilities accurately (7d95bc3)
- Reordered User Guide in docs (Configuration before Creating Workflows)
- Enabled WIREFLOW_TASK_PREFIX by default in global config

### Fixed
- Cache-control strategy now adaptive based on content mix (PDFs/text/images)
- Images now properly receive cache_control (was missing entirely)
- Total breakpoints never exceed 4 (was exceeding with per-section strategy)

## [Unreleased]

## [0.2.0] - 2025-01-20

### Added
- PDF document support via Claude API (32MB limit, joint text+visual analysis)
- Microsoft Office file support (.docx, .pptx auto-conversion via LibreOffice)
- Image processing with Vision API (automatic resizing, 5MB limit)
- Citations API support with document index mapping
- JSON-first content block architecture
- Prompt caching with strategic breakpoint placement
- Nested project descriptions aggregation
- Comprehensive document processing guides

### Changed
- Content blocks now use JSON-first architecture (XML files for debugging only)
- PDF documents positioned before text for optimal processing
- System prompt composition includes project descriptions
- Date format changed to date-only (prevents minute-by-minute cache invalidation)
- Enhanced token estimation with image token calculations

### Fixed
- Path resolution for nested projects
- Office file caching with mtime validation
- Image resizing for Vision API compliance

## [0.1.0] - 2025-11-18

### Added
- Initial pre-release version
- Core workflow management subcommands:
  - `init` - Initialize workflow project structure
  - `new` - Create new workflows with XML task skeleton
  - `edit` - Edit workflow or project files
  - `config` - View and manage configuration cascade
  - `run` - Execute workflows with full context aggregation
  - `task` - Lightweight one-off task execution
  - `cat` - Display workflow output to stdout
  - `open` - Open workflow output in default app (macOS)
  - `list` - List workflows in project
- Task.txt XML skeleton with structured sections:
  - `<description>` - Brief workflow overview
  - `<guidance>` - Strategic approach
  - `<instructions>` - Detailed requirements
  - `<output-format>` - Format specifications
- Configuration cascade system (global → ancestors → project → workflow → CLI)
- Nested project support with config and description inheritance
- Context aggregation from multiple sources:
  - Glob patterns (CONTEXT_PATTERN)
  - Explicit file lists (CONTEXT_FILES)
  - Workflow dependencies (DEPENDS_ON)
  - CLI options (--context-file, --context-pattern)
- Streaming and batch API modes
- Token estimation (--count-tokens)
- Dry-run mode for prompt inspection (--dry-run)
- Cross-platform editor selection (respects VISUAL/EDITOR)
- Refactored execution logic in lib/execute.sh
- Comprehensive test suite (208 tests)
- MkDocs documentation structure
- Version display via --version flag
- CHANGELOG for tracking changes

### Technical Details
- Modular architecture with lib/ directory structure
- Safe execution with backups, atomic writes, cleanup traps
- Git-like project discovery (walks directory tree)
- Hardlinks for output file management
- Pass-through inheritance in configuration cascade
