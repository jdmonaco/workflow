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

# Document aggregation with metadata for INPUT files
# Primary documents to be analyzed or transformed
# Outputs XML structure with document index and source path
documentcat() {
    # Input files are required
    if [ $# -eq 0 ]; then
        echo "Usage: documentcat file1 [file2 ...]" >&2
        return 1
    fi

    local index=1
    for file in "$@"; do
        if [[ -f "$file" ]]; then
            # Resolve to absolute path
            local abs_path
            abs_path=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")

            # Document with index and metadata
            printf "  <document index=\"%d\">\n" "$index"
            printf "    <source>%s</source>\n" "$abs_path"
            printf "    <document_content>\n"

            # Add file contents (no indentation)
            cat "$file"

            # Ensure newline before closing tag
            [[ -n $(tail -c 1 "$file" 2>/dev/null) ]] && printf "\n"

            printf "    </document_content>\n"
            printf "  </document>\n"
            printf "\n"

            ((index++))
        fi
    done
}

# Context aggregation with metadata for CONTEXT files
# Supporting information and background
# Outputs XML structure with source path
contextcat() {
    # Input files are required
    if [ $# -eq 0 ]; then
        echo "Usage: contextcat file1 [file2 ...]" >&2
        return 1
    fi

    for file in "$@"; do
        if [[ -f "$file" ]]; then
            # Resolve to absolute path
            local abs_path
            abs_path=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")

            # Context file with metadata
            printf "  <context-file>\n"
            printf "    <source>%s</source>\n" "$abs_path"
            printf "    <context_content>\n"

            # Add file contents (no indentation)
            cat "$file"

            # Ensure newline before closing tag
            [[ -n $(tail -c 1 "$file" 2>/dev/null) ]] && printf "\n"

            printf "    </context_content>\n"
            printf "  </context-file>\n"
            printf "\n"
        fi
    done
}

# Legacy function for backward compatibility (uses contextcat)
filecat() {
    contextcat "$@"
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

# Find all project roots from current directory upward
# Returns newline-separated list of absolute paths (closest first)
# Useful for nested project context aggregation
find_all_project_roots() {
    local dir="$PWD"
    local roots=()

    while [[ "$dir" != "$HOME" && "$dir" != "/" ]]; do
        if [[ -d "$dir/.workflow" ]]; then
            roots+=("$dir")
        fi
        dir="$(dirname "$dir")"
    done

    # Return all roots (newline-separated to handle spaces in paths)
    if [[ ${#roots[@]} -gt 0 ]]; then
        printf '%s\n' "${roots[@]}"
        return 0
    else
        return 1
    fi
}

# Aggregate project descriptions from all parent projects
# Creates hierarchical context by concatenating project.txt files
# from top-level down to current project with XML tagging
#
# Arguments:
#   $1 - Project root path (required)
#
# Returns:
#   0 if any project descriptions were aggregated
#   1 if no non-empty project.txt files found
#
# Side effects:
#   Writes aggregated content to $1/.workflow/prompts/project.txt
#   Creates prompts/ directory if needed
aggregate_nested_project_descriptions() {
    local current_root="$1"

    if [[ -z "$current_root" ]]; then
        return 1
    fi

    # Find all project roots from current location
    local all_roots
    all_roots=$(cd "$current_root" && find_all_project_roots) || {
        return 1
    }

    # Build cache file path
    local cache_file="$current_root/.workflow/prompts/project.txt"
    mkdir -p "$(dirname "$cache_file")"

    # Clear cache file
    > "$cache_file"

    # Convert newline-separated string to array
    local -a roots_array
    mapfile -t roots_array <<< "$all_roots"

    # Process in reverse order (top-level first)
    local processed_any=false
    for ((i=${#roots_array[@]}-1; i>=0; i--)); do
        local root="${roots_array[i]}"
        local proj_file="$root/.workflow/project.txt"

        # Skip if doesn't exist or is empty
        if [[ ! -f "$proj_file" || ! -s "$proj_file" ]]; then
            continue
        fi

        # Generate sanitized tag name from PROJECT_ROOT basename
        local tag_name
        tag_name=$(sanitize "$(basename "$root")")

        # Append with XML tag
        printf "<%s>\n" "$tag_name" >> "$cache_file"
        cat "$proj_file" >> "$cache_file"

        # Ensure newline before closing tag
        [[ -n $(tail -c 1 "$proj_file" 2>/dev/null) ]] && printf "\n" >> "$cache_file"

        printf "</%s>\n\n" "$tag_name" >> "$cache_file"

        processed_any=true
    done

    # Return success if we processed any projects
    if [[ "$processed_any" == true ]]; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Path Formatting
# =============================================================================

# Format absolute path with ~/ prefix for HOME directory
# Arguments:
#   $1 - Absolute path
# Returns:
#   Path with ~/ prefix if under $HOME, otherwise original path
format_path_with_tilde() {
    local path="$1"
    local relative="${path#$HOME/}"

    if [[ "$relative" == "$path" ]]; then
        # Path is not under HOME
        echo "$path"
    else
        # Path is under HOME, use ~/ prefix
        echo "~/$relative"
    fi
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
