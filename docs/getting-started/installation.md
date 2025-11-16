# Installation

This guide will walk you through installing and setting up the Workflow CLI tool.

## Prerequisites

Before installing Workflow, ensure you have the following:

- **Bash 4.0+:** The tool is written as a bash script
- **curl:** For downloading files and making API calls
- **jq:** For JSON processing
- **Anthropic API key:** Required for making API calls

### Getting an Anthropic API Key

If you don't have an Anthropic API key yet:

1. Visit the [Anthropic Console](https://console.anthropic.com/)
2. Sign up or log in to your account
3. Navigate to API Keys section
4. Create a new API key
5. Save it securely - you'll need it for configuration

!!! warning "Keep Your API Key Secure"
    Never commit your API key to version control or share it publicly. Use environment variables or the global configuration file to store it securely.

## Installation Methods

### Method 1: Clone Repository (Recommended)

Clone the repository and add to your PATH:

```bash
# Clone the repository
git clone https://github.com/jdmonaco/workflow.git
cd workflow

# Create symlink to add to PATH
# Option A: User-local installation (~/.local/bin)
ln -s "$(pwd)/workflow.sh" ~/.local/bin/workflow

# Option B: User bin directory (~/bin)
ln -s "$(pwd)/workflow.sh" ~/bin/workflow

# Verify installation
workflow help
```

!!! tip "Add to PATH"
    Ensure your chosen directory is in your PATH. Add to `~/.bashrc` or `~/.zshrc`:
    ```bash
    # For ~/.local/bin
    export PATH="$HOME/.local/bin:$PATH"

    # For ~/bin
    export PATH="$HOME/bin:$PATH"
    ```

### Method 2: System-Wide Installation

For system-wide installation (requires sudo):

```bash
# Clone the repository
git clone https://github.com/jdmonaco/workflow.git
cd workflow

# Create symlink in system directory
sudo ln -s "$(pwd)/workflow.sh" /usr/local/bin/workflow
```

### Why Clone Instead of Single-File Download?

Workflow is a modular tool that includes:

- `workflow.sh` - Main script
- `lib/` - Library modules (core, config, help, task, utils, api)
- `tests/` - Test suite

All components are needed for the tool to function properly.

## Environment Setup

### Required: API Key Configuration

You have two options for configuring your API key:

#### Option 1: Environment Variable

Set the API key as an environment variable:

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

To make it permanent, add to your shell configuration file (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.bashrc
```

#### Option 2: Global Configuration File (Recommended)

On first use, Workflow automatically creates `~/.config/workflow/config` where you can store your API key:

```bash
# Run any workflow command to trigger auto-creation
workflow help

# Edit the global config
nano ~/.config/workflow/config
```

Add your API key to the config file:

```bash
ANTHROPIC_API_KEY=sk-ant-...
```

!!! note "Environment Variables Take Precedence"
    If you set the API key in both places, the environment variable will take precedence over the config file.

### Optional: Custom System Prompts

By default, Workflow creates a base system prompt at `~/.config/workflow/prompts/base.txt`. If you want to use a custom prompt directory:

```bash
export WORKFLOW_PROMPT_PREFIX="$HOME/custom/prompts"
```

You can also set this in the global config file:

```bash
WORKFLOW_PROMPT_PREFIX=$HOME/custom/prompts
```

### Optional: Task Prefix Directory

If you plan to use named tasks (see [Execution Guide](../user-guide/execution.md#task-mode-task)), set a directory for task templates:

```bash
export WORKFLOW_TASK_PREFIX="$HOME/.config/workflow/tasks"
```

Or in the global config:

```bash
WORKFLOW_TASK_PREFIX=$HOME/.config/workflow/tasks
```

## First-Run Auto-Configuration

The first time you run any `workflow` command, it will automatically:

1. Create `~/.config/workflow/` directory
2. Create a default `config` file with sensible defaults
3. Create `prompts/` subdirectory
4. Create a default `prompts/base.txt` system prompt

This means you can start using Workflow immediately after setting your API key!

## Verification

Verify your installation is working:

```bash
# Check help works
workflow help

# Verify global config was created
ls ~/.config/workflow/

# Check API key is configured
workflow config  # Run from any directory
```

You should see your global configuration values displayed.

## Next Steps

Now that Workflow is installed, you're ready to:

1. Follow the [Quick Start Guide](quickstart.md) for a 5-minute introduction
2. Create your [First Workflow](first-workflow.md) with detailed walkthrough
3. Explore the [User Guide](../user-guide/initialization.md) for comprehensive usage

## Troubleshooting

### Command Not Found

If you get `workflow: command not found`, ensure:

- The script is executable: `chmod +x ~/bin/workflow`
- `~/bin` is in your PATH: `echo $PATH`
- You've reloaded your shell: `source ~/.bashrc`

### jq Not Found

Install `jq` using your package manager:

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq

# CentOS/RHEL
sudo yum install jq
```

### API Key Issues

If you get API authentication errors:

- Verify your key is set: `echo $ANTHROPIC_API_KEY`
- Check the global config: `cat ~/.config/workflow/config`
- Ensure the key starts with `sk-ant-`
- Verify the key is active in the Anthropic Console

For more troubleshooting, see the [Troubleshooting Guide](../troubleshooting.md).
