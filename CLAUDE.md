# Workflow - Development Guide

Quick reference for development workflows and processes.

**For user documentation, see `docs/` directory and README.md.**

## Developer Documentation Index

This guide focuses on development processes and workflows. For deeper technical details, see:

- **[docs/contributing/architecture.md](docs/contributing/architecture.md)**: System design, architecture patterns, and design decisions
- **[docs/contributing/implementation.md](docs/contributing/implementation.md)**: Technical implementation details, module reference, and code-level specifics
- **[dev/CACHE-CONTROL-CHECKLIST.md](dev/CACHE-CONTROL-CHECKLIST.md)**: Cache control implementation verification (not tracked in git)

## Testing Workflows

**Framework:** Bats (Bash Automated Testing System)

**Running tests:**

```bash
# Specific file (PREFERRED - fast, targeted)
bats tests/config.bats
bats tests/cache-control.bats

# Multiple specific files
bats tests/init.bats tests/config.bats

# All tests (AVOID running repeatedly - very slow, 280+ tests)
bats tests/

# Verbose output
bats -t tests/config.bats
```

**IMPORTANT - Test Suite Performance:**

The test suite is extensive (280+ tests) and takes several minutes to complete:
- **DO NOT** run full suite (`bats tests/`) multiple times in a row
- **DO NOT** run full suite to view output differently or process results
- **DO** run specific test files during development: `bats tests/<feature>.bats`
- **DO** run full suite once at the end to verify no regressions
- **DO** run targeted tests iteratively as needed

**Test organization:**
- One file per major feature (init, config, run, task, help, cache-control, etc.)
- Mock global config via `setup_test_env()` in `tests/test_helper/common.sh`
- 280+ tests covering all subcommands and features
- Test files are independent and can be run individually

**Coverage expectations:**
- All subcommands have basic tests
- Configuration cascade tested
- Path resolution tested
- Error conditions tested
- Edge cases covered
- Cache control behavior validated

## Documentation Updates

### Update Protocol

When making interface changes (new features, behavior changes):

**Required updates:**

1. Code implementation and tests
2. `lib/help.sh`: CLI help text
3. `docs/`: User-facing documentation
4. README.md and docs/index.md: Keep synchronized
5. docs/contributing/architecture.md or docs/contributing/implementation.md: Technical details
6. Code comments and library headers

**Checklist:**

- [ ] Implement feature with tests
- [ ] Update help text
- [ ] Update relevant docs pages
- [ ] Update README.md if user-facing
- [ ] Update docs/contributing/architecture.md or docs/contributing/implementation.md with technical details
- [ ] Update code comments
- [ ] Verify README.md ↔ docs/index.md sync
- [ ] Test with `mkdocs serve` (no warnings - activate venv first: `source venv/bin/activate`)

### Documentation Hierarchy

```
README.md               → Brief overview, link to docs
docs/index.md           → Landing page, features
docs/getting-started/   → Installation, tutorials
docs/user-guide/        → Complete usage guide
docs/reference/         → CLI and technical reference
lib/help.sh             → CLI help text
CLAUDE.md                            → Development workflows (this file)
docs/contributing/architecture.md   → System architecture and design
docs/contributing/implementation.md → Technical implementation details
Code comments           → Inline documentation
```

**Critical sync:** README.md ↔ docs/index.md
- Features list must match
- Quick start must be consistent
- Both must reflect current capabilities
- README briefer, index.md more detailed

### Canonical Subcommand Ordering

**All subcommand listings must use this order:**

1. `init`: Project initialization
2. `new`: Create workflows
3. `edit`: Edit workflows/config
4. `config`: View/manage configuration
5. `run`: Execute workflows
6. `task`: Quick execution
7. `cat`: View output
8. `open`: View output in app
9. `list`: List workflows
10. `help`: Documentation

**Rationale:**
- Follows natural workflow progression (setup → prepare → execute → review → utility)
- Groups related commands (run/task, cat/open)
- Improves readability and scannability
- Consistent across all help messages, docs, and tables

**Apply to:**
- Main help message (lib/help.sh)
- Subcommand tables in docs
- Quick reference tables
- README command lists

### Documentation Style Guidelines

**Key Features (README.md and docs/index.md only):**

```markdown
- 🎯 **Feature Name:** Description text on same line, can be 1-2 sentences providing detail.
```

**Other bullet lists:**

```markdown
// Short descriptions (< 10 words):
- **Item:** Brief description

// Longer descriptions:
- **Item:**
  Longer description on next line
```

**Nested bullet indentation:**

```markdown
// ALWAYS use 4 spaces for nested bullets (not 2):
- Top-level item
    - Nested item (4 spaces)
    - Another nested item (4 spaces)
        - Double-nested (8 spaces)

// NOT 2 spaces:
- Top-level item
  - Nested item (2 spaces) ❌ WRONG
```

**Avoid:**
- `**Heading** - Description` (old dash style - use colons instead)
- Emojis outside Key Features
- Inconsistent punctuation
- 2-space indentation for nested bullets (use 4 spaces)

## Development Workflows

### Adding a Subcommand

1. Add case to `workflow.sh` subcommand dispatcher
2. Implement in `lib/core.sh` (or new lib file if complex)
3. Add help function to `lib/help.sh`
4. Add `-h` check to subcommand case
5. Add test file `tests/<subcommand>.bats`
6. Document in `docs/reference/cli-reference.md`

### Modifying Configuration

1. Update loading logic in `lib/config.sh`
2. Update display in `show_config()` in `lib/core.sh`
3. Document in `docs/user-guide/configuration.md`
4. Add tests in `tests/config.bats`

### Changing API Interaction

1. Modify `lib/api.sh`
2. Test both streaming and batch modes
3. Update token estimation if request structure changes

## Version Management

**Current version:** 0.2.0 (pre-release)

**Location:** `WORKFLOW_VERSION` constant in `workflow.sh` (line 5)

**Semantic versioning strategy:**
- **0.x.x:** Pre-release (API may change)
- **1.0.0:** First stable release
- **MAJOR:** Breaking changes to CLI interface or config format
- **MINOR:** New features (backward compatible)
- **PATCH:** Bug fixes (backward compatible)

### Release Process

When preparing a new release, follow these steps in order:

1. **Update RELEASE-NOTES.md:**
   - Add new version section at top: `## Version X.Y.Z (YYYY-MM-DD)`
   - Write comprehensive release notes including:
       - Major features and changes
       - Architecture innovations
       - Complete feature additions
       - Breaking changes (if any)
       - Migration guide (if needed)
       - Target users and use cases
       - Technical highlights
   - Focus on high-level narrative and user impact

2. **Update CHANGELOG.md:**
   - Add new version entry at top: `## [X.Y.Z] - YYYY-MM-DD`
   - List changes organized by type:
       - **Added:** New features
       - **Changed:** Changes to existing functionality
       - **Deprecated:** Soon-to-be removed features
       - **Removed:** Removed features
       - **Fixed:** Bug fixes
       - **Security:** Security fixes
   - Include commit references for traceability
   - Keep entries concise and commit-focused

3. **Bump version numbers:**
   - Edit `WORKFLOW_VERSION` in `workflow.sh` (line 5)
   - Update version in `README.md` (line 3)
   - Update version in `docs/index.md` (if exists)
   - Ensure all three match exactly

4. **Create version bump commit:**
   ```bash
   git add RELEASE-NOTES.md CHANGELOG.md workflow.sh README.md docs/index.md
   git commit -m "chore: Release version X.Y.Z

   Add comprehensive release notes documenting:
   - [Major feature 1]
   - [Major feature 2]
   - [Other significant changes]

   Version bump from X.Y.Z to X.Y.Z reflecting:
   - [Type of changes: new features, bug fixes, etc.]

   [Additional context about the release]

   🤖 Generated with Claude Code
   Co-Authored-By: Claude <noreply@anthropic.com>"
   ```

5. **Create annotated git tag:**
   ```bash
   git tag -a vX.Y.Z -m "Release version X.Y.Z

   Major features:
   - [Feature 1]
   - [Feature 2]
   - [Feature 3]

   See RELEASE-NOTES.md for complete details."
   ```

6. **Verify release:**
   ```bash
   # Check version command
   workflow --version

   # Verify tag
   git tag -l vX.Y.Z
   git show vX.Y.Z --no-patch

   # Check files updated
   git show HEAD --stat
   ```

7. **Push to remote:**
   ```bash
   # Push commits and tags together
   git push origin main --tags

   # Or push separately
   git push origin main
   git push origin vX.Y.Z
   ```

**Version display:**
- `workflow --version` or `workflow -v`: Shows version number
- `workflow --help`: Includes version in header
- RELEASE-NOTES.md: Comprehensive release documentation
- CHANGELOG.md: Commit-focused change tracking

### Release Types

**Patch release (0.2.0 → 0.2.1):**
- Bug fixes only
- No new features
- No breaking changes
- Quick turnaround

**Minor release (0.2.0 → 0.3.0):**
- New features
- Backward compatible
- May include bug fixes
- Enhanced functionality

**Major release (0.9.0 → 1.0.0):**
- Breaking changes
- Major architectural changes
- API incompatibilities
- Requires migration guide

**Pre-release considerations:**
- During 0.x.x series, minor versions may include breaking changes
- Document breaking changes clearly in RELEASE-NOTES.md
- Consider beta tags for experimental features: v0.3.0-beta.1
- First 1.0.0 release signals API stability commitment

## Git Workflow

### Commit Guidelines

**Format:**

```
<type>: <subject>

<body>

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types:** feat, fix, docs, test, refactor, style, chore

**Subject:** Max 72 chars, imperative mood
