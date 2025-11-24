#!/usr/bin/env bash

# =============================================================================
# Workflow Help System
# =============================================================================
# Help text and usage documentation for workflow CLI tool.
# Provides main help and subcommand-specific help functions.
# =============================================================================

# =============================================================================
# Main Help
# =============================================================================

show_help() {
    cat <<EOF
WireFlow - A tool for building flexible AI workflows anywhere
Usage: $SCRIPT_NAME <subcommand> [options]

Available subcommands:
    init [dir]       Initialize workflow project
    new NAME         Create new workflow
    edit [NAME]      Edit workflow or project files
    config [NAME]    View/edit configuration
    run NAME         Execute workflow with full context
    task NAME|TEXT   Execute one-off task (lightweight)
    cat NAME         Pipe workflow output to your shell
    open NAME        Open workflow output file in default app (macOS)
    tasks            Show available task templates
    list             List workflows in project
    help [CMD]       Show help for subcommand

Use '$SCRIPT_NAME help <subcommand>' for detailed help on a specific command.
Use '$SCRIPT_NAME <subcommand> -h' for quick help.

Common options:
    -h, --help       Show help message
    -v, --version    Show version information

Examples:
    $SCRIPT_NAME init .
    $SCRIPT_NAME new 01-analysis
    $SCRIPT_NAME run 01-analysis --stream
    $SCRIPT_NAME task -i "Summarize findings" --context-file data.md

Environment variables:
    ANTHROPIC_API_KEY         Your Anthropic API key (required)
    WIREFLOW_PROMPT_PREFIX    System prompt directory ($(display_absolute_path "$WIREFLOW_PROMPT_PREFIX"))
    WIREFLOW_TASK_PREFIX      Named task directory ($(display_absolute_path "$WIREFLOW_TASK_PREFIX"))

Configuration:
    Global config:   $(display_absolute_path "$GLOBAL_CONFIG_FILE")
    Project config:  <PROJECT_ROOT>/.workflow/config
    Workflow config: <PROJECT_ROOT>/.workflow/<NAME>/config

For more information, see README.md or visit the documentation.
EOF
}

# =============================================================================
# Quick Help Functions (for -h flag)
# =============================================================================

show_quick_help_init() {
    echo "Usage: $SCRIPT_NAME init [<directory>]"
    echo "See '$SCRIPT_NAME help init' for complete usage details."
}

show_quick_help_new() {
    echo "Usage: $SCRIPT_NAME new NAME [--task TEMPLATE]"
    echo "See '$SCRIPT_NAME help new' for complete usage details."
}

show_quick_help_edit() {
    echo "Usage: $SCRIPT_NAME edit [<name>]"
    echo "See '$SCRIPT_NAME help edit' for complete usage details."
}

show_quick_help_config() {
    echo "Usage: $SCRIPT_NAME config [<name>] [--edit]"
    echo "See '$SCRIPT_NAME help config' for complete usage details."
}

show_quick_help_run() {
    echo "Usage: $SCRIPT_NAME run <name> [options]"
    echo "See '$SCRIPT_NAME help run' for complete usage details."
}

show_quick_help_task() {
    echo "Usage: $SCRIPT_NAME task <name>|--inline <text> [options]"
    echo "See '$SCRIPT_NAME help task' for complete usage details."
}

show_quick_help_tasks() {
    echo "Usage: $SCRIPT_NAME tasks [show|edit <name>]"
    echo "See '$SCRIPT_NAME help tasks' for complete usage details."
}

show_quick_help_cat() {
    echo "Usage: $SCRIPT_NAME cat <name>"
    echo "See '$SCRIPT_NAME help cat' for complete usage details."
}

show_quick_help_open() {
    echo "Usage: $SCRIPT_NAME open <name>"
    echo "See '$SCRIPT_NAME help open' for complete usage details."
}

show_quick_help_list() {
    echo "Usage: $SCRIPT_NAME list"
    echo "See '$SCRIPT_NAME help list' for complete usage details."
}

# =============================================================================
# Subcommand Help Functions (for 'wireflow help <cmd>')
# =============================================================================

show_help_init() {
    cat <<EOF
Usage: $SCRIPT_NAME init [<directory>]

Initialize a WireFlow project with .workflow/ structure.

Arguments:
    <directory>    Directory to initialize (default: current directory)

Options:
    -h, --help     Quick help

Examples:
    $SCRIPT_NAME init .
    $SCRIPT_NAME init my-project
EOF
}

show_help_new() {
    cat <<EOF
Usage: $SCRIPT_NAME new <name> [options]

Create a new workflow in the current project.

Arguments:
    <name>        Workflow name (required)

Options:
    --from-task <template>  Use named task file as a template
    -h, --help              Quick help

Examples:
    $SCRIPT_NAME new 01-outline
    $SCRIPT_NAME new data-analysis --from-task analyze

See Also:
    $SCRIPT_NAME tasks   # List all task templates
EOF
}

show_help_edit() {
    cat <<EOF
Usage: $SCRIPT_NAME edit [<name>]

Edit workflow or project files in text editor.

Arguments:
    <name>         Workflow name (optional)

Options:
    -h, --help     Quick help

Behavior:
    Without <name>: Opens project files (project.txt, config)
    With <name>:    Opens workflow files (output, task.txt, config)

Examples:
    $SCRIPT_NAME edit
    $SCRIPT_NAME edit 01-outline
EOF
}

show_help_config() {
    cat <<EOF
Usage: $SCRIPT_NAME config [<name>] [options]

Display configuration with source tracking.

Arguments:
    <name>         Workflow name (optional)

Options:
    --edit         Prompt to edit configuration files
    -h, --help     Quick help

Examples:
    $SCRIPT_NAME config
    $SCRIPT_NAME config 01-analysis
EOF
}

show_help_run() {
    cat <<EOF
Usage: $SCRIPT_NAME run <name> [options]

Execute a workflow with full context aggregation.

Arguments:
    <name>                      Workflow name (required)

Input Options (primary documents):
    --input-file|-in <file>     Add input document (repeatable)
    --input-pattern <glob>      Add input files matching pattern

Context Options (background and references):
    --context-file|-cx <file>   Add context file (repeatable)
    --context-pattern <glob>    Add context files matching pattern
    --depends-on|-d <workflow>  Include output from another workflow

API Options:
    --model|-m <model>           Override model
    --temperature|-t <temp>      Override temperature (0.0-1.0)
    --max-tokens <num>           Override max tokens
    --system|-p <list>           Comma-separated prompt names
    --format|-f <ext>            Output format (md, txt, json, etc.)
    --enable-citations           Enable Anthropic citations support
    --disable-citations          Disable citations (default)

Output Options:
    --output-file|-o <path>      Copy output to additional path

Execution Options:
    --stream|-s                  Stream output in real-time (default: true)
    --count-tokens               Show token estimation only
    --dry-run|-n                 Save API request files and inspect in editor
    --help|-h                    Quick help

Examples:
    $SCRIPT_NAME run 01-analysis --stream
    $SCRIPT_NAME run 01-analysis --count-tokens
    $SCRIPT_NAME run 01-analysis --dry-run --count-tokens
EOF
}

show_help_task() {
    cat <<EOF
Usage: $SCRIPT_NAME task <name>|--inline <text> [options]

Execute a one-off task outside of existing workflows.

Task Specification:
    <name>                    Named task from \$WIREFLOW_TASK_PREFIX/<name>.txt
    -i, --inline <text>       Inline task specification

Input Options (primary documents to analyze):
    --input-file|-in <file>   Add input document (repeatable)
    --input-pattern <glob>    Add input files matching pattern

Context Options (supporting materials and references):
    --context-file|-cx <file> Add context file (repeatable)
    --context-pattern <glob>  Add context files matching pattern

API Options:
    --model|-m <model>        Override model
    --temperature|-t <temp>   Override temperature
    --max-tokens <num>        Override max tokens
    --system|-p <list>        Comma-separated prompt names
    --output-format|-f <ext>  Output format
    --enable-citations        Enable Anthropic citations support
    --disable-citations       Disable citations (default)

Output Options:
    --output-file|-o <path>   Save to file (default: stdout)
    --stream                  Stream output (default: true)
    --no-stream               Use batch mode

Other Options:
    --count-tokens            Show token estimation only
    --dry-run|-n              Save API request files and inspect in editor
    --help|-h                 Quick help

Examples:
    $SCRIPT_NAME task summarize --context-file paper.pdf
    $SCRIPT_NAME task -i "Summarize these notes" --context-file notes.md
    $SCRIPT_NAME task analyze --input-pattern "data/*.csv" --stream

See Also:
    $SCRIPT_NAME tasks           # List available task templates
    $SCRIPT_NAME tasks show <name>  # Preview template
    $SCRIPT_NAME new <name> --task <template>  # Create workflow from template
EOF
}

show_help_tasks() {
    cat <<EOF
Usage: $SCRIPT_NAME tasks [show|edit <name>]

Manage task templates.

Commands:
    tasks              List available task templates (default)
    tasks show <name>  Display task template in pager
    tasks edit <name>  Open task template in editor

Note: Default task templates are stored in ~/.config/wireflow/prompts/tasks.

Examples:
    $SCRIPT_NAME tasks
    $SCRIPT_NAME tasks show summarize
    $SCRIPT_NAME tasks edit summarize

See Also:
    $SCRIPT_NAME task <name>  # Execute task template
    $SCRIPT_NAME new <name> --task <template>  # Create workflow from template
EOF
}

show_help_cat() {
    cat <<EOF
Usage: $SCRIPT_NAME cat <name>

Display workflow output to stdout.

Arguments:
    <name>         Workflow name (required)

Options:
    -h, --help     Quick help

Examples:
    $SCRIPT_NAME cat 01-analysis
    $SCRIPT_NAME cat report | less
EOF
}

show_help_open() {
    cat <<EOF
Usage: $SCRIPT_NAME open <name>

Open workflow output in default application (macOS only).

Arguments:
    <name>         Workflow name (required)

Options:
    -h, --help     Quick help

Examples:
    $SCRIPT_NAME open report
    $SCRIPT_NAME open data-viz
EOF
}

show_help_list() {
    cat <<EOF
Usage: $SCRIPT_NAME list

List all workflows in the current project.

Options:
    -h, --help     Quick help

Example:
    $SCRIPT_NAME list
EOF
}
