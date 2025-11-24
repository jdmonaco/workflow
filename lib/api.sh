# =============================================================================
# Workflow API Functions
# =============================================================================
# API interaction layer for workflow CLI tool.
# Currently supports Anthropic Messages API.
# Future: Support for OpenAI, Mistral, local models, etc.
# =============================================================================

# =============================================================================
# Anthropic Provider Implementation
# =============================================================================

# Validate Anthropic API configuration
# Args:
#   $1 - API key (optional, uses ANTHROPIC_API_KEY env var if not provided)
# Returns:
#   0 - Valid configuration
#   1 - Missing or invalid API key
anthropic_validate() {
    local api_key="${1:-$ANTHROPIC_API_KEY}"

    # Check if empty string was explicitly passed
    if [[ $# -gt 0 && -z "$1" ]]; then
        echo "Error: ANTHROPIC_API_KEY environment variable is not set" >&2
        return 1
    fi

    if [[ -z "$api_key" ]]; then
        echo "Error: ANTHROPIC_API_KEY environment variable is not set" >&2
        return 1
    fi

    return 0
}

# Execute Anthropic Messages API request in single mode
# Single mode = one complete request/response cycle (NOT batch processing)
# Blocks until response received, then displays with less
#
# Args:
#   All arguments are key=value pairs:
#   api_key=...              - Anthropic API key
#   model=...                - Model name (e.g., "claude-sonnet-4-5")
#   max_tokens=...           - Maximum tokens to generate
#   temperature=...          - Temperature (0.0-1.0)
#   system_blocks_file=...   - Path to file containing JSON array of system content blocks
#   user_blocks_file=...     - Path to file containing JSON array of user content blocks
#   output_file=...          - Path to write response
#   enable_citations=...     - "true" or "false" (optional, default: false)
#   output_format=...        - Output format for citation formatting (optional, default: md)
#   doc_map_file=...         - Path to document index map JSON file (optional)
#
# Returns:
#   0 - Success (response written to output_file)
#   1 - API error or network failure
#
# Side effects:
#   Writes to output_file
#   Writes citations.md if citations exist
#   Displays response with less
#   Outputs progress messages to stdout
anthropic_execute_single() {
    # Parse key=value arguments into associative array
    local -A params
    while [[ $# -gt 0 ]]; do
        IFS='=' read -r key value <<< "$1"
        params["$key"]="$value"
        shift
    done

    # Read JSON from files
    local system_blocks
    local user_blocks
    system_blocks=$(<"${params[system_blocks_file]}")
    user_blocks=$(<"${params[user_blocks_file]}")

    # Build JSON payload with content blocks
    local json_payload
    json_payload=$(jq -n \
        --arg model "${params[model]}" \
        --argjson max_tokens "${params[max_tokens]}" \
        --argjson temperature "${params[temperature]}" \
        --slurpfile system "${params[system_blocks_file]}" \
        --slurpfile user_content "${params[user_blocks_file]}" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            temperature: $temperature,
            system: $system[0],
            messages: [
                {
                    role: "user",
                    content: $user_content[0]
                }
            ]
        }'
    )

    # Execute request
    echo -n "Sending Messages API request... "

    # Pass JSON payload via stdin to avoid "Argument list too long" with large images
    local response
    response=$(echo "$json_payload" | curl -s https://api.anthropic.com/v1/messages \
        -H "content-type: application/json" \
        -H "x-api-key: ${params[api_key]}" \
        -H "anthropic-version: 2023-06-01" \
        -d @-)

    echo "done!"

    # Check for errors
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        echo "API Error:"
        echo "$response" | jq '.error'
        return 1
    fi

    # Process citations if enabled
    local enable_citations="${params[enable_citations]:-false}"
    local output_format="${params[output_format]:-md}"
    local doc_map_file="${params[doc_map_file]:-}"

    if [[ "$enable_citations" == "true" ]]; then
        # Parse citations from response
        local parsed
        parsed=$(parse_citations_response "$response" "$doc_map_file")

        # Format for output
        local formatted
        formatted=$(format_citations_output "$parsed" "$output_format")

        # Save formatted output
        echo "$formatted" > "${params[output_file]}"

        # Write citations sidecar file and get path
        CITATIONS_FILE_PATH=$(write_citations_sidecar "$parsed" "$doc_map_file" "${params[output_file]}")

        # For non-stdout mode, report the file location
        if [[ -n "${params[output_file]}" && "${params[output_file]}" != "/dev/stdout" ]]; then
            echo "Citations saved to: $CITATIONS_FILE_PATH" >&2
        fi
    else
        # No citations - extract first text block as before
        echo "$response" | jq -r '.content[0].text' > "${params[output_file]}"
    fi

    # Display with less
    less "${params[output_file]}"

    return 0
}

# Execute Anthropic Messages API request in streaming mode
# Streams response in real-time using Server-Sent Events (SSE)
#
# Args:
#   All arguments are key=value pairs (same as anthropic_execute_single):
#   api_key, model, max_tokens, temperature
#   system_blocks_file, user_blocks_file, output_file
#   enable_citations=...     - "true" or "false" (optional, default: false)
#   output_format=...        - Output format for citation formatting (optional, default: md)
#   doc_map_file=...         - Path to document index map JSON file (optional)
#
# Returns:
#   0 - Success (response written to output_file)
#   1 - API error or network failure
#
# Side effects:
#   Writes to output_file
#   Writes citations.md if citations exist
#   Outputs streaming text to stdout in real-time
#   Outputs progress messages
anthropic_execute_stream() {
    # Parse key=value arguments into associative array
    local -A params
    while [[ $# -gt 0 ]]; do
        IFS='=' read -r key value <<< "$1"
        params["$key"]="$value"
        shift
    done

    local enable_citations="${params[enable_citations]:-false}"
    local output_format="${params[output_format]:-md}"
    local doc_map_file="${params[doc_map_file]:-}"

    # Read JSON from files
    local system_blocks
    local user_blocks
    system_blocks=$(<"${params[system_blocks_file]}")
    user_blocks=$(<"${params[user_blocks_file]}")

    # Build JSON payload with content blocks
    local json_payload
    json_payload=$(jq -n \
        --arg model "${params[model]}" \
        --argjson max_tokens "${params[max_tokens]}" \
        --argjson temperature "${params[temperature]}" \
        --slurpfile system "${params[system_blocks_file]}" \
        --slurpfile user_content "${params[user_blocks_file]}" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            temperature: $temperature,
            system: $system[0],
            messages: [
                {
                    role: "user",
                    content: $user_content[0]
                }
            ]
        }'
    )

    # Add streaming flag to payload
    json_payload=$(echo "$json_payload" | jq '. + {stream: true}')

    # Execute streaming request
    echo "Sending Messages API request (streaming)..."
    echo "---"
    echo ""

    # Initialize output file
    > "${params[output_file]}"

    # Use error flag file to communicate from pipeline subshell
    # Empty file = no error; write to it on error
    local error_flag="$(mktemp)"
    : > "$error_flag"

    # For citations: track events in temp file
    local events_file=""
    if [[ "$enable_citations" == "true" ]]; then
        events_file=$(mktemp)
        > "$events_file"
    fi

    # Stream response and parse SSE events
    # Pass JSON payload via stdin to avoid "Argument list too long" with large images
    echo "$json_payload" | curl -Ns https://api.anthropic.com/v1/messages \
        -H "content-type: application/json" \
        -H "x-api-key: ${params[api_key]}" \
        -H "anthropic-version: 2023-06-01" \
        -d @- | while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Parse SSE format (lines start with "data: ")
        if [[ "$line" == data:* ]]; then
            json_data="${line#data: }"

            # Skip ping events
            [[ "$json_data" == "[DONE]" ]] && continue

            # Save event for citations post-processing if enabled
            if [[ "$enable_citations" == "true" && -n "$events_file" ]]; then
                echo "$json_data" >> "$events_file"
            fi

            # Extract event type
            event_type=$(echo "$json_data" | jq -r '.type // empty')

            case "$event_type" in
                "content_block_delta")
                    # Check delta type (may not be present in all responses)
                    delta_type=$(echo "$json_data" | jq -r '.delta.type // empty')

                    # Handle text deltas (both with and without explicit type)
                    if [[ -z "$delta_type" || "$delta_type" == "text_delta" ]]; then
                        # Extract and print text incrementally
                        delta_text=$(echo "$json_data" | jq -r '.delta.text // empty')
                        if [[ -n "$delta_text" ]]; then
                            printf '%s' "$delta_text"
                            printf '%s' "$delta_text" >> "${params[output_file]}"
                        fi
                    fi
                    # Note: citations_delta events are logged but not processed inline
                    ;;
                "message_stop")
                    printf '\n'
                    ;;
                "error")
                    echo ""
                    echo "API Error:"
                    echo "$json_data" | jq '.error'
                    echo "error" > "$error_flag"  # Signal error
                    exit 1
                    ;;
            esac
        fi
    done

    # Check if error occurred in pipeline (non-empty file = error)
    if [[ -s "$error_flag" ]]; then
        rm -f "$error_flag"
        return 1
    fi
    rm -f "$error_flag"

    echo ""
    echo "---"

    # Post-process citations if enabled
    if [[ "$enable_citations" == "true" && -f "$events_file" ]]; then
        echo ""
        echo "Processing citations..."

        # Reconstruct response content array from streaming events
        local content_blocks="[]"
        local current_block_index=-1
        local current_block_text=""
        local current_block_citations="[]"

        while IFS= read -r event; do
            local event_type
            event_type=$(echo "$event" | jq -r '.type // empty')

            case "$event_type" in
                "content_block_start")
                    # Start new content block
                    current_block_index=$(echo "$event" | jq -r '.index')
                    current_block_text=""
                    current_block_citations="[]"
                    ;;
                "content_block_delta")
                    local delta_type
                    delta_type=$(echo "$event" | jq -r '.delta.type // empty')

                    if [[ "$delta_type" == "text_delta" ]]; then
                        # Accumulate text
                        local text_delta
                        text_delta=$(echo "$event" | jq -r '.delta.text // empty')
                        current_block_text+="$text_delta"
                    elif [[ "$delta_type" == "citations_delta" ]]; then
                        # Accumulate citation
                        local citation
                        citation=$(echo "$event" | jq '.delta.citation')
                        current_block_citations=$(echo "$current_block_citations" | jq ". += [$citation]")
                    fi
                    ;;
                "content_block_stop")
                    # Finalize current block
                    local block
                    if [[ $(echo "$current_block_citations" | jq 'length') -gt 0 ]]; then
                        # Block has citations
                        block=$(jq -n \
                            --arg text "$current_block_text" \
                            --argjson citations "$current_block_citations" \
                            '{type: "text", text: $text, citations: $citations}')
                    else
                        # Block without citations
                        block=$(jq -n \
                            --arg text "$current_block_text" \
                            '{type: "text", text: $text}')
                    fi
                    content_blocks=$(echo "$content_blocks" | jq ". += [$block]")
                    ;;
            esac
        done < "$events_file"

        # Build mock response structure
        local mock_response
        mock_response=$(jq -n --argjson content "$content_blocks" '{content: $content}')

        # Parse and format citations
        local parsed
        parsed=$(parse_citations_response "$mock_response" "$doc_map_file")

        local formatted
        formatted=$(format_citations_output "$parsed" "$output_format")

        # Overwrite output file with formatted version
        echo "$formatted" > "${params[output_file]}"

        # Write citations sidecar file and get path
        CITATIONS_FILE_PATH=$(write_citations_sidecar "$parsed" "$doc_map_file" "${params[output_file]}")

        # For non-stdout mode, report the file location
        if [[ -n "${params[output_file]}" && "${params[output_file]}" != "/dev/stdout" ]]; then
            echo "Citations saved to: $CITATIONS_FILE_PATH" >&2
        fi

        # Cleanup events file
        rm -f "$events_file"

        echo "Citations processed successfully"
    fi

    return 0
}

# Count tokens using Anthropic's count_tokens API endpoint
# Returns exact token counts for system and user messages
#
# Args:
#   All arguments are key=value pairs:
#   api_key=...              - Anthropic API key
#   model=...                - Model name
#   system_blocks_file=...   - Path to file containing JSON array of system content blocks
#   user_blocks_file=...     - Path to file containing JSON array of user content blocks
#
# Returns:
#   0 - Success (outputs JSON with token counts)
#   1 - API error or network failure
#
# Outputs to stdout:
#   JSON object with: {input_tokens: N}
anthropic_count_tokens() {
    # Parse key=value arguments into associative array
    local -A params
    while [[ $# -gt 0 ]]; do
        IFS='=' read -r key value <<< "$1"
        params["$key"]="$value"
        shift
    done

    # Build JSON payload (same structure as Messages API)
    # Read JSON from files
    local system_blocks
    local user_blocks
    system_blocks=$(<"${params[system_blocks_file]}")
    user_blocks=$(<"${params[user_blocks_file]}")

    local json_payload
    json_payload=$(jq -n \
        --arg model "${params[model]}" \
        --slurpfile system "${params[system_blocks_file]}" \
        --slurpfile user_content "${params[user_blocks_file]}" \
        '{
            model: $model,
            system: $system[0],
            messages: [
                {
                    role: "user",
                    content: $user_content[0]
                }
            ]
        }')

    # Call count_tokens endpoint
    # Pass JSON payload via stdin to avoid "Argument list too long" with large images
    local response
    response=$(echo "$json_payload" | curl -s https://api.anthropic.com/v1/messages/count_tokens \
        -H "content-type: application/json" \
        -H "x-api-key: ${params[api_key]}" \
        -H "anthropic-version: 2023-06-01" \
        -d @-)

    # Check for errors
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        echo "Token counting API Error:" >&2
        echo "$response" | jq '.error' >&2
        return 1
    fi

    # Output token count result
    echo "$response"
    return 0
}

# =============================================================================
# Citation Processing
# =============================================================================

# Parse citations from API response and build reference list
# Arguments:
#   $1 - Response JSON (complete API response)
#   $2 - Document index map file (JSON: [{index: N, source: "...", title: "..."}])
# Returns:
#   0 on success, 1 on error
# Outputs to stdout:
#   JSON object: {text: "formatted text", citations: [{...}]}
parse_citations_response() {
    local response_json="$1"
    local doc_map_file="$2"

    # Extract content array from response
    local content_array
    content_array=$(echo "$response_json" | jq '.content')

    if [[ -z "$content_array" || "$content_array" == "null" ]]; then
        echo '{"text": "", "citations": []}'
        return 1
    fi

    # Load document index map
    local doc_map="{}"
    if [[ -n "$doc_map_file" && -f "$doc_map_file" ]]; then
        doc_map=$(<"$doc_map_file")
    fi

    # Process content blocks and build citations list
    local formatted_text=""
    local citation_num=1
    local citations_list="[]"

    # Iterate through content blocks
    local num_blocks
    num_blocks=$(echo "$content_array" | jq 'length')

    for ((i=0; i<num_blocks; i++)); do
        local block
        block=$(echo "$content_array" | jq ".[$i]")

        local block_type
        block_type=$(echo "$block" | jq -r '.type')

        if [[ "$block_type" == "text" ]]; then
            local text
            text=$(echo "$block" | jq -r '.text')

            # Check if block has citations
            local has_citations
            has_citations=$(echo "$block" | jq 'has("citations")')

            if [[ "$has_citations" == "true" ]]; then
                # Add citation marker to text
                formatted_text+="${text}[^${citation_num}]"

                # Extract citation details
                local citations
                citations=$(echo "$block" | jq '.citations')

                # Add to citations list (could have multiple citations per block)
                local num_citations
                num_citations=$(echo "$citations" | jq 'length')

                for ((j=0; j<num_citations; j++)); do
                    local citation
                    citation=$(echo "$citations" | jq ".[$j]")

                    # Add citation number
                    citation=$(echo "$citation" | jq ". + {citation_number: $citation_num}")

                    # Add to list
                    citations_list=$(echo "$citations_list" | jq ". += [$citation]")

                    ((citation_num++))
                done
            else
                # No citations, just add text
                formatted_text+="$text"
            fi
        fi
    done

    # Return formatted text and citations
    jq -n \
        --arg text "$formatted_text" \
        --argjson citations "$citations_list" \
        '{text: $text, citations: $citations}'
}

# Format citations for specific output format
# Arguments:
#   $1 - Parsed citations JSON (from parse_citations_response)
#   $2 - Output format (md, txt, html, json, etc.)
# Returns:
#   Formatted output text with citations
format_citations_output() {
    local citations_json="$1"
    local output_format="$2"

    local text
    text=$(echo "$citations_json" | jq -r '.text')

    local citations
    citations=$(echo "$citations_json" | jq '.citations')

    local num_citations
    num_citations=$(echo "$citations" | jq 'length')

    # If no citations, return text as-is
    if [[ $num_citations -eq 0 ]]; then
        echo "$text"
        return 0
    fi

    # Build reference section based on format
    local references=""

    case "$output_format" in
        md|markdown)
            # Markdown footnotes
            references="\n\n"
            for ((i=0; i<num_citations; i++)); do
                local citation
                citation=$(echo "$citations" | jq ".[$i]")

                local num
                num=$(echo "$citation" | jq -r '.citation_number')

                local doc_title
                doc_title=$(echo "$citation" | jq -r '.document_title // "Unknown Document"')

                local citation_type
                citation_type=$(echo "$citation" | jq -r '.type')

                # Format location based on citation type
                local location=""
                case "$citation_type" in
                    char_location)
                        local start_char
                        start_char=$(echo "$citation" | jq -r '.start_char_index')
                        local end_char
                        end_char=$(echo "$citation" | jq -r '.end_char_index')
                        location="chars $start_char-$end_char"
                        ;;
                    page_location)
                        local start_page
                        start_page=$(echo "$citation" | jq -r '.start_page_number')
                        local end_page
                        end_page=$(echo "$citation" | jq -r '.end_page_number')
                        location="pages $start_page-$end_page"
                        ;;
                    content_block_location)
                        local start_block
                        start_block=$(echo "$citation" | jq -r '.start_block_index')
                        local end_block
                        end_block=$(echo "$citation" | jq -r '.end_block_index')
                        location="blocks $start_block-$end_block"
                        ;;
                esac

                references+="[^${num}]: ${doc_title} ($location)\n"
            done
            ;;

        txt|text)
            # Plain text numbered references
            references="\n\nReferences:\n"
            for ((i=0; i<num_citations; i++)); do
                local citation
                citation=$(echo "$citations" | jq ".[$i]")

                local num
                num=$(echo "$citation" | jq -r '.citation_number')

                local doc_title
                doc_title=$(echo "$citation" | jq -r '.document_title // "Unknown Document"')

                local citation_type
                citation_type=$(echo "$citation" | jq -r '.type')

                local location=""
                case "$citation_type" in
                    char_location)
                        local start_char
                        start_char=$(echo "$citation" | jq -r '.start_char_index')
                        local end_char
                        end_char=$(echo "$citation" | jq -r '.end_char_index')
                        location="chars $start_char-$end_char"
                        ;;
                    page_location)
                        local start_page
                        start_page=$(echo "$citation" | jq -r '.start_page_number')
                        local end_page
                        end_page=$(echo "$citation" | jq -r '.end_page_number')
                        location="pages $start_page-$end_page"
                        ;;
                    content_block_location)
                        local start_block
                        start_block=$(echo "$citation" | jq -r '.start_block_index')
                        local end_block
                        end_block=$(echo "$citation" | jq -r '.end_block_index')
                        location="blocks $start_block-$end_block"
                        ;;
                esac

                references+="[${num}] ${doc_title} ($location)\n"
            done
            ;;

        html)
            # HTML with superscript and anchor links
            # Replace [^N] with <sup><a href="#cite-N">[N]</a></sup>
            local html_text="$text"
            for ((i=0; i<num_citations; i++)); do
                local citation
                citation=$(echo "$citations" | jq ".[$i]")

                local num
                num=$(echo "$citation" | jq -r '.citation_number')

                html_text="${html_text//\[\^${num}\]/<sup><a href=\"\#cite-${num}\">[${num}]<\/a><\/sup>}"
            done

            references="\n\n<div class=\"references\">\n<h2>References</h2>\n<ol>\n"
            for ((i=0; i<num_citations; i++)); do
                local citation
                citation=$(echo "$citations" | jq ".[$i]")

                local num
                num=$(echo "$citation" | jq -r '.citation_number')

                local doc_title
                doc_title=$(echo "$citation" | jq -r '.document_title // "Unknown Document"')

                local citation_type
                citation_type=$(echo "$citation" | jq -r '.type')

                local location=""
                case "$citation_type" in
                    char_location)
                        local start_char
                        start_char=$(echo "$citation" | jq -r '.start_char_index')
                        local end_char
                        end_char=$(echo "$citation" | jq -r '.end_char_index')
                        location="chars $start_char-$end_char"
                        ;;
                    page_location)
                        local start_page
                        start_page=$(echo "$citation" | jq -r '.start_page_number')
                        local end_page
                        end_page=$(echo "$citation" | jq -r '.end_page_number')
                        location="pages $start_page-$end_page"
                        ;;
                    content_block_location)
                        local start_block
                        start_block=$(echo "$citation" | jq -r '.start_block_index')
                        local end_block
                        end_block=$(echo "$citation" | jq -r '.end_block_index')
                        location="blocks $start_block-$end_block"
                        ;;
                esac

                references+="<li id=\"cite-${num}\">${doc_title} ($location)</li>\n"
            done
            references+="</ol>\n</div>"

            text="$html_text"
            ;;

        json)
            # For JSON, preserve structured format - return as-is
            echo "$citations_json"
            return 0
            ;;

        *)
            # Default: simple inline references
            references="\n\nReferences:\n"
            for ((i=0; i<num_citations; i++)); do
                local citation
                citation=$(echo "$citations" | jq ".[$i]")

                local num
                num=$(echo "$citation" | jq -r '.citation_number')

                local doc_title
                doc_title=$(echo "$citation" | jq -r '.document_title // "Unknown Document"')

                references+="[Ref ${num}] ${doc_title}\n"
            done
            ;;
    esac

    # Return text with references appended
    echo -e "${text}${references}"
}

# Write citations details to sidecar file
# Arguments:
#   $1 - Parsed citations JSON (from parse_citations_response)
#   $2 - Document index map file (JSON array)
#   $3 - Output file path (for sidecar file)
# Returns:
#   0 on success
# Side effects:
#   Writes citations.md file next to output file
write_citations_sidecar() {
    local citations_json="$1"
    local doc_map_file="$2"
    local output_file="$3"

    local citations
    citations=$(echo "$citations_json" | jq '.citations')

    local num_citations
    num_citations=$(echo "$citations" | jq 'length')

    # Skip if no citations
    if [[ $num_citations -eq 0 ]]; then
        return 0
    fi

    # Determine sidecar file path
    local sidecar_file
    if [[ -n "$output_file" && "$output_file" != "/dev/stdout" ]]; then
        local output_dir
        output_dir=$(dirname "$output_file")
        sidecar_file="$output_dir/citations.md"
    else
        # Stdout mode - use temp file (will be output to stdout by caller)
        sidecar_file=$(mktemp -t citations.XXXXXX.md)
    fi

    # Load document map if available
    local doc_map="[]"
    if [[ -n "$doc_map_file" && -f "$doc_map_file" ]]; then
        doc_map=$(<"$doc_map_file")
    fi

    # Build citations markdown
    {
        echo "# Citations"
        echo ""

        for ((i=0; i<num_citations; i++)); do
            local citation
            citation=$(echo "$citations" | jq ".[$i]")

            local num
            num=$(echo "$citation" | jq -r '.citation_number')

            local cited_text
            cited_text=$(echo "$citation" | jq -r '.cited_text // ""')

            local doc_title
            doc_title=$(echo "$citation" | jq -r '.document_title // "Unknown Document"')

            local doc_index
            doc_index=$(echo "$citation" | jq -r '.document_index')

            local citation_type
            citation_type=$(echo "$citation" | jq -r '.type')

            # Get source path from document map
            local source_path
            source_path=$(echo "$doc_map" | jq -r ".[] | select(.index == $doc_index) | .source // \"\"")

            echo "${num}. \"${cited_text}\""
            echo "   - Document: ${doc_title}"
            [[ -n "$source_path" ]] && echo "   - Source: ${source_path}"

            # Format location based on citation type
            case "$citation_type" in
                char_location)
                    local start_char
                    start_char=$(echo "$citation" | jq -r '.start_char_index')
                    local end_char
                    end_char=$(echo "$citation" | jq -r '.end_char_index')
                    echo "   - Location: chars ${start_char}-${end_char}"
                    ;;
                page_location)
                    local start_page
                    start_page=$(echo "$citation" | jq -r '.start_page_number')
                    local end_page
                    end_page=$(echo "$citation" | jq -r '.end_page_number')
                    echo "   - Location: pages ${start_page}-${end_page}"
                    ;;
                content_block_location)
                    local start_block
                    start_block=$(echo "$citation" | jq -r '.start_block_index')
                    local end_block
                    end_block=$(echo "$citation" | jq -r '.end_block_index')
                    echo "   - Location: blocks ${start_block}-${end_block}"
                    ;;
            esac

            echo "   - Type: ${citation_type}"
            echo ""
        done
    } > "$sidecar_file"

    # Return the sidecar file path for caller to handle
    echo "$sidecar_file"
    return 0
}
