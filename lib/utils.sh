#!/usr/bin/env bash

# =============================================================================
# Workflow Utility Functions
# =============================================================================
# Support functions for the workflow CLI tool.
# This file is sourced by both workflow.sh and lib/core.sh.
# =============================================================================

# =============================================================================
# File Processing Functions
# =============================================================================

# Filename sanitization for XML-like identifiers
sanitize() {
    local filename="$1"
    local sanitized

    # Strip any parent path elements first
    sanitized="$(basename "$filename")"

    # Strip file extension
    sanitized="${sanitized%.*}"

    # Convert to lowercase
    sanitized="${sanitized,,}"

    # Replace spaces and common punctuation with dashes
    sanitized="${sanitized//[[:space:]]/-}"

    # Remove or replace characters not valid in XML names
    # Keep only alphanumeric, dash, and period
    sanitized="${sanitized//[^a-z0-9.-]/}"

    # Ensure it doesn't start with a number, dash, or period
    # (XML names must start with a letter or underscore)
    if [[ "$sanitized" =~ ^[0-9.-] ]]; then
        sanitized="_${sanitized}"
    fi

    # Remove consecutive dashes
    sanitized="${sanitized//--/-}"

    # Trim leading/trailing dashes
    sanitized="${sanitized#-}"
    sanitized="${sanitized%-}"

    echo "$sanitized"
}

# File concatenation with XML-like tag encapsulation
filecat() {
    # Input files are required
    if [ $# -eq 0 ]; then
        echo "Usage: filecat file1 [file2 ...]" >&2
        return 1;
    fi

    local sanitized
    for file in "$@"; do
        if [[ -f "$file" ]]; then
            # Opening tag, with sanitized identifier based on the filename
            sanitized="$(sanitize "$file")"
            printf "<%s>\n" "$sanitized"

            # Add the file contents
            cat "$file"

            # Ensure newline before closing tag if file doesn't end with one
            [[ -n $(tail -c 1 "$file") ]] && printf "\n"

            # Closing tag
            printf "</%s>\n" "$sanitized"
        fi
    done
}

# =============================================================================
# Project Root Discovery
# =============================================================================
find_project_root() {
    local dir="$PWD"
    while [[ "$dir" != "$HOME" && "$dir" != "/" ]]; do
        if [[ -d "$dir/.workflow" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# =============================================================================
# Workflow Listing
# =============================================================================

# List workflows in a project (excludes special files/directories)
list_workflows() {
    local project_root="${1:-$PROJECT_ROOT}"

    # Validate project root
    if [[ -z "$project_root" || ! -d "$project_root/.workflow" ]]; then
        echo "Error: Invalid project root or .workflow directory not found" >&2
        return 1
    fi

    # List entries, excluding special files/directories
    local workflows
    workflows=$(ls -1 "$project_root/.workflow" 2>/dev/null | \
                grep -E -v '^(config|prompts|output|project\.txt)$')

    # Return workflows if found, otherwise return 1
    if [[ -n "$workflows" ]]; then
        echo "$workflows"
        return 0
    else
        return 1
    fi
}

# =============================================================================
# JSON Utilities
# =============================================================================

# Escape JSON strings
escape_json() {
    local string="$1"
    printf '%s' "$string" | jq -Rs .
}
