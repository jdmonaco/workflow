# Contributing

Thank you for your interest in contributing to Workflow!

## Ways to Contribute

- **Report bugs:** File issues with clear reproduction steps
- **Suggest features:** Propose enhancements or new capabilities
- **Improve documentation:** Fix typos, clarify explanations, add examples
- **Submit code:** Fix bugs or implement features

## Getting Started

### Development Setup

```bash
# Clone repository
git clone https://github.com/username/workflow.git
cd workflow

# Install for local development
ln -s "$(pwd)/workflow.sh" ~/bin/workflow

# Install test framework
git submodule update --init --recursive
```

### Running Tests

```bash
# Run all tests
bats tests/

# Run specific test file
bats tests/config.bats

# Run with verbose output
bats -t tests/
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
│   ├── utils.sh         # Utility functions
│   └── api.sh           # API interaction
├── tests/               # Test suite
│   ├── test_helper/     # Test helpers (submodules)
│   ├── init.bats        # Init tests
│   ├── config.bats      # Config tests
│   ├── run.bats         # Run tests
│   ├── task.bats        # Task tests
│   └── help.bats        # Help tests
├── docs/                # Documentation (MkDocs)
├── README.md            # Project readme
└── mkdocs.yml           # Documentation configuration
```

## Reporting Issues

### Bug Reports

Include:

1. **Workflow version** - `grep "^# Version:" ~/bin/workflow`
2. **Environment** - OS, bash version
3. **Error message** - Complete error output
4. **Steps to reproduce** - Minimal example
5. **Expected vs actual behavior**

**Example:**

```markdown
## Bug: Context pattern not matching files

**Version:** 2.0.0
**OS:** macOS 14.0, bash 5.2

**Steps to reproduce:**
1. Create project: `workflow init test-project`
2. Add config: `CONTEXT_PATTERN="data/*.csv"`
3. Run with dry-run: `workflow run test --count-tokens`

**Expected:** Should match data/file.csv
**Actual:** Shows 0 files matched

**Error output:**
```
Context: 0 files
```

**Additional context:**
Files exist: `ls data/*.csv` shows `data/file.csv`
```

### Feature Requests

Include:

1. **Use case** - What problem does this solve?
2. **Proposed solution** - How should it work?
3. **Alternatives** - Other approaches considered?
4. **Examples** - Show usage examples

## Submitting Changes

### Pull Request Process

1. **Fork and clone** the repository
2. **Create a branch** for your changes
3. **Make your changes** with clear commits
4. **Add tests** for new functionality
5. **Update documentation** as needed
6. **Run tests** to ensure they pass
7. **Submit pull request** with clear description

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

```
docs: Add examples for cross-format dependencies

Added section showing how to chain workflows with different
output formats (JSON → Markdown → HTML).
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

# Bad
process_file() {
file_path=$1
if [ ! -f $file_path ]; then
echo "Error: File not found: $file_path"
return 1
fi
cat $file_path
}
```

### Testing Guidelines

**Test Structure:**

```bash
@test "feature: specific behavior" {
    # Setup
    setup_test_env

    # Execute
    run workflow command args

    # Assert
    assert_success
    assert_output --partial "expected text"

    # Cleanup (if needed)
    cleanup_test_env
}
```

**Test Coverage:**

- Test happy paths
- Test error conditions
- Test edge cases
- Test configuration cascade
- Mock external dependencies (API calls)

### Documentation Guidelines

**User Documentation:**

- Write for end users, not developers
- Use concrete examples
- Explain why, not just how
- Keep it concise
- Use appropriate tone (helpful, not condescending)

**Technical Documentation:**

- Document implementation details in code comments
- Explain design decisions in docstrings
- Note any gotchas or edge cases
- Keep documentation updated with code changes

**Documentation Structure:**

```markdown
# Page Title

Brief introduction (1-2 sentences).

## Section

Explanation with examples:

```bash
# Example command
workflow run analysis
```

Output:

```
Expected output
```

### Tips

- Tip content
- Another tip
```

## Development Workflow

### Making Changes

```bash
# Create feature branch
git checkout -b feature/my-feature

# Make changes
vim workflow.sh

# Test changes
bats tests/

# Commit
git add workflow.sh
git commit -m "feat: Add my feature"
```

### Running Full Test Suite

```bash
# All tests
bats tests/

# Check for shellcheck issues
shellcheck workflow.sh lib/*.sh
```

### Building Documentation

```bash
# Install mkdocs
pip install mkdocs mkdocs-material

# Serve locally
mkdocs serve

# Build
mkdocs build
```

## Code Review

All submissions require review before merging.

**Reviewers check for:**

- Functionality works as described
- Tests cover new code
- Documentation updated
- Code style follows guidelines
- No breaking changes (or documented if necessary)
- Commits are clear and logical

## Community Guidelines

- Be respectful and constructive
- Help others learn and grow
- Focus on the code, not the person
- Assume good intentions
- Welcome newcomers

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

- Open a discussion on GitHub
- Ask in pull request comments
- Check the documentation for details

## See Also

- [User Guide](user-guide/initialization.md) - Complete usage documentation
- [Reference](reference/cli-reference.md) - Technical reference
- [Architecture](development/architecture.md) - System design and architecture patterns
- [Implementation](development/implementation.md) - Technical implementation details
- [GitHub Issues](https://github.com/jdmonaco/workflow/issues) - Bug tracker

---

Thank you for contributing to Workflow!
