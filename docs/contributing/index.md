# Contributing

Thank you for your interest in contributing to Workflow!

## Ways to Contribute

- **Report bugs:** File issues with clear reproduction steps
- **Suggest features:** Propose enhancements or new capabilities
- **Improve documentation:** Fix typos, clarify explanations, add examples
- **Submit code:** Fix bugs or implement features

## Getting Started

### Understanding the Codebase

Before contributing code, review the technical documentation:

- [Architecture](architecture.md): System design, architecture patterns, and design decisions
- [Implementation](implementation.md): Module reference, implementation details, and technical gotchas

These provide comprehensive context for understanding how Workflow is built and how components interact.

### Development Setup

```bash
# Clone repository
git clone https://github.com/jdmonaco/workflow.git
cd workflow

# Install for local development
ln -s "$(pwd)/workflow.sh" ~/bin/workflow

# Install test framework
git submodule update --init --recursive
```

### Running Tests

```bash
# Run specific test file (PREFERRED - fast)
bats tests/config.bats

# Run all tests (slow - 280+ tests)
bats tests/

# Run with verbose output
bats -t tests/config.bats
```

### Project Structure

```
workflow/
├── workflow.sh           # Main script
├── lib/                  # Library modules
│   ├── core.sh          # Core subcommands
│   ├── config.sh        # Configuration management
│   ├── help.sh          # Help system
│   ├── task.sh          # Task mode
│   ├── execute.sh       # Shared execution logic
│   ├── utils.sh         # Utility functions
│   └── api.sh           # API interaction
├── tests/               # Test suite
│   ├── test_helper/     # Test helpers (submodules)
│   └── *.bats          # Test files
├── docs/                # Documentation (MkDocs)
└── mkdocs.yml           # Documentation configuration
```

## Development Workflow

### Commit Guidelines

**Format:**

```
<type>: <subject>

<body>

<footer>
```

**Types:**

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `test:` Test additions or fixes
- `refactor:` Code refactoring
- `style:` Code style changes (formatting)
- `chore:` Maintenance tasks

**Examples:**

```
feat: Add task mode for lightweight execution

Implements workflow task subcommand for one-off queries without
creating workflow directories. Supports inline and named tasks.

Closes #42
```

```
fix: Correct path resolution for nested projects

Config file paths are now correctly resolved relative to project
root when run from subdirectories.

Fixes #56
```

### Code Style

**Bash Style:**

- Use `#!/usr/bin/env bash` shebang
- 4-space indentation
- Use `[[ ]]` for conditionals
- Quote variables: `"$var"` not `$var`
- Use `local` for function variables
- Add comments for complex logic

**Example:**

```bash
# Good
process_file() {
    local file_path="$1"

    if [[ ! -f "$file_path" ]]; then
        echo "Error: File not found: $file_path" >&2
        return 1
    fi

    # Process file content
    cat "$file_path"
}
```

## See Also

- [User Guide](../user-guide/initialization.md): Complete usage documentation
- [Reference](../reference/cli-reference.md): Technical reference
- [Architecture](architecture.md): System design and architecture patterns
- [Implementation](implementation.md): Technical implementation details
- [GitHub Issues](https://github.com/jdmonaco/workflow/issues): Bug tracker

---

Thank you for contributing to Workflow!
