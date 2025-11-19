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

    # Capitalize each word (sentence case)
    title=$(echo "$title" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

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

# Detect file type (text vs document/PDF vs image)
# Arguments:
#   $1 - File path
# Returns:
#   "text" for text files (default)
#   "document" for PDFs (future support)
#   "image" for supported image formats (jpg, png, gif, webp)
detect_file_type() {
    local file="$1"
    local extension="${file##*.}"

    # Convert to lowercase
    extension="${extension,,}"

    # Check file type by extension
    case "$extension" in
        # Image types (Vision API support)
        png|jpg|jpeg|gif|webp)
            echo "image"
            ;;
        # Document types (future support)
        pdf)
            echo "document"
            ;;
        # Text files (default)
        *)
            echo "text"
            ;;
    esac
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
        *)
            echo "image/jpeg"  # Default fallback
            ;;
    esac
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

# Cache and potentially resize image for API use
# Arguments:
#   $1 - source_file: Original image file (absolute path)
#   $2 - project_root: Project root directory
#   $3 - workflow_dir: Workflow directory for cache
# Returns:
#   Path to cached/resized image (or original if no resize needed)
cache_image() {
    local source_file="$1"
    local project_root="$2"
    local workflow_dir="$3"

    # Get dimensions
    local dimensions
    dimensions=$(get_image_dimensions "$source_file")
    if [[ -z "$dimensions" ]]; then
        # Can't get dimensions (ImageMagick not available), use original
        echo "$source_file"
        return 0
    fi

    local width height
    read -r width height <<< "$dimensions"

    # Check if resize needed
    if ! should_resize_image "$width" "$height"; then
        # No resize needed, use original
        echo "$source_file"
        return 0
    fi

    # Calculate relative path from project root
    local rel_path
    if [[ "$source_file" == "$project_root"/* ]]; then
        rel_path="${source_file#$project_root/}"
    else
        # File outside project, use basename in cache
        rel_path="external/$(basename "$source_file")"
    fi

    # Create cache path
    local cache_dir="$workflow_dir/cache"
    local cached_file="$cache_dir/$rel_path"

    # Check if already cached and up-to-date
    if [[ -f "$cached_file" ]]; then
        # Compare modification times
        if [[ "$cached_file" -nt "$source_file" ]]; then
            # Cached version is newer, reuse it
            echo "$cached_file"
            return 0
        fi
    fi

    # Calculate target dimensions
    local target_dims
    target_dims=$(calculate_target_dimensions "$width" "$height")
    local target_width target_height
    read -r target_width target_height <<< "$target_dims"

    # Resize and cache
    if resize_image "$source_file" "$cached_file" "$target_width" "$target_height"; then
        echo "  Resized image: ${width}x${height} → ${target_width}x${target_height} (cached)" >&2
        echo "$cached_file"
        return 0
    else
        # Resize failed, fall back to original
        echo "$source_file"
        return 1
    fi
}

# Build image content block for Vision API
# Arguments:
#   $1 - file: Image file path (absolute)
#   $2 - project_root: Project root directory
#   $3 - workflow_dir: Workflow directory (for cache)
# Returns:
#   JSON content block with type="image", base64-encoded data
# Note:
#   Images are NOT citable and do NOT get document indices
build_image_content_block() {
    local file="$1"
    local project_root="$2"
    local workflow_dir="$3"

    # Validate image
    if ! validate_image_file "$file"; then
        return 1
    fi

    # Cache and potentially resize image
    local image_file
    image_file=$(cache_image "$file" "$project_root" "$workflow_dir")

    # Get media type
    local media_type
    media_type=$(get_image_media_type "$image_file")

    # Base64 encode image
    local base64_data
    base64_data=$(base64 < "$image_file" | tr -d '\n')

    # Build image content block (Vision API format)
    # Note: No cache_control for images, no citations, no document index
    jq -n \
        --arg type "image" \
        --arg source_type "base64" \
        --arg media_type "$media_type" \
        --arg data "$base64_data" \
        '{
            type: $type,
            source: {
                type: $source_type,
                media_type: $media_type,
                data: $data
            }
        }'
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

# Build a document content block (placeholder for future PDF support)
# Arguments:
#   $1 - File path
#   $2 - Optional metadata (JSON object string)
# Returns:
#   JSON content block object
build_document_content_block() {
    local file="$1"
    local metadata="${2:-{}}"

    if [[ ! -f "$file" ]]; then
        echo "{}" >&2
        return 1
    fi

    # Get absolute path
    local abs_path
    abs_path=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")

    # For now, return error for non-text files
    # Future: implement base64 encoding for PDFs/images
    echo "Error: Document/PDF support not yet implemented" >&2

    # Return placeholder structure
    jq -n \
        --arg type "document" \
        --arg source "$abs_path" \
        --argjson metadata "$metadata" \
        '{
            type: $type,
            source: $source,
            metadata: ($metadata + {source: $source}),
            error: "Document support not yet implemented"
        }'
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
