# Architecture

High-level system design and architecture patterns for WireFlow.

**For detailed implementation:** See the layer-specific documentation linked below.

## Design Principles

- **Git-like Discovery:** Walk up directory tree for `.workflow/`
- **Configuration Cascade:** Transparent pass-through inheritance
- **Modular Libraries:** One file per concern for maintainability
- **Safe Execution:** Backups, atomic writes, cleanup traps

## Module Structure

```
wireflow.sh              # Entry point, argument parsing, subcommand dispatch
lib/
├── core.sh             # Subcommand implementations (init, new, edit, list, config)
├── config.sh           # Configuration loading and cascade logic
├── help.sh             # Help text for all subcommands
├── run.sh              # Run mode (workflow execution with full context)
├── task.sh             # Task mode (lightweight execution without workflow dirs)
├── batch.sh            # Batch mode (Message Batches API)
├── edit.sh             # Cross-platform editor selection
├── execute.sh          # Shared execution logic (prompts, context, API)
├── utils.sh            # Utilities (file processing, project discovery)
└── api.sh              # Anthropic API interaction (streaming and batch)
tests/
├── unit/               # Function-level unit tests (one per lib/*.sh)
├── integration/        # End-to-end command tests (one per subcommand)
├── test_helper/        # Bats support libraries (git submodules)
└── run-tests.sh        # Test runner script
```

## Project Structure

```
project-root/
├── .workflow/                    # Project root marker
│   ├── config                    # Project configuration
│   ├── project.txt               # Project description (optional)
│   ├── output/                   # Hardlinks to workflow outputs
│   ├── cache/                    # Shared conversion cache
│   └── run/<name>/               # Individual workflows
│       ├── task.txt              # Task prompt
│       ├── config                # Workflow configuration
│       └── output.<format>       # Output file
└── (project files...)
```

## Layer Architecture

WireFlow is organized into four technical layers:

### Configuration Layer

Multi-tier cascade: builtin → global → ancestor → project → workflow → CLI → env

**Key concepts:**

- Pass-through inheritance (empty value inherits)
- Nested project support
- Profile system (fast/balanced/deep)

**Details:** [Configuration](configuration.md)

### Content Layer

Handles all data flow: input processing, context aggregation, output management.

**Key concepts:**

- Input vs context semantic separation
- Three aggregation methods (patterns, files, dependencies)
- Automatic file type detection and conversion
- Hardlink output strategy

**Details:** [Content & I/O](content.md)

### Execution Layer

Three execution modes with different persistence models.

**Key concepts:**

- Run mode: full cascade, persistent output
- Task mode: global config only, stdout
- Batch mode: Message Batches API, 50% cost savings
- Streaming vs buffered output delivery

**Details:** [Execution](execution.md)

### API Layer

Anthropic Messages API interaction.

**Key concepts:**

- JSON-first request building
- Prompt caching with strategic breakpoints
- Citations support
- Extended thinking and effort levels

**Details:** [API Layer](api.md)

## Data Flow

```
Input Files ─┐
             ├─► Content     ─► Execution ─► API ─► Output
Context    ──┤   Aggregation    Mode          │
             │                                │
Config ──────┴────────────────────────────────┘
```

1. **Configuration loaded** via cascade
2. **Content aggregated** from patterns, files, dependencies
3. **Execution mode** selected (run/task/batch)
4. **API request** built and sent
5. **Output** written and hardlinked

## Editor Selection

Cross-platform editor detection:

1. `$VISUAL` (highest priority)
2. `$EDITOR`
3. Platform-specific defaults (`uname -s`)
4. Common editor search (`vim`, `nvim`, `emacs`, `nano`, `code`)
5. Fallback: `vi` (POSIX standard)

**Implementation:** `lib/edit.sh`

## See Also

- [Implementation](implementation.md) - Module-by-module reference
- [Configuration](configuration.md) - Config cascade details
- [Content & I/O](content.md) - File processing and aggregation
- [Execution](execution.md) - Execution modes and output delivery
- [API Layer](api.md) - API interaction details
