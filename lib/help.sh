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
WireFlow - Reproducible AI workflows from the command line
Usage: $SCRIPT_NAME <subcommand> [options]

Subcommands:
    init [dir]       Initialize wireflow project
    new NAME         Add a named workflow
    edit [NAME]      Open files in editor
    config [NAME]    Show effective config
    run NAME         Execute workflow
    task NAME|TEXT   Quick one-off query
    batch NAME       Submit batch processing job
    cat NAME         Print output to stdout
    open NAME        Open output in app (macOS)
    tasks            Manage task templates
    list             Show project workflows
    help [CMD]       Show help

Use '$SCRIPT_NAME help <subcommand>' for detailed help on a specific command.
Use '$SCRIPT_NAME <subcommand> -h' for quick help.

Common options:
    -h, --help       Show help message
    -v, --version    Show version information

Examples:
    $SCRIPT_NAME init .
    $SCRIPT_NAME new 01-analysis
    $SCRIPT_NAME run 01-analysis --stream
    $SCRIPT_NAME task -i "Summarize findings" -cx data.md
    $SCRIPT_NAME batch my-workflow -in data/

Environment variables:
    ANTHROPIC_API_KEY         Your Anthropic API key (required)
    WIREFLOW_PROMPT_PREFIX    System prompt directory ($(display_absolute_path "$WIREFLOW_PROMPT_PREFIX"))
    WIREFLOW_TASK_PREFIX      Named task directory ($(display_absolute_path "$WIREFLOW_TASK_PREFIX"))

Configuration:
    Global config:   $(display_absolute_path "$GLOBAL_CONFIG_FILE")
    Project config:  <PROJECT_ROOT>/.workflow/config
    Workflow config: <PROJECT_ROOT>/.workflow/run/<NAME>/config

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
    echo "Usage: $SCRIPT_NAME run <name> [options] [-- <input>...]"
    echo "See '$SCRIPT_NAME help run' for complete usage details."
}

show_quick_help_task() {
    echo "Usage: $SCRIPT_NAME task <name>|--inline <text> [options] [-- <input>...]"
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

show_quick_help_batch() {
    cat <<EOF
Usage: $SCRIPT_NAME batch <name> [options]
       $SCRIPT_NAME batch status [<name>]
       $SCRIPT_NAME batch results <name>
       $SCRIPT_NAME batch cancel <name>
See '$SCRIPT_NAME help batch' for complete usage details.
EOF
}

# =============================================================================
# Subcommand Help Functions (for 'wireflow help <cmd>')
# =============================================================================

show_help_init() {
    cat <<EOF
Usage: $SCRIPT_NAME init [<directory>]

Initialize a wireflow project. Run once per project root.

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

Add a named workflow. Creates config and task files you can customize.

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

Open workflow or project files in your editor. Fast access to config and tasks.

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

Show effective config. See where each value comes from in the cascade.

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
Usage: $SCRIPT_NAME run <name> [options] [-- <input>...]

Execute a workflow. Aggregates context, calls API, saves output.

Arguments:
    <name>                        Workflow name (required)
    -- <input>...                 Input files/directories (after --)

Input Options (primary documents):
    --input, -in <path>...        Add input files/directories (multiple allowed)

Context Options (background and references):
    --context, -cx <path>...      Add context files/directories (multiple allowed)
    --depends-on, -dp <name>...   Include outputs from other workflows

Model Options:
    --profile <tier>              Model tier: fast, balanced, deep
    --model, -m <model>           Explicit model override (bypasses profile)

Thinking & Effort Options:
    --enable-thinking             Enable extended thinking mode
    --disable-thinking            Disable extended thinking (default)
    --thinking-budget <num>       Token budget for thinking (min 1024)
    --effort <level>              Effort level: low, medium, high (Opus 4.5 only)

API Options:
    --temperature, -t <temp>      Override temperature (0.0-1.0)
    --max-tokens <num>            Override max tokens
    --system, -p <list>           Comma-separated prompt names
    --format, -f <ext>            Output format (md, txt, json, etc.)
    --enable-citations            Enable Anthropic citations support
    --disable-citations           Disable citations (default)

Output Options:
    --export, -ex <path>          Copy output to external path

Execution Options:
    --stream, -s                  Stream output in real-time (default)
    --count-tokens                Show token estimation only
    --dry-run, -n                 Save request JSON, open in editor
    --no-auto-deps                Skip automatic execution of stale dependencies
    --force                       Force re-execution, ignoring cache
    --help, -h                    Quick help

Notes:
    Directory paths are expanded non-recursively; all supported files in the
    directory are included. Duplicate paths are ignored; inputs take precedence
    over context if the same path appears in both.

    For batch processing (multiple input files as separate API requests),
    use '$SCRIPT_NAME batch <name>' instead.

Examples:
    $SCRIPT_NAME run 01-analysis --stream
    $SCRIPT_NAME run 01-analysis --profile deep --enable-thinking
    $SCRIPT_NAME run 01-analysis --model claude-opus-4-5 --effort medium
    $SCRIPT_NAME run 01-analysis --count-tokens
    $SCRIPT_NAME run 01-analysis -ex ~/output/analysis.md
    $SCRIPT_NAME run 01-analysis -- reports/*.pdf
EOF
}

show_help_task() {
    cat <<EOF
Usage: $SCRIPT_NAME task <name> | --inline <text> [options] [-- <input>...]

Quick one-off query. No workflow directory needed.

Task Specification:
    <name>                        Named task from \$WIREFLOW_TASK_PREFIX/<name>.txt
    --inline, -i <text>           Inline task specification
    -- <input>...                 Input files/directories (after --)

Input Options (primary documents to analyze):
    --input, -in <path>...        Add input files/directories (multiple allowed)

Context Options (supporting materials and references):
    --context, -cx <path>...      Add context files/directories (multiple allowed)

Model Options:
    --profile <tier>              Model tier: fast, balanced, deep
    --model, -m <model>           Explicit model override (bypasses profile)

Thinking & Effort Options:
    --enable-thinking             Enable extended thinking mode
    --disable-thinking            Disable extended thinking (default)
    --thinking-budget <num>       Token budget for thinking (min 1024)
    --effort <level>              Effort level: low, medium, high (Opus 4.5 only)

API Options:
    --temperature, -t <temp>      Override temperature
    --max-tokens <num>            Override max tokens
    --system, -p <list>           Comma-separated prompt names
    --format, -f <ext>            Output format
    --enable-citations            Enable Anthropic citations support
    --disable-citations           Disable citations (default)

Output Options:
    --export, -ex <path>          Save to file (default: stdout)
    --stream                      Stream output (default)
    --no-stream                   Buffered mode (wait for complete response)

Other Options:
    --count-tokens                Show token estimation only
    --dry-run, -n                 Save request JSON, open in editor
    --help, -h                    Quick help

Notes:
    Directory paths are expanded non-recursively; all supported files in the
    directory are included. Duplicate paths are ignored; inputs take precedence
    over context if the same path appears in both.

Examples:
    $SCRIPT_NAME task summarize -cx paper.pdf
    $SCRIPT_NAME task -i "Summarize these notes" --profile fast
    $SCRIPT_NAME task analyze -in data/*.csv --enable-thinking
    $SCRIPT_NAME task summarize -ex summary.md -cx report.pdf

See Also:
    $SCRIPT_NAME tasks              # List available task templates
    $SCRIPT_NAME tasks show <name>  # Preview template
EOF
}

show_help_tasks() {
    cat <<EOF
Usage: $SCRIPT_NAME tasks [show|edit <name>]

List, view, or edit reusable task templates.

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

Print workflow output. Pipe it, grep it, use it.

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

Open output in your default app. macOS only.

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

Show all workflows in this project.

Options:
    -h, --help     Quick help

Example:
    $SCRIPT_NAME list
EOF
}

show_help_batch() {
    cat <<EOF
Usage: $SCRIPT_NAME batch <name> [options] [-- <input>...]
       $SCRIPT_NAME batch status [<name>]
       $SCRIPT_NAME batch results <name>
       $SCRIPT_NAME batch cancel <name>

Submit and manage batch processing jobs via the Anthropic Message Batches API.
Batch mode provides 50% cost reduction by processing multiple requests asynchronously.

Subcommands:
    <name>                        Submit batch job (default action)
    status [<name>]               Show batch status (all or specific workflow)
    results <name>                Retrieve completed batch results
    cancel <name>                 Cancel a pending batch

Arguments:
    <name>                        Workflow name
    -- <input>...                 Input files/directories (after --)

Input Options (one request per file):
    --input, -in <path>...        Add input files/directories (multiple allowed)

Context Options (shared across all requests):
    --context, -cx <path>...      Add context files/directories (multiple allowed)
    --depends-on, -dp <name>...   Include outputs from other workflows

Model Options:
    --profile <tier>              Model tier: fast, balanced, deep
    --model, -m <model>           Explicit model override (bypasses profile)

Thinking & Effort Options:
    --enable-thinking             Enable extended thinking mode
    --disable-thinking            Disable extended thinking (default)
    --thinking-budget <num>       Token budget for thinking (min 1024)
    --effort <level>              Effort level: low, medium, high (Opus 4.5 only)

API Options:
    --temperature, -t <temp>      Override temperature (0.0-1.0)
    --max-tokens <num>            Override max tokens
    --system, -p <list>           Comma-separated prompt names
    --format, -f <ext>            Output format (md, txt, json, etc.)
    --enable-citations            Enable Anthropic citations support
    --disable-citations           Disable citations (default)

Output Options:
    --export, -ex <dir>           Copy results to external directory

Other Options:
    --count-tokens                Show token estimation only
    --dry-run, -n                 Save request JSON, open in editor
    --help, -h                    Quick help

Notes:
    Each input file becomes a separate API request in the batch.
    Context files are shared across all requests (included once per request).
    Results are written to .workflow/output/<name>/ directory.

Examples:
    # Submit batch job
    $SCRIPT_NAME batch my-analysis -in data/*.pdf

    # Submit with export directory
    $SCRIPT_NAME batch my-analysis -in reports/ -ex ~/processed/

    # Check status
    $SCRIPT_NAME batch status my-analysis

    # Get results when complete
    $SCRIPT_NAME batch results my-analysis

    # Cancel pending batch
    $SCRIPT_NAME batch cancel my-analysis

See Also:
    $SCRIPT_NAME run <name>     # Single-request execution (non-batch)
EOF
}
