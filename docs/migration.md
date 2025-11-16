# Migration Guide

Guide for migrating from previous versions of Workflow.

## Version History

### Current Version: 2.0

**Major changes:**

- Global user configuration (`~/.config/workflow/`)
- Simplified system prompt structure
- Task mode for lightweight execution
- Enhanced help system
- Configuration pass-through mechanism

### Previous Version: 1.x

- Project-only configuration
- Required `WORKFLOW_PROMPT_PREFIX` environment variable
- No global defaults

## Migrating from 1.x to 2.0

###  1. Understand the Changes

**New in 2.0:**

- **Global config:** User defaults at `~/.config/workflow/config`
- **Auto-creation:** First run creates global config and prompts
- **Pass-through:** Empty config values inherit from parent tier
- **Task mode:** New `workflow task` subcommand
- **Help system:** `workflow help <subcommand>` for detailed help

**Backwards compatible:**

- Existing projects work without changes
- Configuration file format unchanged
- Command syntax unchanged (except new `task` subcommand)

### 2. Install New Version

```bash
# Back up old version
cp ~/bin/workflow ~/bin/workflow.old

# Download new version
curl -o ~/bin/workflow https://raw.githubusercontent.com/username/workflow/main/workflow.sh
chmod +x ~/bin/workflow
```

### 3. Run Initial Setup

```bash
# Trigger global config creation
workflow help
```

This creates:

- `~/.config/workflow/config` - Global configuration
- `~/.config/workflow/prompts/base.txt` - Default system prompt

### 4. Migrate Global Settings

If you had environment variables, move them to global config:

**Old (1.x):**

```bash
# In ~/.bashrc
export WORKFLOW_PROMPT_PREFIX="$HOME/prompts"
export ANTHROPIC_API_KEY="sk-ant-..."
```

**New (2.0):**

```bash
# In ~/.config/workflow/config
WORKFLOW_PROMPT_PREFIX=$HOME/prompts
ANTHROPIC_API_KEY=sk-ant-...
```

Keep environment variables if preferred - they still work and take precedence.

### 5. Update System Prompts

**Old structure (1.x):**

```
$WORKFLOW_PROMPT_PREFIX/
├── Root.txt       # Base prompt
├── Custom1.txt
└── Custom2.txt
```

**New structure (2.0):**

```
~/.config/workflow/prompts/
├── base.txt       # Replaces Root.txt (auto-created)
├── Custom1.txt    # Copy from old location
└── Custom2.txt    # Copy from old location
```

**Migration steps:**

```bash
# Copy custom prompts
cp $WORKFLOW_PROMPT_PREFIX/*.txt ~/.config/workflow/prompts/

# Or set WORKFLOW_PROMPT_PREFIX in global config to keep old location
echo "WORKFLOW_PROMPT_PREFIX=$HOME/prompts" >> ~/.config/workflow/config
```

**Update SYSTEM_PROMPTS references:**

Old:

```bash
SYSTEM_PROMPTS=(Root Custom1)
```

New:

```bash
SYSTEM_PROMPTS=(base Custom1)  # Root → base
```

### 6. Review Project Configs

Projects work as-is, but consider adopting pass-through:

**Old (1.x):**

```bash
# .workflow/config
MODEL=claude-3-5-sonnet-20241022
TEMPERATURE=1.0
MAX_TOKENS=8192
SYSTEM_PROMPTS=(Root)
```

**New (2.0) - pass-through:**

```bash
# .workflow/config
MODEL=   # Empty - inherits from global
TEMPERATURE=   # Empty - inherits from global
MAX_TOKENS=   # Empty - inherits from global
SYSTEM_PROMPTS=()   # Empty - inherits from global
```

Benefits:

- Change global config → affects all projects
- Override only when needed

### 7. Test Projects

```bash
cd existing-project
workflow list  # Verify project recognized
workflow config  # Check configuration cascade
workflow run existing-workflow --dry-run  # Test without API call
```

## Breaking Changes

### Removed Features

None - 2.0 is backwards compatible.

### Renamed Features

| 1.x | 2.0 |
|-----|-----|
| `Root.txt` system prompt | `base.txt` system prompt |

### Changed Defaults

| Setting | 1.x Default | 2.0 Default |
|---------|-------------|-------------|
| Global config | None | `~/.config/workflow/config` (auto-created) |
| System prompts | Required `WORKFLOW_PROMPT_PREFIX` | Auto-created at `~/.config/workflow/prompts/` |
| Prompt name | `Root` | `base` |

## New Features to Adopt

### Task Mode

Quick, one-off queries without workflow persistence:

```bash
# Inline task
workflow task -i "Summarize this" --context-file notes.md

# Named task
echo "Extract key points" > ~/.config/workflow/tasks/extract.txt
workflow task extract --context-file document.md
```

### Enhanced Help

```bash
workflow help               # Main help
workflow help run           # Detailed run help
workflow run -h             # Quick help
```

### Global Configuration

Set your preferences once:

```bash
# Edit global config
nano ~/.config/workflow/config

# Set preferred model
MODEL=claude-3-opus-4-20250514

# Set default system prompts
SYSTEM_PROMPTS=(base research)
```

All new projects inherit these defaults.

## Troubleshooting Migration

### "Root.txt not found"

Update config files:

```bash
# Find all configs referencing Root
grep -r "Root" .workflow/

# Update to use base
# Old: SYSTEM_PROMPTS=(Root)
# New: SYSTEM_PROMPTS=(base)
```

### Prompts Not Loading

Check prompt directory:

```bash
# Verify location
echo $WORKFLOW_PROMPT_PREFIX
ls $WORKFLOW_PROMPT_PREFIX/

# Or check global config
grep WORKFLOW_PROMPT_PREFIX ~/.config/workflow/config
```

### Configuration Not Applied

Check cascade:

```bash
workflow config workflow-name
# Shows where each value comes from: (global), (project), (workflow)
```

### Projects Don't Inherit Global Config

This is intentional if project configs have explicit values.

To enable inheritance:

```bash
# Edit project config
nano .workflow/config

# Set values to empty
MODEL=
TEMPERATURE=
# etc.
```

## Rollback to 1.x

If you need to rollback:

```bash
# Restore old version
cp ~/bin/workflow.old ~/bin/workflow

# Remove 2.0 global config (optional)
rm -r ~/.config/workflow/
```

Projects continue working - they're compatible with both versions.

## Getting Help

- **Documentation:** See full docs at https://docs.example.com
- **Issues:** Report at https://github.com/username/workflow/issues
- **Changes:** See CHANGELOG.md for detailed version history

## See Also

- [Installation Guide](getting-started/installation.md)
- [Configuration Guide](user-guide/configuration.md)
- [Troubleshooting](troubleshooting.md)
