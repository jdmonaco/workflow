# =============================================================================
# Workflow API Functions
# =============================================================================
# API interaction layer for workflow CLI tool.
# Currently supports Anthropic Messages API.
# Future: Support for OpenAI, Mistral, local models, etc.
# =============================================================================

# Source utility functions if not already loaded
SCRIPT_LIB_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
if ! declare -f escape_json > /dev/null; then
    source "$SCRIPT_LIB_DIR/utils.sh"
fi

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
#
# Returns:
#   0 - Success (response written to output_file)
#   1 - API error or network failure
#
# Side effects:
#   Writes to output_file
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
        --argjson system "$system_blocks" \
        --argjson user_content "$user_blocks" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            temperature: $temperature,
            system: $system,
            messages: [
                {
                    role: "user",
                    content: $user_content
                }
            ]
        }'
    )

    # Execute request
    echo -n "Sending Messages API request... "

    local response
    response=$(curl -s https://api.anthropic.com/v1/messages \
        -H "content-type: application/json" \
        -H "x-api-key: ${params[api_key]}" \
        -H "anthropic-version: 2023-06-01" \
        -d "$json_payload")

    echo "done!"

    # Check for errors
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        echo "API Error:"
        echo "$response" | jq '.error'
        return 1
    fi

    # Extract and save response
    echo "$response" | jq -r '.content[0].text' > "${params[output_file]}"

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
#
# Returns:
#   0 - Success (response written to output_file)
#   1 - API error or network failure
#
# Side effects:
#   Writes to output_file
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
        --argjson system "$system_blocks" \
        --argjson user_content "$user_blocks" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            temperature: $temperature,
            system: $system,
            messages: [
                {
                    role: "user",
                    content: $user_content
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
    local error_flag="$(mktemp)"
    rm "$error_flag"  # Remove, we'll create it if error occurs

    # Stream response and parse SSE events
    curl -Ns https://api.anthropic.com/v1/messages \
        -H "content-type: application/json" \
        -H "x-api-key: ${params[api_key]}" \
        -H "anthropic-version: 2023-06-01" \
        -d "$json_payload" | while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Parse SSE format (lines start with "data: ")
        if [[ "$line" == data:* ]]; then
            json_data="${line#data: }"

            # Skip ping events
            [[ "$json_data" == "[DONE]" ]] && continue

            # Extract event type
            event_type=$(echo "$json_data" | jq -r '.type // empty')

            case "$event_type" in
                "content_block_delta")
                    # Extract and print text incrementally
                    delta_text=$(echo "$json_data" | jq -r '.delta.text // empty')
                    if [[ -n "$delta_text" ]]; then
                        printf '%s' "$delta_text"
                        printf '%s' "$delta_text" >> "${params[output_file]}"
                    fi
                    ;;
                "message_stop")
                    printf '\n'
                    ;;
                "error")
                    echo ""
                    echo "API Error:"
                    echo "$json_data" | jq '.error'
                    touch "$error_flag"  # Signal error
                    exit 1
                    ;;
            esac
        fi
    done

    # Check if error occurred in pipeline
    if [[ -f "$error_flag" ]]; then
        rm -f "$error_flag"
        return 1
    fi

    echo ""
    echo "---"

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
        --argjson system "$system_blocks" \
        --argjson user_content "$user_blocks" \
        '{
            model: $model,
            system: $system,
            messages: [
                {
                    role: "user",
                    content: $user_content
                }
            ]
        }')

    # Call count_tokens endpoint
    local response
    response=$(curl -s https://api.anthropic.com/v1/messages/count_tokens \
        -H "content-type: application/json" \
        -H "x-api-key: ${params[api_key]}" \
        -H "anthropic-version: 2023-06-01" \
        -d "$json_payload")

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
