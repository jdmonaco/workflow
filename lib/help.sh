#!/usr/bin/env bash

# =============================================================================
# Workflow Help System
# =============================================================================
# Help text and usage documentation for workflow CLI tool.
# Provides main help and subcommand-specific help functions.
# This file is sourced by workflow.sh.
# =============================================================================

SCRIPT_NAME="$(basename ${0})"

# =============================================================================
# Main Help
# =============================================================================

show_help() {
    cat <<EOF
Usage: $SCRIPT_NAME <subcommand> [options]

Workflow - A CLI tool for building AI workflows anywhere

Available subcommands:
    init [dir]       Initialize workflow project
    new NAME         Create new workflow
    edit [NAME]      Edit workflow or project files
    cat NAME         Display workflow output
    open NAME        Open workflow output in default app (macOS)
    list, ls         List workflows in project
    config [NAME]    View/edit configuration
    run NAME         Execute workflow with full context
    task NAME|TEXT   Execute one-off task (lightweight)

Use '$SCRIPT_NAME help <subcommand>' for detailed help on a specific command.
Use '$SCRIPT_NAME <subcommand> -h' for quick help.

Common options:
    -h, --help       Show help message

Examples:
    $SCRIPT_NAME init .
    $SCRIPT_NAME new 01-analysis
    $SCRIPT_NAME run 01-analysis --stream
    $SCRIPT_NAME task -i "Summarize findings" --context-file data.md

Environment variables:
    ANTHROPIC_API_KEY         Your Anthropic API key (required)
    WORKFLOW_PROMPT_PREFIX    System prompt directory (default: ~/.config/workflow/prompts)
    WORKFLOW_TASK_PREFIX      Named task directory (optional, for 'task' subcommand)

Configuration:
    Global config:   ~/.config/workflow/config
    Project config:  .workflow/config
    Workflow config: .workflow/<NAME>/config

For more information, see README.md or visit the documentation.
EOF
}

# =============================================================================
# Subcommand Help Functions
# =============================================================================

show_help_init() {
    cat <<EOF
Usage: $SCRIPT_NAME init [<directory>]

Initialize a workflow project with .workflow/ structure.

Arguments:
    <directory>           Directory to initialize (default: current directory)

Options:
    -h, --help            Show this help

Description:
    Creates .workflow/ directory structure with:
        - config              Project-level configuration
        - project.txt         Project description (optional)
        - prompts/            System prompt cache
        - output/             Hardlinks to workflow outputs

    Opens project.txt and config for interactive editing.

    If initializing inside an existing workflow project, detects parent
    and offers config inheritance.

Global config inheritance:
    New projects inherit defaults from ~/.config/workflow/config:
        - MODEL, TEMPERATURE, MAX_TOKENS
        - SYSTEM_PROMPTS, OUTPUT_FORMAT

Parent project inheritance:
    Nested projects can inherit from parent .workflow/config instead.

Examples:
    $SCRIPT_NAME init .
    $SCRIPT_NAME init my-project

See also:
    $SCRIPT_NAME help new
    $SCRIPT_NAME help config
EOF
}

show_help_new() {
    cat <<EOF
Usage: $SCRIPT_NAME new <name>

Create a new workflow in the current project.

Arguments:
    <name>                Workflow name (required)

Options:
    -h, --help            Show this help

Description:
    Creates .workflow/<name>/ directory with:
        - task.txt        Task description (opens in editor)
        - config          Workflow configuration (opens in editor)

    Workflow config supports:
        - CONTEXT_PATTERN    Glob pattern for context files
        - CONTEXT_FILES      Explicit file list
        - DEPENDS_ON         Workflow dependencies
        - API overrides      MODEL, TEMPERATURE, etc.

Requirements:
    Must be run within an initialized workflow project.
    Use 'workflow init' first if needed.

Examples:
    $SCRIPT_NAME new 01-outline
    $SCRIPT_NAME new analyze-data
    $SCRIPT_NAME new final-report

See also:
    $SCRIPT_NAME help init
    $SCRIPT_NAME help edit
    $SCRIPT_NAME help run
EOF
}

show_help_edit() {
    cat <<EOF
Usage: $SCRIPT_NAME edit [<name>]

Edit workflow or project files in interactive text editor.

Arguments:
    <name>                Workflow name (optional)

Options:
    -h, --help            Show this help

Behavior:
    Without <name>:
        Opens project-level files:
            - .workflow/project.txt
            - .workflow/config

    With <name>:
        Opens workflow-specific files:
            - .workflow/<name>/task.txt
            - .workflow/<name>/config

Requirements:
    Must be run within an initialized workflow project.

Examples:
    $SCRIPT_NAME edit                    # Edit project files
    $SCRIPT_NAME edit 01-outline         # Edit workflow files

See also:
    $SCRIPT_NAME help config
EOF
}

show_help_cat() {
    cat <<EOF
Usage: $SCRIPT_NAME cat <name>

Display workflow output to stdout.

Arguments:
    <name>                Workflow name (required)

Options:
    -h, --help            Show this help

Description:
    Outputs the workflow result file to stdout for viewing or piping
    to other commands. Useful for quick viewing or shell pipeline
    processing.

    Reads from: .workflow/output/<name>.<format>

Requirements:
    Must be run within an initialized workflow project.
    Workflow must have been run at least once (output must exist).

Examples:
    $SCRIPT_NAME cat 01-analysis
    $SCRIPT_NAME cat data-summary | grep "findings"
    $SCRIPT_NAME cat report | less
    $SCRIPT_NAME cat extract | jq .results
    $SCRIPT_NAME cat draft > published.md

See also:
    $SCRIPT_NAME help run
    $SCRIPT_NAME help list
EOF
}

show_help_open() {
    cat <<EOF
Usage: $SCRIPT_NAME open <name>

Open workflow output in default application (macOS only).

Arguments:
    <name>                Workflow name (required)

Options:
    -h, --help            Show this help

Description:
    Opens the workflow result file using the macOS 'open' command,
    which launches the default application for the file type.

    File type behavior:
    - .md files open in default Markdown editor/viewer
    - .json files open in default JSON viewer
    - .html files open in default browser
    - .txt files open in default text editor
    - Other formats open with registered application

    Reads from: .workflow/output/<name>.<format>

Requirements:
    - macOS system (uses 'open' command)
    - Initialized workflow project
    - Workflow output must exist

Examples:
    $SCRIPT_NAME open report           # Open report.md in editor
    $SCRIPT_NAME open data-viz         # Open data-viz.html in browser
    $SCRIPT_NAME open analysis         # Open analysis.json in viewer

See also:
    $SCRIPT_NAME help cat
    $SCRIPT_NAME help run
EOF
}

show_help_list() {
    cat <<EOF
Usage: $SCRIPT_NAME list
   or: $SCRIPT_NAME ls

List all workflows in the current project.

Options:
    -h, --help            Show this help

Description:
    Lists workflow directories in .workflow/, excluding special files:
        - config, prompts/, output/, project.txt

    Shows status indicators:
        [complete]   - Has task.txt and config
        [incomplete] - Missing required files

Requirements:
    Must be run within an initialized workflow project.

Examples:
    $SCRIPT_NAME list
    $SCRIPT_NAME ls

See also:
    $SCRIPT_NAME help new
    $SCRIPT_NAME help run
EOF
}

show_help_config() {
    cat <<EOF
Usage: $SCRIPT_NAME config [<name>] [options]

Display configuration with source tracking. Optionally prompt to edit files.

Arguments:
    <name>                Workflow name (optional)

Options:
    --edit                Prompt to edit configuration files
    -h, --help            Show this help

Behavior:
    Without <name>:
        - Shows project configuration
        - Lists all workflows
        - Source tracking: (global), (ancestor:path), (project)

    With <name>:
        - Shows workflow configuration
        - Full cascade: global → ancestors → project → workflow
        - Shows context sources (CONTEXT_PATTERN, etc.)

Configuration cascade:
    1. Global:      ~/.config/workflow/config
    2. Ancestors:   Parent project configs (oldest to newest)
    3. Project:     .workflow/config
    4. Workflow:    .workflow/<name>/config
    5. CLI flags:   (highest priority)

Source indicators:
    (global)              - From ~/.config/workflow/config
    (ancestor:path)       - From ancestor project config
    (project)             - From .workflow/config
    (workflow)            - From .workflow/<name>/config

Examples:
    $SCRIPT_NAME config                  # Show project config
    $SCRIPT_NAME config 01-analysis      # Show workflow config
    $SCRIPT_NAME config --edit           # Show config and prompt to edit

See also:
    $SCRIPT_NAME help run
    $SCRIPT_NAME help task
EOF
}

show_help_run() {
    cat <<EOF
Usage: $SCRIPT_NAME run <name> [options]

Execute a workflow with full context aggregation and persistence.

Arguments:
    <name>                Workflow name (must exist in .workflow/)

Context Options:
    --context-file <file> Add context file (repeatable, relative to PWD)
    --context-pattern <glob>
                          Add files matching pattern (relative to PWD)
    --depends-on <workflow>
                          Include output from another workflow

API Options:
    --model <model>       Override model (default: from config)
    --temperature <temp>  Override temperature (0.0-1.0)
    --max-tokens <num>    Override max tokens
    --system-prompts <list>
                          Comma-separated prompt names (e.g., "base,NeuroAI")
    --output-format <ext> Output format: md, txt, json, html, etc.

Execution Options:
    --stream              Stream output in real-time
    --dry-run             Estimate tokens without API call
    -h, --help            Show this help

Description:
    Executes workflow by:
        1. Finding project root
        2. Loading config (global → project → workflow → CLI)
        3. Building context from configured sources
        4. Making API request
        5. Saving output with hardlink in .workflow/output/

    Context sources (in order):
        1. DEPENDS_ON workflows
        2. CONTEXT_PATTERN (from config, relative to project root)
        3. CLI --context-pattern (relative to PWD)
        4. CONTEXT_FILES (from config)
        5. CLI --context-file (relative to PWD)

    Output:
        Saved to:  .workflow/<name>/output.<format>
        Linked to: .workflow/output/<name>.<format>
        Previous outputs backed up with timestamps

Examples:
    $SCRIPT_NAME run 01-analysis
    $SCRIPT_NAME run 01-analysis --stream
    $SCRIPT_NAME run 02-report --depends-on 01-analysis
    $SCRIPT_NAME run draft --context-file notes.md --max-tokens 8192

See also:
    $SCRIPT_NAME help config
    $SCRIPT_NAME help task
EOF
}

show_help_task() {
    cat <<EOF
Usage: $SCRIPT_NAME task <name> [options]
   or: $SCRIPT_NAME task --inline <text> [options]
   or: $SCRIPT_NAME task -i <text> [options]

Execute a one-off task without creating workflow directories.

Arguments:
    <name>                Named task from \$WORKFLOW_TASK_PREFIX/<name>.txt

Task Specification (mutually exclusive):
    -i, --inline <text>   Inline task specification

Context Options:
    --context-file <file> Add context file (repeatable, relative to PWD)
    --context-pattern <glob>
                          Add files matching pattern (relative to PWD)

API Options:
    --model <model>       Override model
    --temperature <temp>  Override temperature (0.0-1.0)
    --max-tokens <num>    Override max tokens
    --system-prompts <list>
                          Comma-separated prompt names
    --output-format <ext> Output format: md, txt, json, html, etc.

Output Options:
    --output-file <path>  Save to file (default: stream to stdout)
    --stream              Stream output (default: true)
    --no-stream           Use single-batch mode

Other Options:
    --dry-run             Estimate tokens without API call
    -h, --help            Show this help

Description:
    Lightweight mode for one-off tasks. Does not create workflow
    directories. Streams to stdout by default.

    Uses project context if run from within a project:
        - Project config (.workflow/config)
        - Project description (.workflow/project.txt)

    Otherwise runs in standalone mode with global config only.

Environment:
    WORKFLOW_TASK_PREFIX  Directory containing named task files
                          (only needed for named tasks, not --inline)

Examples:
    # Named task with context
    $SCRIPT_NAME task summarize --context-file notes.md

    # Inline task
    $SCRIPT_NAME task -i "Extract action items" --context-file meeting.md

    # Save output to file
    $SCRIPT_NAME task -i "Analyze data" --context-pattern "data/*.csv" --output-file analysis.md

    # Override model
    $SCRIPT_NAME task summarize --model claude-opus-4 --context-file report.md

Key differences from '$SCRIPT_NAME run':
    - No workflow directory required
    - Streams by default (vs batch)
    - No dependencies or workflow config
    - CLI context only
    - Optional output file

See also:
    $SCRIPT_NAME help run
    $SCRIPT_NAME help config
EOF
}
