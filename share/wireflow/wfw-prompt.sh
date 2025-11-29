#!/usr/bin/env bash
# =============================================================================
# WireFlow PS1 Prompt Integration
# =============================================================================
# Provides __wfw_ps1() for including project name in shell prompt.
#
# Usage:
#   source ~/.local/share/wireflow/wfw-prompt.sh
#   export PS1='\w$(__wfw_ps1 " (%s)")\$ '
#
# The optional format argument defaults to " (%s)" where %s is replaced
# with the project name (basename of project root directory).
# =============================================================================

# Find WireFlow project root by walking up the directory tree
# Returns the project root path, or exits with status 1 if not in a project
__wfw_find_project_root() {
    local dir="${1:-$PWD}"
    local max_depth=100
    local depth=0

    # Get canonical path
    if [[ -d "$dir" ]]; then
        dir="$(cd "$dir" 2>/dev/null && pwd -P)" || dir="${1:-$PWD}"
    fi
    [[ -z "$dir" ]] && return 1

    while [[ "$dir" != "/" && $depth -lt $max_depth ]]; do
        if [[ -d "$dir/.workflow" ]]; then
            echo "$dir"
            return 0
        fi
        local parent
        parent="$(dirname "$dir")"
        [[ "$parent" == "$dir" ]] && break
        dir="$parent"
        ((depth++))
    done

    [[ -d "/.workflow" ]] && echo "/" && return 0
    return 1
}

# Print formatted project name for PS1 prompt integration
# Usage: __wfw_ps1 [format]
#   format: printf format string (default: " (%s)")
__wfw_ps1() {
    local fmt="${1:- (%s)}"
    local project_root

    project_root="$(__wfw_find_project_root)" || return

    local project_name
    project_name="$(basename "$project_root")"

    # shellcheck disable=SC2059
    printf "$fmt" "$project_name"
}
