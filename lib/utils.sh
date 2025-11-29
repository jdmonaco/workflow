# =============================================================================
# WireFlow Utility Functions
# =============================================================================
# Support functions for the WireFlow CLI tool.
# =============================================================================

# =============================================================================
# Path Formatting
# =============================================================================

# Verify and canonicalize target paths (requires realpath)
# Arguments:
#   $@ - Target paths
# Returns:
#   success status - All target paths verified
#   stdout - Canonicalized paths, one line per verified target path
real_path() {
    realpath -q "${@}"
}

# Path normalization
# Arguments:
#   $1 - Path to normalize, required
# Returns:
#   stdout - Path with normalized components (removed '.', '..', '//', etc.)
normalize_path() {  
    local path="$1"
    
    # Validate required path argument
    # Handle empty input
    if [[ -z "$path" ]]; then
        echo "."
        return 0
    fi

    local max_iterations=100  # Prevent infinite loops
    local counter=0

    # Remove trailing slashes (except root)
    while [[ "$path" != "/" && "$path" == */ ]]; do
        path="${path%/}"
    done

    # Iteratively simplify the path with safeguard
    local prev_path=""
    while [[ "$prev_path" != "$path" && $counter -lt $max_iterations ]]; do
        prev_path="$path"

        # Remove /./
        path="${path//\/.\//\/}"

        # Remove leading ./
        [[ "$path" == ./* ]] && path="${path#./}"

        # Remove trailing /.
        [[ "$path" != "/" ]] && path="${path%/.}"

        # Remove //
        path="${path//\/\//\/}"

        # Remove /dir/../ patterns safely
        # This handles the common case of parent directory references
        if [[ "$path" =~ /[^/]+/\.\. ]]; then
            path=$(echo "$path" | sed 's|/[^/][^/]*/\.\./|/|g')
            path=$(echo "$path" | sed 's|/[^/][^/]*/\.\.$||')
        fi

        ((counter++))
    done

    # Final cleanup
    [[ -z "$path" ]] && path="/"
    [[ "$path" != "/" ]] && path="${path%/}"

    # Handle relative paths that are now empty after cleanup
    [[ -z "$path" ]] && path="."

    # Output the final normalized path
    echo "$path"
}

# Normalize any path for display  
# Arguments:  
#   $1 - Path to format, optional (defaults to '.')  
# Returns:  
#   stdout - Normalized path with optional tilde prefix for absolute paths  
display_normalized_path() {
    local path="${1:-.}"  
    local normalized="$(normalize_path "$path")"  
    echo "${normalized/#$HOME/\~}"  
}

# Absolute path normalization without link-following or verification
# Arguments:
#   $1 - Path to normalize, optional (defaults to '.')
# Returns:
#   stdout - Normalized absolute path
absolute_path() {
    local path="${1:-.}"
    
    # Expand tilde
    path="${path/#\~/$HOME}"

    # Ensure absolute path
    [[ "$path" != /* ]] && path="$(pwd)/$path"

    # Path normalization
    normalize_path "$path"
}

# Absolute path with tilde prefix for display
# Arguments:
#   $1 - Path to format, optional (defaults to '.')
# Returns:
#   stdout - Normalized absolute path with tilde prefix for display
display_absolute_path() {
    local path="${1:-.}"
    local abs_path="$(absolute_path "$path")"
    echo "${abs_path/#$HOME/\~}"
}

# Relative path normalization with respect to any base path  
# Arguments:  
#   $1 - Target path, optional (defaults to '.')  
#   $2 - Base path, optional (defaults to $HOME)  
# Returns:  
#   stdout - Normalized relative path to the target path from the base path  
relative_path() {  
    local target="${1:-.}"  
    local base="${2:-$HOME}"  
  
    # Make both paths absolute first
    local target_abs="$(absolute_path "$target")"  
    local base_abs="$(absolute_path "$base")"  
  
    # If they're the same, return .
    if [[ "$target_abs" == "$base_abs" ]]; then
        echo "."
        return
    fi
    
    # If target is under base (child), strip base prefix
    if [[ "$target_abs" == "$base_abs"/* ]]; then
        local rel="${target_abs#$base_abs/}"
        echo "$rel"
        return
    fi
    
    # Otherwise, need to go up from base to find common ancestor
    local common="$base_abs"
    local ups=""
    
    # Walk up from base until we find a common prefix
    while [[ -n "$common" ]] && [[ "$common" != "/" ]] && [[ "$target_abs" != "$common"/* ]] && [[ "$target_abs" != "$common" ]]; do
        ups="../$ups"
        common="${common%/*}"
        # If we've gone all the way up to root
        [[ -z "$common" ]] && common="/"
    done

    # If no common ancestor (shouldn't happen for absolute paths), return absolute path
    if [[ -z "$common" ]]; then
        echo "$target_abs"
        return
    fi
    
    # Build relative path: ups + remainder of target
    if [[ "$target_abs" == "$common" ]]; then
        # Target is the common ancestor
        echo "${ups%/}"  # Remove trailing /
    else
        # Target is below common ancestor
        local remainder
        if [[ "$common" == "/" ]]; then
            # Special case for root - don't add extra slash
            remainder="${target_abs#/}"
        else
            remainder="${target_abs#$common/}"
        fi
        echo "${ups}${remainder}"
    fi
}

# =============================================================================
# Terminal UI Functions
# =============================================================================

# Prompt the user before continuing execution, otherwise exit the program
# Arguments:
#    $1 - optional prompt string to display
prompt_to_continue_or_exit() {
    # Auto-continue in test mode
    [[ "${WIREFLOW_TEST_MODE:-}" == "true" ]] && return 0

    [[ -n "$1" ]] && echo "$1"
    read -p "Continue? [y/N] " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && echo "Exiting..." && exit 0
    echo ""
}

# =============================================================================
# File Processing Functions
# =============================================================================

# Filename sanitization -- create XML-like identifiers for files
sanitize() {
    local input="$1"
    local sanitized="$input"

    # Replace path separators with underscores (preserves path structure)
    sanitized="${sanitized//\//_}"

    # Replace spaces with underscores
    sanitized="${sanitized// /_}"

    # Replace special characters with underscores
    # Keep only alphanumeric, dash, underscore, and period
    # Use sed to replace non-matching chars with underscore
    sanitized=$(echo "$sanitized" | sed 's/[^a-zA-Z0-9._-]/_/g')

    # Ensure it doesn't start with a number, dash, or period
    # (XML names must start with a letter or underscore)
    if [[ "$sanitized" =~ ^[0-9.-] ]]; then
        sanitized="_${sanitized}"
    fi

    # Remove consecutive underscores
    while [[ "$sanitized" == *"__"* ]]; do
        sanitized="${sanitized//__/_}"
    done

    # Trim leading/trailing underscores
    sanitized="${sanitized#_}"
    sanitized="${sanitized%_}"

    echo "$sanitized"
}

# =============================================================================
# Obsidian Markdown Preprocessing
# =============================================================================

# Resolve Obsidian embed reference to actual file path
# Arguments:
#   $1 - embed reference (e.g., "image.png" or "Attachments/doc.pdf")
#   $2 - source directory (directory containing the markdown file)
# Returns:
#   Absolute path to stdout if found, empty if not found
#   Exit code 0 if found, 1 if not found
resolve_obsidian_embed() {
    local embed_ref="$1"
    local source_dir="$2"

    # Strip page/dimension modifiers
    embed_ref="${embed_ref%%#*}"  # Remove #page=N
    embed_ref="${embed_ref%%|*}"  # Remove |dimensions

    # Search directories in order of priority
    local search_dirs=(
        "$source_dir"
        "$source_dir/Attachments"
        "$source_dir/attachments"
        "$source_dir/assets"
        "$source_dir/images"
        "$source_dir/media"
    )

    for dir in "${search_dirs[@]}"; do
        local candidate="$dir/$embed_ref"
        if [[ -f "$candidate" ]]; then
            # Return absolute path
            realpath "$candidate"
            return 0
        fi
    done

    return 1
}

# Global arrays for tracking discovered embed files during preprocessing
# Populated by preprocess_obsidian_markdown(), consumed by caller
declare -a OBSIDIAN_EMBED_FILES=()
declare -a OBSIDIAN_EMBED_ROLES=()

# Preprocess Obsidian markdown, resolving ![[...]] embeds
# Arguments:
#   $1 - markdown content
#   $2 - source file path (for relative resolution)
#   $3 - role ("context" or "input")
#   $4 - project root (for relative path calculation)
# Outputs:
#   - Modified markdown to stdout
#   - Populates OBSIDIAN_EMBED_FILES array with resolved absolute paths
#   - Populates OBSIDIAN_EMBED_ROLES array with corresponding roles
# Returns:
#   0 on success, warnings to stderr for missing files
preprocess_obsidian_markdown() {
    local content="$1"
    local source_file="$2"
    local role="$3"
    local project_root="$4"
    local source_dir
    source_dir=$(dirname "$source_file")

    # Clear global arrays for this file
    OBSIDIAN_EMBED_FILES=()
    OBSIDIAN_EMBED_ROLES=()

    # Process content line by line
    local output=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Check for Obsidian embed pattern: ![[filename]] or ![[filename|dims]] or ![[filename#page]]
        if [[ "$line" =~ !\[\[([^\]|#]+)([\|#][^\]]+)?\]\] ]]; then
            local embed_ref="${BASH_REMATCH[1]}"
            local modifiers="${BASH_REMATCH[2]:-}"
            local full_match="![[${embed_ref}${modifiers}]]"
            local resolved_path

            # Try to find the file
            resolved_path=$(resolve_obsidian_embed "$embed_ref" "$source_dir")

            if [[ -n "$resolved_path" ]]; then
                # Generate XML tag from project-relative path
                local rel_path xml_tag
                rel_path=$(relative_path "$resolved_path" "$project_root")
                xml_tag=$(sanitize "$rel_path")

                # Replace embed with XML reference tag
                # Escape brackets for bash glob pattern substitution
                local escaped_match="${full_match//\[/\\[}"
                escaped_match="${escaped_match//\]/\\]}"
                line="${line//$escaped_match/<${xml_tag}\/>}"

                # Track file for inclusion (deduplication handled by caller)
                OBSIDIAN_EMBED_FILES+=("$resolved_path")
                OBSIDIAN_EMBED_ROLES+=("$role")
            else
                # Warning to stderr, keep original syntax
                echo "Warning: Obsidian embed not found: $embed_ref (in $source_file)" >&2
            fi
        fi
        output+="$line"$'\n'
    done <<< "$content"

    # Remove trailing newline added by loop
    printf '%s' "${output%$'\n'}"
}

# =============================================================================
# Project and Workflow Utilities
# =============================================================================

# Library help function to print justified columns of paths
_print_labeled_path() {
    local label="${1:-Path}"
    local path="$2"
    local indent="${3:-  }"
    [[ -z "$path" ]] && return 1
    local display="$(display_absolute_path "$path")"
    printf "${indent}%-12s%-55s%s\n" "${label}:" "$display"
}

# Show current project location (root directory path)
show_project_location() {
    local project_root="${1:-$PROJECT_ROOT}"
    local project_file="${2:-$PROJECT_FILE}"
    local output_dir="${3:-$OUTPUT_DIR}"
    [[ -z "$project_root" || ! -d "$project_root" ]] && return 1

    # Display current project root
    echo "Current Project:"
    _print_labeled_path "Root" "$project_root"
    _print_labeled_path "Project" "$project_file" || true
    _print_labeled_path "Output" "$output_dir" || true
    return 0
}

# Show specific workflow location (run directory path)
show_workflow_location() {
    local name="${1:-$WORKFLOW_NAME}"
    local workflow_dir="${2:-$WORKFLOW_DIR}"
    local project_root="${3:-$PROJECT_ROOT}"
    [[ -z "$name" || -z "$workflow_dir" ]] && return 1
    [[ ! -d "$workflow_dir" ]] && return 1

    # Display current project root
    echo "Workflow ('$name'):"
    _print_labeled_path "Project" "$project_root" || true
    _print_labeled_path "Run path" "$workflow_dir"
    _print_labeled_path "Task file" "$workflow_dir/task.txt"
    return 0
}

# Find the closest (current) project root in parent directory tree
find_project_root() {
    local dir="${1:-$(pwd)}"
    local max_depth=100  # Reasonable maximum
    local depth=0

    # Get canonical path to avoid symlink issues, but handle failures gracefully
    if [[ -d "$dir" ]]; then
        dir="$(cd "$dir" 2>/dev/null && pwd -P)" || dir="${1:-$(pwd)}"
    fi
    # If no directory at all, return failure
    [[ -z "$dir" ]] && return 1

    while [[ "$dir" != "/" && $depth -lt $max_depth ]]; do
        if [[ -d "$dir/.workflow" ]]; then
            echo "$dir"
            return 0
        fi
        # Safeguard against dirname not making progress
        local parent="$(dirname "$dir")"
        [[ "$parent" == "$dir" ]] && break
        dir="$parent"
        ((depth++))
    done

    # Check root directory as final attempt
    [[ -d "/.workflow" ]] && echo "/" && return 0

    # No project found - return failure
    return 1
}

# Find ancestor project roots excluding current project
# Returns:
#   success status - if any ancestors were found
#   stdout - newline-separated paths from oldest to newest ancestor
find_ancestor_projects() {
    local project_root="${1:-$PROJECT_ROOT}"
    local dir="$(dirname "$project_root")" # start at parent
    local roots=()
    local max_depth=100
    local depth=0

    # Get canonical starting directory
    dir="$(cd "$dir" 2>/dev/null && pwd -P)" || return 1

    # Search upwards to find all project roots
    while [[ "$dir" != "/" && $depth -lt $max_depth ]]; do
        if [[ -d "$dir/.workflow" ]]; then
            roots+=("$dir")
        fi
        local parent="$(dirname "$dir")"
        [[ "$parent" == "$dir" ]] && break  # Safeguard
        dir="$parent"
        ((depth++))
    done

    # Check root as final location
    [[ -d "/.workflow" ]] && roots+=("/")

    # If ancestors were found, print them out in reverse
    if [[ ${#roots[@]} -eq 0 ]]; then
        # Failure if no ancestors found
        return 1
    else
        # Reverse array to print oldest first
        for ((i=${#roots[@]}-1; i>=0; i--)); do
            printf '%s\n' "${roots[i]}"
        done
        return 0
    fi
}

# =============================================================================
# Workflow Management
# =============================================================================

# Verify that workflow directory exists and ensure its path is set
# Returns:
#   0 - if a valid workflow directory exists and its paths have been set
#   1 - if this is not a workflow run or no valid path or directory can be found
check_workflow_dir() {
    # Fail if this is not a workflow run (i.e., WORKFLOW_NAME is unset)
    [[ -z "${WORKFLOW_NAME:-}" ]] && return 1

    # Try to build a valid workflow directory path
    local dir="${WORKFLOW_DIR:-}"
    if [[ -z "$dir" ]]; then
        if [[ -n "$RUN_DIR" && -n "$WORKFLOW_NAME" ]]; then
            dir="$RUN_DIR/$WORKFLOW_NAME"
        else
            echo "check_workflow_dir: set RUN_DIR and WORKFLOW_NAME first" >&2
            return 1
        fi
    fi

    # Verify that the workflow directory exists
    [[ -d "$dir" ]] || return 1

    # Set workflow paths
    WORKFLOW_DIR="$(absolute_path "$dir")"
    WORKFLOW_CONFIG="$WORKFLOW_DIR/config"
    WORKFLOW_TASK="$WORKFLOW_DIR/task.txt"
}

# List workflows in a project
list_workflows() {
    local run_root="${1:-$RUN_DIR}"
    [[ -z "$run_root" || ! -d "$run_root" ]] && return 1

    # List entries in the workflow run directory
    local workflows
    workflows=$(ls -1 "$run_root" 2>/dev/null)

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
    # Use jq to escape special characters, then remove the outer quotes
    printf '%s' "$string" | jq -Rs . | sed 's/^"//;s/"$//'
}

# =============================================================================
# Title Extraction (for Citations)
# =============================================================================

# Convert filename to sentence-case title
# Arguments:
#   $1 - File path
# Returns:
#   Title string (e.g., "my-document.md" → "My Document")
filename_to_title() {
    local filepath="$1"
    local filename
    local title

    # Get basename and strip extension
    filename=$(basename "$filepath")
    title="${filename%.*}"

    # Replace dashes and underscores with spaces
    title="${title//-/ }"
    title="${title//_/ }"

    # Capitalize first letter of each word if it's lowercase (preserve existing uppercase)
    title=$(echo "$title" | awk '{for(i=1;i<=NF;i++) {if(substr($i,1,1) ~ /[a-z]/) $i=toupper(substr($i,1,1)) substr($i,2); }}1')

    echo "$title"
}

# Extract title from file using multiple strategies
# Priority: YAML frontmatter → Markdown heading → filename
# Arguments:
#   $1 - File path
# Returns:
#   Title string
extract_title_from_file() {
    local filepath="$1"

    if [[ ! -f "$filepath" ]]; then
        echo "Untitled"
        return 1
    fi

    # Check if file is Markdown
    if [[ "$filepath" =~ \.(md|markdown)$ ]]; then
        # Strategy 1: YAML frontmatter
        local in_frontmatter=false
        local title_from_frontmatter=""

        while IFS= read -r line; do
            # Check for frontmatter start/end
            if [[ "$line" == "---" ]]; then
                if [[ "$in_frontmatter" == false ]]; then
                    in_frontmatter=true
                    continue
                else
                    # End of frontmatter
                    break
                fi
            fi

            # Extract title key from frontmatter
            if [[ "$in_frontmatter" == true && "$line" =~ ^title:[[:space:]]* ]]; then
                title_from_frontmatter="${line#title:}"
                title_from_frontmatter="${title_from_frontmatter#"${title_from_frontmatter%%[![:space:]]*}"}"  # ltrim
                title_from_frontmatter="${title_from_frontmatter%"${title_from_frontmatter##*[![:space:]]}"}"  # rtrim
                # Remove quotes if present
                title_from_frontmatter="${title_from_frontmatter#\"}"
                title_from_frontmatter="${title_from_frontmatter%\"}"
                title_from_frontmatter="${title_from_frontmatter#\'}"
                title_from_frontmatter="${title_from_frontmatter%\'}"
                break
            fi
        done < "$filepath"

        if [[ -n "$title_from_frontmatter" ]]; then
            echo "$title_from_frontmatter"
            return 0
        fi

        # Strategy 2: First H1 or H2 heading
        local heading
        heading=$(grep -m 1 -E '^##? ' "$filepath" 2>/dev/null)
        if [[ -n "$heading" ]]; then
            # Strip leading # and whitespace
            heading="${heading#\#}"
            heading="${heading#\#}"
            heading="${heading#"${heading%%[![:space:]]*}"}"  # ltrim
            heading="${heading%"${heading##*[![:space:]]}"}"  # rtrim
            echo "$heading"
            return 0
        fi
    fi

    # Strategy 3: Filename fallback
    filename_to_title "$filepath"
}

# =============================================================================
# Content Block Builders (for Anthropic Messages API)
# =============================================================================

# Detect file type (text vs document/PDF vs office vs image)
# Arguments:
#   $1 - File path
# Returns:
#   "text" for text files (default)
#   "document" for PDFs
#   "office" for Microsoft Office files (docx, pptx)
#   "image" for supported image formats (jpg, png, gif, webp)
detect_file_type() {
    local file="$1"
    local extension="${file##*.}"

    # Convert to lowercase
    extension="${extension,,}"

    # Check file type by extension
    case "$extension" in
        # Image types (Vision API support)
        # Native formats: png, jpg, jpeg, gif, webp
        # Conversion formats: svg (rasterize), heic/heif (to jpeg), tiff/tif (to png)
        png|jpg|jpeg|gif|webp|svg|heic|heif|tiff|tif)
            echo "image"
            ;;
        # PDF document types
        pdf)
            echo "pdf"
            ;;
        # Microsoft Office types (require conversion)
        docx|pptx)
            echo "office"
            ;;
        # Binary files
        bin|exe|zip|tar|gz|bz2|7z|rar|so|dylib|dll|o|a)
            echo "binary"
            ;;
        # Text files (default for code, config, docs, etc.)
        *)
            # If no extension or unknown, try file command
            if [[ -f "$file" ]]; then
                local file_output=$(file -b "$file" 2>/dev/null)
                if [[ "$file_output" == *"executable"* ]] || [[ "$file_output" == *"binary"* ]] || [[ "$file_output" == "data" ]]; then
                    echo "binary"
                else
                    echo "text"
                fi
            else
                echo "text"
            fi
            ;;
    esac
}

# Check if file type is supported for inclusion (non-binary)
# Arguments:
#   $1 - File path
# Returns:
#   0 (true) if supported, 1 (false) if binary/unsupported
is_supported_file() {
    local file="$1"
    local file_type
    file_type=$(detect_file_type "$file")
    [[ "$file_type" != "binary" ]]
}

# Get image media type from file extension
# Arguments:
#   $1 - File path
# Returns:
#   Proper MIME type string (e.g., "image/jpeg")
get_image_media_type() {
    local file="$1"
    local extension="${file##*.}"

    # Convert to lowercase
    extension="${extension,,}"

    case "$extension" in
        jpg|jpeg)
            echo "image/jpeg"
            ;;
        png)
            echo "image/png"
            ;;
        gif)
            echo "image/gif"
            ;;
        webp)
            echo "image/webp"
            ;;
        svg)
            echo "image/svg+xml"
            ;;
        heic|heif)
            echo "image/heic"
            ;;
        tiff|tif)
            echo "image/tiff"
            ;;
        *)
            echo "image/jpeg"  # Default fallback
            ;;
    esac
}

# Check if image format requires conversion for Vision API
# Arguments:
#   $1 - File path
# Returns:
#   0 if conversion needed, 1 if format is natively supported
# Stdout:
#   Target format (jpeg, png) if conversion needed
needs_format_conversion() {
    local file="$1"
    local extension="${file##*.}"
    extension="${extension,,}"

    case "$extension" in
        heic|heif)
            echo "jpeg"
            return 0
            ;;
        tiff|tif)
            echo "png"
            return 0
            ;;
        svg)
            echo "png"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Get target dimensions for SVG rasterization
# SVG has no inherent pixel dimensions, so we target 1568px on long edge
# Arguments:
#   $1 - SVG file path (unused, for API consistency)
# Returns:
#   "width height" - target dimensions (stdout)
get_svg_target_dimensions() {
    # For SVG, target 1568px on the long edge (Vision API optimal)
    # ImageMagick will preserve aspect ratio with this max dimension
    echo "1568 1568"
}

# Get image dimensions using ImageMagick
# Arguments:
#   $1 - Image file path
# Returns:
#   "width height" (space-separated) or empty string on error
get_image_dimensions() {
    local file="$1"

    if ! command -v magick >/dev/null 2>&1; then
        return 1
    fi

    # Use identify to get dimensions
    magick identify -format "%w %h" "$file" 2>/dev/null
}

# Validate image file against API limits
# Arguments:
#   $1 - Image file path
# Returns:
#   0 if valid, 1 if invalid
# Prints error message to stderr if invalid
validate_image_file() {
    local file="$1"

    # Check file exists
    if [[ ! -f "$file" ]]; then
        echo "Error: Image file not found: $file" >&2
        return 1
    fi

    # Check file size (5MB limit for API)
    local file_size
    file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    local max_size=$((5 * 1024 * 1024))  # 5MB

    if [[ $file_size -gt $max_size ]]; then
        echo "Error: Image file exceeds 5MB limit: $file ($file_size bytes)" >&2
        return 1
    fi

    # Check dimensions if ImageMagick available
    if command -v magick >/dev/null 2>&1; then
        local dimensions
        dimensions=$(get_image_dimensions "$file")
        if [[ -n "$dimensions" ]]; then
            local width height
            read -r width height <<< "$dimensions"

            # Hard limit: 8000x8000 (or 2000x2000 if >20 images, but we check per-image)
            if [[ $width -gt 8000 || $height -gt 8000 ]]; then
                echo "Warning: Image dimensions ($width x $height) exceed 8000px limit, will be resized" >&2
                # Not a fatal error, will be resized
            fi
        fi
    fi

    return 0
}

# Check if image should be resized
# Arguments:
#   $1 - width (pixels)
#   $2 - height (pixels)
# Returns:
#   0 if should resize (exceeds 1568px on long edge)
#   1 if no resize needed
should_resize_image() {
    local width=$1
    local height=$2
    local max_long_edge=1568

    local long_edge
    [[ $width -gt $height ]] && long_edge=$width || long_edge=$height

    [[ $long_edge -gt $max_long_edge ]]
}

# Calculate target dimensions for resizing
# Maintains aspect ratio, limits long edge to 1568px
# Arguments:
#   $1 - width (pixels)
#   $2 - height (pixels)
# Returns:
#   "target_width target_height" (space-separated)
calculate_target_dimensions() {
    local width=$1
    local height=$2
    local max_long_edge=1568

    local long_edge
    [[ $width -gt $height ]] && long_edge=$width || long_edge=$height

    # If already within limits, return original dimensions
    if [[ $long_edge -le $max_long_edge ]]; then
        echo "$width $height"
        return 0
    fi

    # Calculate scale factor
    local scale
    scale=$(awk "BEGIN {printf \"%.6f\", $max_long_edge / $long_edge}")

    # Calculate new dimensions
    local new_width new_height
    new_width=$(awk "BEGIN {printf \"%.0f\", $width * $scale}")
    new_height=$(awk "BEGIN {printf \"%.0f\", $height * $scale}")

    echo "$new_width $new_height"
}

# Resize image using ImageMagick
# Arguments:
#   $1 - source_file: Original image file
#   $2 - target_file: Output file path
#   $3 - target_width: Target width in pixels
#   $4 - target_height: Target height in pixels
# Returns:
#   0 on success, 1 on failure
resize_image() {
    local source_file="$1"
    local target_file="$2"
    local target_width="$3"
    local target_height="$4"

    if ! command -v magick >/dev/null 2>&1; then
        echo "Error: ImageMagick not found. Cannot resize image: $source_file" >&2
        return 1
    fi

    # Create target directory if needed
    mkdir -p "$(dirname "$target_file")"

    # Resize image using geometry specification
    magick "$source_file" -resize "${target_width}x${target_height}" "$target_file" 2>/dev/null || {
        echo "Error: Failed to resize image: $source_file" >&2
        return 1
    }

    return 0
}

# Convert image format and optionally resize in a single operation
# Supports HEIC/TIFF/SVG conversion with macOS sips fallback for HEIC
# Arguments:
#   $1 - source_file: Original image file
#   $2 - target_file: Output file path (extension determines format)
#   $3 - target_width: Target width in pixels (optional, 0 = no resize)
#   $4 - target_height: Target height in pixels (optional, 0 = no resize)
#   $5 - quality: JPEG quality (optional, default 85, ignored for PNG)
# Returns:
#   0 on success, 1 on failure
convert_image_format() {
    local source_file="$1"
    local target_file="$2"
    local target_width="${3:-0}"
    local target_height="${4:-0}"
    local quality="${5:-85}"

    # Create target directory if needed
    mkdir -p "$(dirname "$target_file")"

    # Determine source format for special handling
    local extension="${source_file##*.}"
    extension="${extension,,}"

    # Try ImageMagick first (cross-platform)
    if command -v magick >/dev/null 2>&1; then
        local magick_args=()

        # SVG special handling: set density for quality rasterization
        if [[ "$extension" == "svg" ]]; then
            magick_args+=(-density 300 -background none)
        fi

        # Add source file
        magick_args+=("$source_file")

        # Add resize if dimensions specified
        if [[ $target_width -gt 0 && $target_height -gt 0 ]]; then
            magick_args+=(-resize "${target_width}x${target_height}")
        fi

        # Add quality setting for JPEG output
        if [[ "$target_file" == *.jpg ]] || [[ "$target_file" == *.jpeg ]]; then
            magick_args+=(-quality "$quality")
        fi

        # Add output file
        magick_args+=("$target_file")

        # Execute conversion
        if magick "${magick_args[@]}" 2>/dev/null; then
            return 0
        fi
    fi

    # macOS fallback for HEIC using sips (built-in, no extra dependencies)
    if [[ "$extension" == "heic" || "$extension" == "heif" ]]; then
        if [[ "$OSTYPE" == darwin* ]] && command -v sips >/dev/null 2>&1; then
            # sips can convert HEIC to JPEG natively
            if sips -s format jpeg "$source_file" --out "$target_file" 2>/dev/null; then
                # Apply resize separately if needed
                if [[ $target_width -gt 0 && $target_height -gt 0 ]]; then
                    # sips -Z uses the larger dimension for max size
                    local max_dim=$target_width
                    [[ $target_height -gt $target_width ]] && max_dim=$target_height
                    sips -Z "$max_dim" "$target_file" 2>/dev/null
                fi
                return 0
            fi
        fi
    fi

    echo "Error: Failed to convert image: $source_file (ImageMagick required)" >&2
    return 1
}

# Cache and potentially convert/resize image for API use
# Uses global CACHE_DIR for project-level caching with hash-based IDs
# Arguments:
#   $1 - source_file: Original image file (absolute path)
# Returns:
#   Path to cached/converted/resized image (or original if no processing needed)
# Note:
#   When CACHE_DIR is empty (standalone task mode), processes to temp file
cache_image() {
    local source_file="$1"

    # Check if format conversion is needed
    local needs_conversion=false
    local target_format=""
    if target_format=$(needs_format_conversion "$source_file"); then
        needs_conversion=true
    fi

    # Get source extension
    local source_extension="${source_file##*.}"
    source_extension="${source_extension,,}"

    # Determine output extension based on conversion
    local output_extension
    if [[ "$needs_conversion" == true ]]; then
        case "$target_format" in
            jpeg) output_extension="jpg" ;;
            png)  output_extension="png" ;;
            *)    output_extension="$source_extension" ;;
        esac
    else
        output_extension="$source_extension"
    fi

    # Get dimensions and determine resize needs
    local dimensions width height needs_resize target_width target_height

    if [[ "$source_extension" == "svg" ]]; then
        # SVG: use target dimensions directly (no source pixel dimensions)
        dimensions=$(get_svg_target_dimensions "$source_file")
        read -r width height <<< "$dimensions"
        needs_resize=true
        target_width=$width
        target_height=$height
    else
        dimensions=$(get_image_dimensions "$source_file")
        if [[ -z "$dimensions" ]]; then
            if [[ "$needs_conversion" == true ]]; then
                echo "Error: Cannot determine dimensions for conversion: $source_file" >&2
                return 1
            fi
            # Can't get dimensions (ImageMagick not available), use original
            echo "$source_file"
            return 0
        fi
        read -r width height <<< "$dimensions"

        # Check if resize needed
        if should_resize_image "$width" "$height"; then
            local target_dims
            target_dims=$(calculate_target_dimensions "$width" "$height")
            read -r target_width target_height <<< "$target_dims"
            needs_resize=true
        else
            needs_resize=false
            target_width=0
            target_height=0
        fi
    fi

    # If no conversion and no resize needed, return original
    if [[ "$needs_conversion" == false && "$needs_resize" == false ]]; then
        echo "$source_file"
        return 0
    fi

    # Determine cache location
    local cached_file
    if [[ -n "$CACHE_DIR" ]]; then
        local cache_id
        cache_id=$(generate_cache_id "$source_file")
        local cache_subdir="$CACHE_DIR/conversions/images"
        cached_file="$cache_subdir/${cache_id}.${output_extension}"

        # Check if already cached and valid
        if validate_cache_entry "$cached_file"; then
            echo "$cached_file"
            return 0
        fi

        mkdir -p "$cache_subdir"
    else
        # No persistent cache (standalone task mode): use temp file
        cached_file=$(mktemp -t "wfw_image_XXXXXX.${output_extension}")
    fi

    # Determine conversion type for metadata
    local conversion_type
    if [[ "$needs_conversion" == true && "$needs_resize" == true ]]; then
        conversion_type="image_convert_and_resize_${source_extension}_to_${output_extension}"
    elif [[ "$needs_conversion" == true ]]; then
        conversion_type="image_convert_${source_extension}_to_${output_extension}"
    else
        conversion_type="image_resize"
    fi

    # Perform conversion/resize
    local resize_w=0 resize_h=0
    if [[ "$needs_resize" == true ]]; then
        resize_w=$target_width
        resize_h=$target_height
    fi

    if convert_image_format "$source_file" "$cached_file" "$resize_w" "$resize_h"; then
        # Write cache metadata (if using project cache)
        if [[ -n "$CACHE_DIR" ]]; then
            write_cache_metadata "$cached_file" "$source_file" "$conversion_type"
        fi

        # Log what happened
        if [[ "$needs_conversion" == true && "$needs_resize" == true ]]; then
            echo "  Converted and resized: ${source_extension^^} → ${output_extension^^}, ${width}x${height} → ${target_width}x${target_height}" >&2
        elif [[ "$needs_conversion" == true ]]; then
            echo "  Converted image: ${source_extension^^} → ${output_extension^^}" >&2
        else
            echo "  Resized image: ${width}x${height} → ${target_width}x${target_height} (cached)" >&2
        fi

        echo "$cached_file"
        return 0
    else
        [[ -z "$CACHE_DIR" ]] && rm -f "$cached_file"
        echo "$source_file"
        return 1
    fi
}

# Build image content block for Vision API
# Arguments:
#   $1 - file: Image file path (absolute)
# Returns:
#   JSON content block with type="image", base64-encoded data
# Note:
#   Images are NOT citable and do NOT get document indices
#   Uses global CACHE_DIR for caching resized images
build_image_content_block() {
    local file="$1"

    # Get absolute path
    local abs_path
    abs_path=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")

    # Validate image
    if ! validate_image_file "$abs_path"; then
        return 1
    fi

    # Cache and potentially resize image
    local image_file
    image_file=$(cache_image "$abs_path")

    # Get media type
    local media_type
    media_type=$(get_image_media_type "$image_file")

    # Base64 encode image
    # For large images, we need to avoid shell variable size limits
    # Pass base64 data through stdin to jq using printf (no trailing newline)
    local base64_data
    base64_data=$(base64 < "$image_file" | tr -d '\n')

    # Build image content block (Vision API format)
    # Note: No cache_control for images, no citations, no document index
    # Use printf (not echo) to avoid adding trailing newline before jq -Rs
    printf '%s' "$base64_data" | jq -Rs \
        --arg type "image" \
        --arg source_type "base64" \
        --arg media_type "$media_type" \
        '{
            type: $type,
            source: {
                type: $source_type,
                media_type: $media_type,
                data: .
            }
        }'
}

# =============================================================================
# PDF Document Validation and Processing
# =============================================================================

# Validate PDF file against API limits
# Arguments:
#   $1 - PDF file path
# Returns:
#   0 if valid, 1 if invalid
# Prints error message to stderr if invalid
validate_pdf_file() {
    local file="$1"

    # Check file exists
    if [[ ! -f "$file" ]]; then
        echo "Error: PDF file not found: $file" >&2
        return 1
    fi

    # Check file is readable
    if [[ ! -r "$file" ]]; then
        echo "Error: PDF file not readable: $file" >&2
        return 1
    fi

    # Check file size (32MB limit for PDF API)
    local file_size
    file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    local max_size=$((32 * 1024 * 1024))  # 32MB

    if [[ $file_size -gt $max_size ]]; then
        local size_mb=$((file_size / 1024 / 1024))
        echo "Error: PDF file exceeds 32MB limit: $file (${size_mb}MB)" >&2
        return 1
    fi

    return 0
}

# =============================================================================
# Shared Conversion Cache System
# =============================================================================

# Maximum file size for content hash validation (10MB)
# Files larger than this skip hash verification when mtime changes
CACHE_HASH_SIZE_LIMIT=$((10 * 1024 * 1024))

# Generate a deterministic cache ID from absolute path
# Uses SHA-256 hash of the absolute path (first 16 characters)
# Arguments:
#   $1 - Source file path (will be resolved to absolute)
# Returns:
#   16-character hex cache ID (stdout)
generate_cache_id() {
    local source_path="$1"
    local abs_path

    # Resolve to absolute path
    if [[ "$source_path" == /* ]]; then
        abs_path="$source_path"
    else
        abs_path="$(cd "$(dirname "$source_path")" && pwd)/$(basename "$source_path")"
    fi

    # Hash the absolute path for cache ID (first 16 chars of SHA-256)
    echo "$abs_path" | shasum -a 256 | cut -c1-16
}

# Write cache metadata sidecar file
# Arguments:
#   $1 - Cached file path (the .meta file will be created alongside)
#   $2 - Source file absolute path
#   $3 - Conversion type (e.g., "office_to_pdf")
# Side effects:
#   Creates a .meta JSON file next to the cached file
write_cache_metadata() {
    local cached_file="$1"
    local source_path="$2"
    local conversion_type="$3"
    local meta_file="${cached_file}.meta"

    # Get source file stats
    local source_mtime source_size source_hash
    source_mtime=$(stat -f%m "$source_path" 2>/dev/null || stat -c%Y "$source_path" 2>/dev/null)
    source_size=$(stat -f%z "$source_path" 2>/dev/null || stat -c%s "$source_path" 2>/dev/null)

    # Only compute hash for files within size limit
    if [[ "$source_size" -le "$CACHE_HASH_SIZE_LIMIT" ]]; then
        source_hash="sha256:$(shasum -a 256 "$source_path" | cut -d' ' -f1)"
    else
        source_hash="skipped:file_too_large"
    fi

    # Get tool version if available
    local tool_version="unknown"
    if [[ "$conversion_type" == "office_to_pdf" ]] && command -v soffice >/dev/null 2>&1; then
        tool_version=$(soffice --version 2>/dev/null | head -1 || echo "LibreOffice")
    fi

    # Write metadata JSON
    cat > "$meta_file" <<EOF
{
  "source_path": "$source_path",
  "source_mtime": $source_mtime,
  "source_size": $source_size,
  "source_hash": "$source_hash",
  "conversion_type": "$conversion_type",
  "converted_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "tool_version": "$tool_version"
}
EOF
}

# Validate cache entry against source file
# Arguments:
#   $1 - Cached file path
# Returns:
#   0 if cache is valid, 1 if invalid or missing
validate_cache_entry() {
    local cached_file="$1"
    local meta_file="${cached_file}.meta"

    # Check cache and metadata exist
    [[ -f "$cached_file" && -f "$meta_file" ]] || return 1

    # Read metadata (using simple parsing since jq may not be available)
    local source_path source_mtime source_hash source_size
    source_path=$(grep '"source_path"' "$meta_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
    source_mtime=$(grep '"source_mtime"' "$meta_file" | sed 's/.*: *\([0-9]*\).*/\1/')
    source_size=$(grep '"source_size"' "$meta_file" | sed 's/.*: *\([0-9]*\).*/\1/')
    source_hash=$(grep '"source_hash"' "$meta_file" | sed 's/.*: *"\([^"]*\)".*/\1/')

    # Source must still exist
    [[ -f "$source_path" ]] || return 1

    # Fast path: mtime unchanged
    local current_mtime
    current_mtime=$(stat -f%m "$source_path" 2>/dev/null || stat -c%Y "$source_path" 2>/dev/null)
    [[ "$current_mtime" == "$source_mtime" ]] && return 0

    # Slow path: mtime changed, check size first
    local current_size
    current_size=$(stat -f%z "$source_path" 2>/dev/null || stat -c%s "$source_path" 2>/dev/null)

    # Size changed = definitely invalid
    [[ "$current_size" != "$source_size" ]] && return 1

    # For files within size limit, verify content hash
    if [[ "$current_size" -le "$CACHE_HASH_SIZE_LIMIT" && "$source_hash" != skipped:* ]]; then
        local current_hash
        current_hash="sha256:$(shasum -a 256 "$source_path" | cut -d' ' -f1)"
        [[ "$current_hash" == "$source_hash" ]] && return 0
    fi

    return 1  # Cache invalid (mtime changed, large file or hash mismatch)
}

# =============================================================================
# Microsoft Office File Conversion
# =============================================================================

# Check if LibreOffice soffice command is available
# Returns:
#   0 if available, 1 if not
check_soffice_available() {
    command -v soffice >/dev/null 2>&1
}

# Convert Microsoft Office file to PDF using LibreOffice
# Uses the shared project-level cache at $CACHE_DIR/conversions/office/
# Arguments:
#   $1 - Source Office file path (will be resolved to absolute)
# Returns:
#   Path to cached PDF file (stdout)
#   Returns 1 on error
# Requires:
#   CACHE_DIR global must be set (empty = no caching, convert to temp)
# Side effects:
#   Creates cache directory if needed
#   Writes converted PDF and .meta sidecar to cache
convert_office_to_pdf() {
    local source_file="$1"

    if [[ ! -f "$source_file" ]]; then
        echo "Error: Office file not found: $source_file" >&2
        return 1
    fi

    # Resolve to absolute path
    local abs_source
    if [[ "$source_file" == /* ]]; then
        abs_source="$source_file"
    else
        abs_source="$(cd "$(dirname "$source_file")" && pwd)/$(basename "$source_file")"
    fi

    local source_basename
    source_basename=$(basename "$abs_source")

    # Determine cache location and cached PDF path
    local cache_dir cached_pdf use_cache=true

    if [[ -n "$CACHE_DIR" ]]; then
        # Project cache available - use hash-based cache ID
        local cache_id
        cache_id=$(generate_cache_id "$abs_source")
        cache_dir="$CACHE_DIR/conversions/office"
        cached_pdf="$cache_dir/${cache_id}.pdf"
    else
        # No project cache (standalone task mode outside project)
        # Convert to temp, no caching
        use_cache=false
        cache_dir="${TMPDIR:-/tmp}/wireflow-conversion"
        cached_pdf="$cache_dir/${source_basename%.*}.pdf"
    fi

    # Create cache directory
    mkdir -p "$cache_dir"

    # Check cache validity (only if caching enabled)
    if $use_cache && validate_cache_entry "$cached_pdf"; then
        echo "$cached_pdf"
        return 0
    fi

    # Convert to PDF using LibreOffice in headless mode
    echo "  Converting Office file to PDF: $source_basename" >&2

    # Convert to temp directory first, then move to cache
    local temp_dir="${TMPDIR:-/tmp}/wireflow-soffice-$$"
    mkdir -p "$temp_dir"

    # Run soffice in headless mode
    # --convert-to pdf: Convert to PDF format
    # --outdir: Output directory for converted file
    # --headless: Run without GUI
    if soffice --convert-to pdf --outdir "$temp_dir" --headless "$abs_source" >/dev/null 2>&1; then
        local temp_pdf="$temp_dir/${source_basename%.*}.pdf"
        if [[ -f "$temp_pdf" ]]; then
            # Move to cache location
            mv "$temp_pdf" "$cached_pdf"
            rm -rf "$temp_dir"

            # Write metadata sidecar (only if caching enabled)
            if $use_cache; then
                write_cache_metadata "$cached_pdf" "$abs_source" "office_to_pdf"
            fi

            echo "$cached_pdf"
            return 0
        else
            rm -rf "$temp_dir"
            echo "Error: PDF conversion succeeded but output file not found" >&2
            return 1
        fi
    else
        rm -rf "$temp_dir"
        echo "Error: Failed to convert Office file to PDF: $source_file" >&2
        return 1
    fi
}

# Build a content block from a file (document or text type)
# Context and input files use "document" type (for citations support)
# Dependencies and other blocks use "text" type
# Arguments:
#   $1 - File path (required)
#   $2 - Block category: "context", "dependency", "input", or empty
#   $3 - Enable citations flag: "true" or "false" (for document blocks)
#   $4 - Additional metadata key (optional, e.g., "workflow")
#   $5 - Additional metadata value (optional)
# Returns:
#   JSON content block object (document or text type)
build_content_block() {
    local file="$1"
    local block_category="${2:-}"
    local enable_citations="${3:-false}"
    local meta_key="${4:-}"
    local meta_value="${5:-}"

    if [[ ! -f "$file" ]]; then
        echo "{}" >&2
        return 1
    fi

    # Get absolute path
    local abs_path
    abs_path=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")

    # Read file content
    local content
    content=$(cat "$file")

    # Preprocess Obsidian markdown files to resolve embeds
    if [[ "$file" == *.md || "$file" == *.markdown ]]; then
        if [[ -n "${PROJECT_ROOT:-}" ]]; then
            content=$(preprocess_obsidian_markdown "$content" "$abs_path" "$block_category" "$PROJECT_ROOT")
        fi
    fi

    # Extract title for document blocks
    local title
    title=$(extract_title_from_file "$file")

    # Determine if this should be a document block
    # Context and input files are always document type (for citations support)
    # Dependencies and system/task remain text type
    local use_document_type=false
    if [[ "$block_category" == "context" || "$block_category" == "input" ]]; then
        use_document_type=true
    fi

    if [[ "$use_document_type" == true ]]; then
        # Build "document" type block with citations support
        # Use "context" field for metadata (optional, for debugging)
        local context_metadata=""
        if [[ -n "$meta_key" && -n "$meta_value" ]]; then
            context_metadata="<metadata type=\"$block_category\" $meta_key=\"$meta_value\" source=\"$abs_path\"></metadata>"
        else
            context_metadata="<metadata type=\"$block_category\" source=\"$abs_path\"></metadata>"
        fi

        jq -n \
            --arg type "document" \
            --arg source_type "text" \
            --arg media_type "text/plain" \
            --arg data "$content" \
            --arg title "$title" \
            --arg context "$context_metadata" \
            --argjson enabled "$enable_citations" \
            '{
                type: $type,
                source: {
                    type: $source_type,
                    media_type: $media_type,
                    data: $data
                },
                title: $title,
                context: $context,
                citations: {enabled: $enabled}
            }'
    else
        # Build "text" type block (for dependencies, system, task)
        # Embed metadata as XML in text content
        local metadata_xml=""
        if [[ -n "$block_category" && -n "$meta_key" && -n "$meta_value" ]]; then
            metadata_xml="<metadata type=\"$block_category\" $meta_key=\"$meta_value\" source=\"$abs_path\"></metadata>\n\n"
        elif [[ -n "$block_category" ]]; then
            metadata_xml="<metadata type=\"$block_category\" source=\"$abs_path\"></metadata>\n\n"
        fi

        local full_text="${metadata_xml}${content}"

        jq -n \
            --arg type "text" \
            --arg text "$full_text" \
            '{
                type: $type,
                text: $text
            }'
    fi
}

# Build a document content block for PDF files
# Arguments:
#   $1 - PDF file path
#   $2 - Enable cache control: "true" or "false" (default: false)
# Returns:
#   JSON content block object with base64-encoded PDF
build_document_content_block() {
    local file="$1"
    local enable_cache="${2:-false}"

    if [[ ! -f "$file" ]]; then
        echo "{}" >&2
        return 1
    fi

    # Get absolute path
    local abs_path
    abs_path=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")

    # Validate PDF file
    if ! validate_pdf_file "$abs_path"; then
        echo "{}" >&2
        return 1
    fi

    # Base64 encode the PDF file
    local base64_data
    base64_data=$(base64 < "$abs_path" | tr -d '\n')

    # Build JSON content block using jq
    # Use printf to avoid issues with large base64 strings
    if [[ "$enable_cache" == "true" ]]; then
        printf '%s' "$base64_data" | jq -Rs \
            --arg type "document" \
            --arg source_type "base64" \
            --arg media_type "application/pdf" \
            '{
                type: $type,
                source: {
                    type: $source_type,
                    media_type: $media_type,
                    data: .
                },
                cache_control: {
                    type: "ephemeral"
                }
            }'
    else
        printf '%s' "$base64_data" | jq -Rs \
            --arg type "document" \
            --arg source_type "base64" \
            --arg media_type "application/pdf" \
            '{
                type: $type,
                source: {
                    type: $source_type,
                    media_type: $media_type,
                    data: .
                }
            }'
    fi
}

# =============================================================================
# JSON to XML Conversion (Optional Post-Processing)
# =============================================================================

# Helper: Generate indentation
_indent() {
    local level=$1
    printf '%*s' $((level * 2)) ''
}

# Helper: Check if string contains XML tags
_contains_xml() {
    local pattern='<[^>]+>'
    [[ "$1" =~ $pattern ]]
}

# Helper: Convert JSON value to pseudo-XML recursively
_json_to_pseudo_xml() {
    local json="$1"
    local level="${2:-0}"
    local key="$3"

    # Determine the type of JSON value
    local first_char="${json:0:1}"
    local last_char="${json: -1}"

    if [[ "$first_char" == "{" && "$last_char" == "}" ]]; then
        # Object
        if [[ -n "$key" ]]; then
            _indent "$level"
            echo "<$key>"
        fi

        # Parse object keys and values
        while IFS= read -r line; do
            local k="${line%%:*}"
            local v="${line#*:}"
            k="${k//\"/}"  # Remove quotes from key
            _json_to_pseudo_xml "$v" $((level + 1)) "$k"
        done < <(echo "$json" | jq -r 'to_entries | .[] | "\(.key):\(.value | @json)"')

        if [[ -n "$key" ]]; then
            _indent "$level"
            echo "</$key>"
        fi

    elif [[ "$first_char" == "[" && "$last_char" == "]" ]]; then
        # Array
        while IFS= read -r item; do
            _json_to_pseudo_xml "$item" "$level" "$key"
        done < <(echo "$json" | jq -c '.[]')

    elif [[ "$first_char" == "\"" ]]; then
        # String value
        local str_val
        str_val=$(echo "$json" | jq -r '.')

        if _contains_xml "$str_val"; then
            # XML string - add newlines for readability
            _indent "$level"
            echo "<$key>"
            echo "$str_val"
            _indent "$level"
            echo "</$key>"
        else
            # Regular string - inline
            _indent "$level"
            echo "<$key>$str_val</$key>"
        fi

    else
        # Number, boolean, or null
        local val
        val=$(echo "$json" | jq -r '.')
        _indent "$level"
        echo "<$key>$val</$key>"
    fi
}

# Convert JSON files to pseudo-XML (optional)
# Creates human-readable XML files alongside JSON for inspection/debugging
# Detects XML-like content in string values and preserves their structure
# Arguments:
#   $1 - workflow_dir: Directory containing JSON files
# Returns:
#   0 if conversion succeeded or jq unavailable (not an error)
#   1 if conversion failed (should not happen, silently ignored)
# Side effects:
#   Creates .xml files alongside .json files if jq available
# Note:
#   JSON files are canonical, XML files are convenience views only
convert_json_to_xml() {
    local workflow_dir="$1"

    # Check if jq is available (required for parsing)
    if ! command -v jq >/dev/null 2>&1; then
        return 0  # Not an error, just skip conversion
    fi

    # Silently convert files (don't announce unless debugging)
    local files=(
        "system-blocks"
        "user-blocks"
        "request"
        "document-map"
    )

    for base in "${files[@]}"; do
        local json_file="$workflow_dir/${base}.json"
        local xml_file="$workflow_dir/${base}.xml"

        if [[ -f "$json_file" ]]; then
            # Convert using custom pseudo-XML converter
            {
                echo "<root>"
                _json_to_pseudo_xml "$(<"$json_file")" 1
                echo "</root>"
            } > "$xml_file" 2>/dev/null || {
                # Conversion failed, remove partial file
                rm -f "$xml_file"
            }
        fi
    done

    return 0
}
