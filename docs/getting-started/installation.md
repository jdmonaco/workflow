# Installation

This guide will walk you through installing and setting up the WireFlow CLI tool.

## Prerequisites

Before installing WireFlow, ensure you have the following:

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

## Optional Dependencies

WireFlow supports various document types with optional dependencies:

### PDF Documents

**Built-in support:** PDF files are automatically processed using the Claude API, which jointly analyzes both the text content and visual elements (diagrams, charts, images) from each page of the PDF. No additional dependencies required.

### Microsoft Office Files (.docx, .pptx)

**Requires LibreOffice:** Office files are automatically converted to PDF for processing. This requires the `soffice` command-line tool from LibreOffice.

#### Installing LibreOffice

**macOS:**
```bash
brew install --cask libreoffice
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install libreoffice
```

**Linux (Fedora/RHEL):**
```bash
sudo dnf install libreoffice
```

**Or download directly:** [https://www.libreoffice.org/download/download-libreoffice/](https://www.libreoffice.org/download/download-libreoffice/)

#### Setting Up soffice Symlink

After installing LibreOffice, you need to create a symlink to the `soffice` command so it's available on your PATH:

**macOS:**
```bash
# Create symlink in user bin directory
ln -s /Applications/LibreOffice.app/Contents/MacOS/soffice ~/.local/bin/soffice

# Or if LibreOffice is in ~/Applications
ln -s ~/Applications/LibreOffice.app/Contents/MacOS/soffice ~/.local/bin/soffice

# Verify it works
soffice --version
```

**Linux:**

On most Linux distributions, the `soffice` command is automatically added to PATH during installation. Verify with:

```bash
soffice --version
```

If not found, create a symlink:

```bash
ln -s /usr/bin/soffice ~/.local/bin/soffice
```

!!! note "Graceful Degradation"
    If LibreOffice is not installed, WireFlow will skip Office files with a warning message and continue processing other documents. The tool will work fine without it if you only use PDF, text, and image files.

### Image Files (.jpg, .png, .gif, .webp)

**Built-in support:** Images are automatically processed using the Claude Vision API. No additional dependencies required, though ImageMagick is recommended for optimal image resizing:

**macOS:**
```bash
brew install imagemagick
```

**Linux:**
```bash
sudo apt-get install imagemagick  # Ubuntu/Debian
sudo dnf install imagemagick      # Fedora/RHEL
```

## Installation Methods

### Method 1: Clone Repository (Recommended)

Clone the repository and add to your PATH:

```bash
# Clone the repository
git clone https://github.com/jdmonaco/wireflow.git
cd wireflow

# Create symlink to add to PATH
# Option A: User-local installation (~/.local/bin)
ln -s "$(pwd)/wireflow.sh" ~/.local/bin/wfw

# Option B: User bin directory (~/bin)
ln -s "$(pwd)/wireflow.sh" ~/bin/wfw

# Verify installation
wfw help
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
git clone https://github.com/jdmonaco/wireflow.git
cd wireflow

# Create symlink in system directory
sudo ln -s "$(pwd)/wireflow.sh" /usr/local/bin/wfw
```

### Why Clone Instead of Single-File Download?

WireFlow is a modular tool that includes:

- `wireflow.sh` - Main script
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

On first use, WireFlow automatically creates `~/.config/wireflow/config` where you can store your API key:

```bash
# Run any wireflow command to trigger auto-creation
wfw help

# Edit the global config
nano ~/.config/wireflow/config
```

Add your API key to the config file:

```bash
ANTHROPIC_API_KEY=sk-ant-...
```

!!! note "Environment Variables Take Precedence"
    If you set the API key in both places, the environment variable will take precedence over the config file.

### Optional: Custom System Prompts

By default, WireFlow creates a base system prompt at `~/.config/wireflow/prompts/base.txt`. If you want to use a custom prompt directory:

```bash
export WIREFLOW_PROMPT_PREFIX="$HOME/custom/prompts"
```

You can also set this in the global config file:

```bash
WIREFLOW_PROMPT_PREFIX=$HOME/custom/prompts
```

### Optional: Task Prefix Directory

If you plan to use named tasks (see [Execution Guide](../user-guide/execution.md#task-mode-task)), set a directory for task templates:

```bash
export WIREFLOW_TASK_PREFIX="$HOME/.config/wireflow/tasks"
```

Or in the global config:

```bash
WIREFLOW_TASK_PREFIX=$HOME/.config/wireflow/tasks
```

## First-Run Auto-Configuration

The first time you run any `wireflow` command, it will automatically:

1. Create `~/.config/wireflow/` directory
2. Create a default `config` file with sensible defaults
3. Create `prompts/` subdirectory
4. Create a default `prompts/base.txt` system prompt

This means you can start using WireFlow immediately after setting your API key!

## Verification

Verify your installation is working:

```bash
# Check help works
wfw help

# Verify global config was created
ls ~/.config/wireflow/

# Check API key is configured
wfw config  # Run from any directory
```

You should see your global configuration values displayed.

## Next Steps

Now that WireFlow is installed, you're ready to:

1. Follow the [Quick Start Guide](quickstart.md) for a 5-minute introduction
2. Create your [First Workflow](first-workflow.md) with detailed walkthrough
3. Explore the [User Guide](../user-guide/initialization.md) for comprehensive usage

## Troubleshooting

### Command Not Found

If you get `wfw: command not found`, ensure:

- The script is executable: `chmod +x ~/bin/wfw`
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
- Check the global config: `cat ~/.config/wireflow/config`
- Ensure the key starts with `sk-ant-`
- Verify the key is active in the Anthropic Console

For more troubleshooting, see the [Troubleshooting Guide](../troubleshooting.md).
