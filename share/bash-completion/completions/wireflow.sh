#!/usr/bin/env bash

# Bash completion for wireflow
# Source: https://github.com/yourusername/wireflow

_wireflow() {
    local cur prev words cword
    _init_completion || return
    
    # Main dispatch based on subcommand position
    if [[ $cword -eq 1 ]]; then
        _wireflow_subcommands
    else
        local subcommand="${words[1]}"
        case "$subcommand" in
            init)     _wireflow_init ;;
            new)      _wireflow_new ;;
            edit)     _wireflow_edit ;;
            config)   _wireflow_config ;;
            run)      _wireflow_run ;;
            task)     _wireflow_task ;;
            tasks)    _wireflow_tasks ;;
            cat)      _wireflow_cat ;;
            open)     _wireflow_open ;;
            list)     _wireflow_list ;;
            help)     _wireflow_help ;;
            *)        return 0 ;;
        esac
    fi
}

# =============================================================================
# Subcommand Completions
# =============================================================================

_wireflow_subcommands() {
    local subcommands="init new edit config run task tasks cat open list help"
    COMPREPLY=($(compgen -W "$subcommands" -- "$cur"))
}

# =============================================================================
# Helper Functions - Dynamic Listing
# =============================================================================

# Get list of workflows in current project
_wireflow_list_workflows() {
    local project_root
    project_root=$(wfw find-project-root 2>/dev/null) || return 1
    
    local run_dir="$project_root/.workflow/run"
    [[ ! -d "$run_dir" ]] && return 1
    
    # List workflow directories
    find "$run_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;
}

# Get list of available tasks
_wireflow_list_tasks() {
    local task_prefix="${WIREFLOW_TASK_PREFIX:-$HOME/.config/wireflow/tasks}"
    local builtin_prefix="$HOME/.config/wireflow/tasks"
    
    # List from custom location
    [[ -d "$task_prefix" ]] && find "$task_prefix" -name "*.txt" -exec basename {} .txt \;
    
    # List from builtin location (if different)
    if [[ -d "$builtin_prefix" && "$builtin_prefix" != "$task_prefix" ]]; then
        find "$builtin_prefix" -name "*.txt" -exec basename {} .txt \;
    fi
}

# Common API options
_wireflow_api_options() {
    echo "--model --temperature --max-tokens --system-prompts --output-format --format-hint"
    echo "--enable-citations --disable-citations"
}

# Common input/context options
_wireflow_input_options() {
    echo "--input-file --input-pattern --context-file --context-pattern"
}

# Common execution options
_wireflow_execution_options() {
    echo "--stream --no-stream --count-tokens --dry-run"
}

# =============================================================================
# Subcommand-Specific Completions
# =============================================================================

_wireflow_init() {
    case "$prev" in
        init)
            # Complete directory paths
            _filedir -d
            ;;
        *)
            # No other options
            return 0
            ;;
    esac
}

_wireflow_new() {
    case "$prev" in
        --from-task|--task)
            # Complete with task names
            COMPREPLY=($(compgen -W "$(_wireflow_list_tasks)" -- "$cur"))
            ;;
        new)
            # First arg is workflow name (no completion)
            return 0
            ;;
        *)
            # Complete options
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--from-task --task --help -h" -- "$cur"))
            fi
            ;;
    esac
}

_wireflow_edit() {
    case "$prev" in
        edit)
            # Complete with workflow names
            COMPREPLY=($(compgen -W "$(_wireflow_list_workflows)" -- "$cur"))
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
            fi
            ;;
    esac
}

_wireflow_config() {
    case "$prev" in
        config)
            # Complete with workflow names
            COMPREPLY=($(compgen -W "$(_wireflow_list_workflows)" -- "$cur"))
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--edit --help -h" -- "$cur"))
            fi
            ;;
    esac
}

_wireflow_run() {
    local workflow_specified=false
    local i
    
    # Check if workflow name has been specified
    for ((i=2; i<cword; i++)); do
        if [[ "${words[i]}" != -* ]]; then
            workflow_specified=true
            break
        fi
    done
    
    if ! $workflow_specified; then
        # First arg: complete workflow names
        COMPREPLY=($(compgen -W "$(_wireflow_list_workflows)" -- "$cur"))
        return 0
    fi
    
    # After workflow name: complete options
    case "$prev" in
        --model|-m)
            # Complete with model names
            COMPREPLY=($(compgen -W "claude-opus-4 claude-sonnet-4-5 claude-haiku-4" -- "$cur"))
            ;;
        --temperature|-t)
            # Suggest common temperature values
            COMPREPLY=($(compgen -W "0.0 0.3 0.5 0.7 1.0" -- "$cur"))
            ;;
        --max-tokens)
            # Suggest common token limits
            COMPREPLY=($(compgen -W "1024 2048 4096 8192 16384" -- "$cur"))
            ;;
        --system-prompts|--system|-p)
            # No completion (comma-separated list)
            return 0
            ;;
        --output-format|--format-hint|--format|-f)
            # Complete with format extensions
            COMPREPLY=($(compgen -W "md txt json html xml" -- "$cur"))
            ;;
        --input-file|--context-file|-in|-cx)
            # Complete with file paths
            _filedir
            ;;
        --input-pattern|--context-pattern)
            # No completion (glob pattern)
            return 0
            ;;
        --depends-on|-d)
            # Complete with workflow names
            COMPREPLY=($(compgen -W "$(_wireflow_list_workflows)" -- "$cur"))
            ;;
        --output-file|--export-file|-o)
            # Complete with file paths
            _filedir
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                # Complete with all run options
                local opts="$(_wireflow_api_options) $(_wireflow_input_options) $(_wireflow_execution_options)"
                opts="$opts --depends-on --export-file --output-file --help -h"
                opts="$opts -m -t -p -f -in -cx -d -o -s -n"
                COMPREPLY=($(compgen -W "$opts" -- "$cur"))
            fi
            ;;
    esac
}

_wireflow_task() {
    local task_specified=false
    local i
    
    # Check if task name or --inline has been specified
    for ((i=2; i<cword; i++)); do
        if [[ "${words[i]}" == "--inline" || "${words[i]}" == "-i" ]]; then
            task_specified=true
            break
        elif [[ "${words[i]}" != -* ]]; then
            task_specified=true
            break
        fi
    done
    
    if ! $task_specified; then
        # First arg: complete task names or --inline
        if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "--inline -i --help -h" -- "$cur"))
        else
            COMPREPLY=($(compgen -W "$(_wireflow_list_tasks)" -- "$cur"))
        fi
        return 0
    fi
    
    # After task name: complete options (same as run, minus --depends-on)
    case "$prev" in
        --inline|-i)
            # No completion for inline text
            return 0
            ;;
        --model|-m)
            COMPREPLY=($(compgen -W "claude-opus-4 claude-sonnet-4-5 claude-haiku-4" -- "$cur"))
            ;;
        --temperature|-t)
            COMPREPLY=($(compgen -W "0.0 0.3 0.5 0.7 1.0" -- "$cur"))
            ;;
        --max-tokens)
            COMPREPLY=($(compgen -W "1024 2048 4096 8192 16384" -- "$cur"))
            ;;
        --system-prompts|--system|-p)
            return 0
            ;;
        --output-format|--format-hint|--format|-f)
            COMPREPLY=($(compgen -W "md txt json html xml" -- "$cur"))
            ;;
        --input-file|--context-file|-in|-cx)
            _filedir
            ;;
        --input-pattern|--context-pattern)
            return 0
            ;;
        --output-file|-o)
            _filedir
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                local opts="$(_wireflow_api_options) $(_wireflow_input_options) $(_wireflow_execution_options)"
                opts="$opts --output-file --help -h"
                opts="$opts -m -t -p -f -in -cx -o -n"
                COMPREPLY=($(compgen -W "$opts" -- "$cur"))
            fi
            ;;
    esac
}

_wireflow_tasks() {
    case "$prev" in
        tasks)
            # Complete with subcommands or task names
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
            else
                COMPREPLY=($(compgen -W "list show edit" -- "$cur"))
            fi
            ;;
        show|edit)
            # Complete with task names
            COMPREPLY=($(compgen -W "$(_wireflow_list_tasks)" -- "$cur"))
            ;;
        list)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
            fi
            ;;
        *)
            return 0
            ;;
    esac
}

_wireflow_cat() {
    case "$prev" in
        cat)
            # Complete with workflow names
            COMPREPLY=($(compgen -W "$(_wireflow_list_workflows)" -- "$cur"))
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
            fi
            ;;
    esac
}

_wireflow_open() {
    case "$prev" in
        open)
            # Complete with workflow names
            COMPREPLY=($(compgen -W "$(_wireflow_list_workflows)" -- "$cur"))
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
            fi
            ;;
    esac
}

_wireflow_list() {
    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
    fi
}

_wireflow_help() {
    case "$prev" in
        help)
            # Complete with subcommand names
            COMPREPLY=($(compgen -W "init new edit config run task tasks cat open list" -- "$cur"))
            ;;
    esac
}

# Register completion function
complete -F _wireflow wfw wireflow