#!/usr/bin/env bash

# =============================================================================
# Workflow Help System
# =============================================================================
# Help text and usage documentation for workflow CLI tool.
# Provides main help and subcommand-specific help functions.
# This file is sourced by workflow.sh.
# =============================================================================

# =============================================================================
# Main Help
# =============================================================================

show_help() {
    cat <<EOF
Usage: workflow <subcommand> [options]

Workflow - AI-Assisted Research and Project Development Tool

Available subcommands:
    init [dir]       Initialize workflow project
    new NAME         Create new workflow
    edit [NAME]      Edit workflow or project files
    list, ls         List workflows in project
    config [NAME]    View/edit configuration
    run NAME         Execute workflow with full context
    task NAME|TEXT   Execute one-off task (lightweight)

Use 'workflow help <subcommand>' for detailed help on a specific command.
Use 'workflow <subcommand> -h' for quick help.

Common options:
    -h, --help       Show help message

Examples:
    workflow init .
    workflow new 01-analysis
    workflow run 01-analysis --stream
    workflow task -i "Summarize findings" --context-file data.md

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
usage: workflow init [<directory>]

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

    Opens project.txt and config in \$EDITOR for editing.

    If initializing inside an existing workflow project, detects parent
    and offers config inheritance.

Global config inheritance:
    New projects inherit defaults from ~/.config/workflow/config:
        - MODEL, TEMPERATURE, MAX_TOKENS
        - SYSTEM_PROMPTS, OUTPUT_FORMAT

Parent project inheritance:
    Nested projects can inherit from parent .workflow/config instead.

Examples:
    workflow init .
    workflow init my-project

See also:
    workflow help new
    workflow help config
EOF
}

show_help_new() {
    cat <<EOF
usage: workflow new <name>

Create a new workflow in the current project.

Arguments:
    <name>                Workflow name (required)

Options:
    -h, --help            Show this help

Description:
    Creates .workflow/<name>/ directory with:
        - task.txt        Task description (opens in \$EDITOR)
        - config          Workflow configuration (opens in \$EDITOR)

    Workflow config supports:
        - CONTEXT_PATTERN    Glob pattern for context files
        - CONTEXT_FILES      Explicit file list
        - DEPENDS_ON         Workflow dependencies
        - API overrides      MODEL, TEMPERATURE, etc.

Requirements:
    Must be run within an initialized workflow project.
    Use 'workflow init' first if needed.

Examples:
    workflow new 01-outline
    workflow new analyze-data
    workflow new final-report

See also:
    workflow help init
    workflow help edit
    workflow help run
EOF
}

show_help_edit() {
    cat <<EOF
usage: workflow edit [<name>]

Edit workflow or project files in \$EDITOR.

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
    workflow edit                    # Edit project files
    workflow edit 01-outline         # Edit workflow files

See also:
    workflow help config
EOF
}

show_help_list() {
    cat <<EOF
usage: workflow list
   or: workflow ls

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
    workflow list
    workflow ls

See also:
    workflow help new
    workflow help run
EOF
}

show_help_config() {
    cat <<EOF
usage: workflow config [<name>] [options]

Display configuration with source tracking and option to edit.

Arguments:
    <name>                Workflow name (optional)

Options:
    --no-edit             Skip interactive edit prompt
    -h, --help            Show this help

Behavior:
    Without <name>:
        - Shows project configuration
        - Lists all workflows
        - Source tracking: (global), (project)

    With <name>:
        - Shows workflow configuration
        - Full cascade: global → project → workflow
        - Shows context sources (CONTEXT_PATTERN, etc.)

Configuration cascade:
    1. Global:   ~/.config/workflow/config
    2. Project:  .workflow/config
    3. Workflow: .workflow/<name>/config
    4. CLI flags (highest priority)

Source indicators:
    (global)   - From ~/.config/workflow/config
    (project)  - From .workflow/config
    (workflow) - From .workflow/<name>/config

Examples:
    workflow config                  # Show project config
    workflow config 01-analysis      # Show workflow config
    workflow config --no-edit        # Skip edit prompt

See also:
    workflow help run
    workflow help task
EOF
}

show_help_run() {
    cat <<EOF
usage: workflow run <name> [options]

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
    workflow run 01-analysis
    workflow run 01-analysis --stream
    workflow run 02-report --depends-on 01-analysis
    workflow run draft --context-file notes.md --max-tokens 8192

See also:
    workflow help config
    workflow help task
EOF
}

show_help_task() {
    cat <<EOF
usage: workflow task <name> [options]
   or: workflow task --inline <text> [options]
   or: workflow task -i <text> [options]

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
    workflow task summarize --context-file notes.md

    # Inline task
    workflow task -i "Extract action items" --context-file meeting.md

    # Save output to file
    workflow task -i "Analyze data" --context-pattern "data/*.csv" --output-file analysis.md

    # Override model
    workflow task summarize --model claude-opus-4 --context-file report.md

Key differences from 'workflow run':
    - No workflow directory required
    - Streams by default (vs batch)
    - No dependencies or workflow config
    - CLI context only
    - Optional output file

See also:
    workflow help run
    workflow help config
EOF
}
