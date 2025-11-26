# Troubleshooting

Common issues and solutions for Workflow.

## Installation Issues

### Command Not Found

**Error:** `workflow: command not found`

**Solution:**

```bash
# Check script exists
ls -la ~/bin/workflow

# Make executable
chmod +x ~/bin/workflow

# Check PATH
echo $PATH | grep "$HOME/bin"

# Add to PATH if needed
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Dependencies Missing

**Error:** `jq: command not found`

**Solution:**

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq curl

# CentOS/RHEL
sudo yum install jq curl
```

## API Issues

### API Key Not Set

**Error:** `ANTHROPIC_API_KEY environment variable is not set`

**Solution:**

```bash
# Set environment variable
export ANTHROPIC_API_KEY="sk-ant-..."

# Or add to global config
nano ~/.config/wireflow/config
# Add: ANTHROPIC_API_KEY=sk-ant-...
```

### API Authentication Failed

**Error:** `401 Unauthorized` or `invalid API key`

**Solutions:**

- Verify key starts with `sk-ant-`
- Check key is active in [Anthropic Console](https://console.anthropic.com/)
- Ensure no extra spaces or quotes
- Try regenerating key

### API Rate Limiting

**Error:** `429 Too Many Requests`

**Solutions:**

- Wait a few minutes
- Reduce request frequency
- Check rate limits in console
- Consider upgrading API tier

## Project Issues

### Not in Workflow Project

**Error:** `Error: Not in a workflow project`

**Solution:**

```bash
# Initialize project
wfw init .

# Or navigate to existing project
cd /path/to/project-with-.workflow
```

### Workflow Not Found

**Error:** `Workflow 'xyz' does not exist`

**Solutions:**

```bash
# List existing workflows
wfw list

# Create workflow
wfw new xyz

# Check for typos
ls .workflow/
```

### Permission Denied

**Error:** `Permission denied: .workflow/config`

**Solution:**

```bash
# Fix permissions
chmod u+w .workflow/config
chmod -R u+w .workflow/
```

## Context Issues

### Context Files Not Found

**Error:** `Context file not found: data/file.csv`

**Solutions:**

```bash
# Check file exists
ls data/file.csv

# Remember: Config paths relative to project root
cd $(git rev-parse --show-toplevel)  # or project root
ls data/file.csv

# CLI paths relative to PWD
pwd
ls data/file.csv
```

### Glob Pattern Matches Nothing

**Error:** Context shows 0 files from pattern

**Solutions:**

```bash
# Test pattern in shell
ls data/*.csv

# Check pattern syntax
echo data/*.csv

# Verify paths
pwd  # Where am I?
ls -la  # What's here?

# Remember: Config patterns relative to project root
```

### Dependencies Not Found

**Error:** `Dependency workflow 'xyz' not found or has no output`

**Solutions:**

```bash
# Check workflow exists
wfw list

# Check has output
ls .workflow/xyz/output/

# Run dependency first
wfw run xyz --stream
```

## Configuration Issues

### Config Not Taking Effect

**Problem:** Changes to config don't apply

**Solutions:**

```bash
# Check configuration cascade
wfw config workflow-name

# Verify which config is used
# CLI flags > workflow config > project config > global config

# Check for typos
cat .workflow/workflow-name/config
```

### System Prompts Not Found

**Error:** `System prompt not found: custom.txt`

**Solutions:**

```bash
# Check prompt directory
ls $WIREFLOW_PROMPT_PREFIX/

# Verify environment variable
echo $WIREFLOW_PROMPT_PREFIX

# Check config
grep WIREFLOW_PROMPT_PREFIX ~/.config/wireflow/config

# Create missing prompt
nano ~/.config/wireflow/prompts/custom.txt
```

## Execution Issues

### Token Limit Exceeded

**Error:** `Request exceeds token limit`

**Solutions:**

```bash
# Check estimate
wfw run analysis --count-tokens

# Reduce context
# - Use more specific patterns
# - Remove unnecessary files
# - Split into smaller workflows
# - Use summarization

# Example: Summarize first
wfw run 01-summarize  # Process all data
wfw run 02-final --depends-on 01-summarize  # Use summary only
```

### Streaming Fails

**Problem:** Streaming doesn't work or shows no output

**Solutions:**

```bash
# Check API connectivity
curl -I https://api.anthropic.com

# Try buffered mode
wfw run analysis  # Without --stream

# Check terminal
# Streaming requires TTY
tty

# Redirect if needed
wfw run analysis --stream 2>&1 | less
```

### Output Not Saved

**Problem:** Workflow completes but no output file

**Solutions:**

```bash
# Check output directory
ls -la .workflow/workflow-name/output/

# Check disk space
df -h .

# Check permissions
ls -ld .workflow/workflow-name/
chmod -R u+w .workflow/
```

## Editor Issues

### Editor Not Opening

**Problem:** `wfw edit` doesn't open editor

**Solutions:**

```bash
# Set EDITOR variable
export EDITOR=nano

# Or use vim (default)
export EDITOR=vim

# Or your preferred editor
export EDITOR=code  # VS Code
export EDITOR=emacs

# Add to shell config
echo 'export EDITOR=nano' >> ~/.bashrc
```

### Vim Unfamiliar

**Solution:**

Quick vim guide for workflow editing:

```
i           Enter insert mode (start typing)
<ESC>       Exit insert mode
:w          Save
:q          Quit
:wq         Save and quit
:q!         Quit without saving
```

Or switch to nano:

```bash
export EDITOR=nano
```

## Output Issues

### Response Appears Empty

**Problem:** Output file exists but appears empty

**Solutions:**

```bash
# Check file size
ls -lh .workflow/analysis/output.md

# View file
cat .workflow/analysis/output.md

# Check for API errors
# Look at workflow command output for error messages

# Re-run with dry-run
wfw run analysis --count-tokens
```

### Wrong Output Format

**Problem:** Expected JSON, got Markdown

**Solutions:**

```bash
# Check config
wfw config analysis

# Verify OUTPUT_FORMAT
# Use CLI override
wfw run analysis --format json

# Or update config
nano .workflow/analysis/config
# Add: OUTPUT_FORMAT=json
```

### Backups Not Created

**Problem:** No `-*.*` files

**Solution:**

Backups only created on **re-run**:

```bash
# First run: Creates <name>.md
wfw run analysis

# Second run: Creates backup
wfw run analysis
ls .workflow/analysis/output/
# Now you'll see <name>-TIMESTAMP.md
```

## Global Config Issues

### Global Config Not Created

**Problem:** `~/.config/wireflow/` doesn't exist

**Solution:**

```bash
# Run any workflow command
wfw help

# Or create manually
mkdir -p ~/.config/wireflow/prompts
wfw init /tmp/test-project  # Triggers creation
```

### Config Syntax Errors

**Problem:** Config not loading correctly

**Solutions:**

```bash
# Check bash syntax
bash -n ~/.config/wireflow/config

# Common issues:
# - Missing quotes around values with spaces
# - Incorrect array syntax: Use (value1 value2) not [value1, value2]
# - Trailing commas
# - Special characters not escaped

# Example correct syntax:
MODEL="claude-opus-4-5-20251101"
SYSTEM_PROMPTS=(base research)
CONTEXT_FILES=("file1.md" "file2.txt")
```

## Nested Project Issues

### Nested Detection Fails

**Problem:** Parent project not detected during `wfw init`

**Solutions:**

```bash
# Check for `.workflow/` in parent directories
find . -name ".workflow" -type d

# Manually check
ls ../.workflow/
ls ../../.workflow/
```

### Workflows Don't Find Context

**Problem:** Nested project can't find parent files

**Solution:**

Nested projects are **independent**:

- Separate workflow namespaces
- No automatic parent context
- Must explicitly include parent files

```bash
# In nested project workflow config
CONTEXT_FILES=("../../parent-file.md")  # Explicit path to parent
```

## Task Mode Issues

### Named Task Not Found

**Error:** `Task file not found: summarize.txt`

**Solutions:**

```bash
# Check WIREFLOW_TASK_PREFIX
echo $WIREFLOW_TASK_PREFIX

# Check file exists
ls $WIREFLOW_TASK_PREFIX/summarize.txt

# Create task
mkdir -p ~/.config/wireflow/tasks
echo "Summarize the content" > ~/.config/wireflow/tasks/summarize.txt
```

### Task Output to File Fails

**Problem:** `--output-file` doesn't create file

**Solutions:**

```bash
# Check path is writable
touch test-output.md && rm test-output.md

# Use absolute path
wfw task -i "Test" --output-file /full/path/output.md

# Check disk space
df -h .
```

## Performance Issues

### Slow Execution

**Problem:** Workflows take very long

**Solutions:**

```bash
# Check token count
wfw run analysis --count-tokens

# Reduce context if large
# Check network latency
ping api.anthropic.com

# Try smaller model for testing
wfw run analysis --model claude-haiku-4-5-20251001 --stream
```

### High API Costs

**Problem:** Unexpectedly high bills

**Solutions:**

```bash
# Always estimate first
wfw run expensive-task --count-tokens

# Review token usage
# Look at actual usage in output:
# "API Response received (6,245 input tokens, 1,832 output tokens)"

# Use appropriate model
# - Haiku for simple tasks
# - Sonnet for general tasks
# - Opus only when necessary

# Optimize context
# - Remove unnecessary files
# - Use summaries
# - Split large tasks
```

## Getting Help

### Check Version

```bash
grep "^# Version:" ~/bin/workflow | head -1
```

### Review Logs

Workflow outputs errors to stderr:

```bash
wfw run analysis 2> error.log
cat error.log
```

### Report Issues

1. Check [GitHub Issues](https://github.com/username/workflow/issues)
2. Provide:
   - Workflow version
   - Error message
   - Steps to reproduce
   - Configuration (redact API key!)

### Community Support

- GitHub Discussions
- Documentation at https://docs.example.com
- CLAUDE.md for technical details

## Quick Diagnostic

Run this diagnostic to check common issues:

```bash
# Check installation
which workflow
wfw --help > /dev/null && echo "✓ Workflow installed" || echo "✗ Workflow not found"

# Check dependencies
command -v jq > /dev/null && echo "✓ jq installed" || echo "✗ jq missing"
command -v curl > /dev/null && echo "✓ curl installed" || echo "✗ curl missing"

# Check API key
[ -n "$ANTHROPIC_API_KEY" ] && echo "✓ API key set" || echo "✗ API key not set"

# Check project
[ -d ".workflow" ] && echo "✓ In workflow project" || echo "✗ Not in project"

# Check config
[ -f ~/.config/wireflow/config ] && echo "✓ Global config exists" || echo "✗ No global config"

# Check prompts
[ -d ~/.config/wireflow/prompts ] && echo "✓ Prompt directory exists" || echo "✗ No prompt directory"
```

## See Also

- [Installation Guide](getting-started/installation.md)
- [Configuration Guide](user-guide/configuration.md)
- [CLI Reference](reference/cli-reference.md)
