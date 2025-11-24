# =============================================================================
# Interactive Editor Functions
# =============================================================================
# Support functions for interactively editing project and workflow files.
# This file is sourced by lib/core.sh.
# =============================================================================

# Function to detect if editor supports vim-style splits
is_vim_like() {
    local editor="$1"
    local editor_base=$(basename "$editor")
    
    case "$editor_base" in
        vim|nvim|neovim|gvim|mvim|vimx)
            return 0
            ;;
        vi)
            # Check if vi is actually vim in disguise
            if "$editor" --version 2>&1 | grep -qi "vim"; then
                return 0
            fi
            ;;
    esac
    return 1
}

# Function to check if editor supports multiple files well
supports_multiple_files() {
    local editor="$1"
    local editor_base=$(basename "$editor")
    
    case "$editor_base" in
        vim|nvim|neovim|gvim|mvim|vimx|vi|emacs|gedit|kate|code|subl)
            return 0
            ;;
    esac
    return 1
}

# Function to open files in the best available editor
edit_files() {
    local files=("$@")
    local editor=""
    local num_files="${#files[@]}"
    
    # Validate that files array is not empty
    if [ $num_files -eq 0 ]; then
        echo "Error: No files specified" >&2
        return 1
    fi
    
    # Priority order: VISUAL > EDITOR > vim > nvim > nano > emacs > vi > ed
    if [ -n "$VISUAL" ] && command -v "$VISUAL" >/dev/null 2>&1; then
        editor="$VISUAL"
    elif [ -n "$EDITOR" ] && command -v "$EDITOR" >/dev/null 2>&1; then
        editor="$EDITOR"
    elif command -v vim >/dev/null 2>&1; then
        editor="vim"
    elif command -v nvim >/dev/null 2>&1; then
        editor="nvim"
    elif command -v nano >/dev/null 2>&1; then
        editor="nano"
    elif command -v emacs >/dev/null 2>&1; then
        editor="emacs"
    elif command -v vi >/dev/null 2>&1; then
        editor="vi"
    elif command -v ed >/dev/null 2>&1; then
        editor="ed"
    else
        echo "Error: No suitable text editor found" >&2
        return 1
    fi
    
    # Call the editor -- single file and multiple file handling
    if [ $num_files -eq 1 ]; then
        "$editor" "${files[@]}"
    elif is_vim_like "$editor"; then
        # Vim-like editors: use vertical and horizontal splits
        if [ $num_files -eq 2 ]; then
            "$editor" -O "${files[@]}"
        elif [ $num_files -eq 3 ]; then
            "$editor" "${files[0]}" -c "vsplit ${files[1]} | wincmd l | split ${files[2]} | 1wincmd w"
        elif [ $num_files -eq 4 ]; then
            "$editor" -O2 "${files[0]}" "${files[1]}" -c "wincmd l | split ${files[3]} | wincmd h | \
                split ${files[2]} | 1wincmd w"
        else
            "$editor" "${files[@]}"
        fi
    elif ! supports_multiple_files "$editor"; then
        # Editors that don't handle multiple files well: edit sequentially
        echo "Note: Opening files sequentially (editor doesn't support splits)" >&2
        for file in "${files[@]}"; do
            "$editor" "$file" || return $?
        done
        return 0
    else
        # Else: editor can handle multiple files (like emacs), pass them all
        "$editor" "${files[@]}"
    fi
    
    return $?
}
