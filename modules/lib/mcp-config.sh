#!/bin/bash
# MCP Configuration Helpers for Claude Safe modules

CLAUDE_SAFE_DIR="${CLAUDE_SAFE_DIR:-$HOME/.claude-safe}"

# Get the path to Claude's MCP config file
get_mcp_config_path() {
    # The claude_token.json file is stored in the Docker volume
    # We need to access it via docker volume
    echo "/tmp/claude-safe-mcp-config.json"
}

# Read current MCP config from Docker volume
read_mcp_config() {
    local temp_file=$(get_mcp_config_path)

    # Extract config from Docker volume
    docker run --rm -v claude-data:/persist alpine cat /persist/claude_token.json 2>/dev/null > "$temp_file" || echo "{}" > "$temp_file"

    # Ensure it's valid JSON
    if ! jq empty "$temp_file" 2>/dev/null; then
        echo "{}" > "$temp_file"
    fi

    cat "$temp_file"
}

# Write MCP config back to Docker volume
write_mcp_config() {
    local config="$1"
    local temp_file=$(get_mcp_config_path)

    echo "$config" > "$temp_file"

    # Copy back to Docker volume
    docker run --rm -v claude-data:/persist -v "$temp_file:/tmp/config.json" alpine sh -c "cat /tmp/config.json > /persist/claude_token.json"
}

# Configure an MCP server from a module's mcp.json
configure_mcp_server() {
    local module_name="$1"
    local mcp_json_file="$2"

    if [ ! -f "$mcp_json_file" ]; then
        echo "MCP config file not found: $mcp_json_file"
        return 1
    fi

    # Read module's MCP config
    local module_mcp_config
    module_mcp_config=$(cat "$mcp_json_file")

    if ! echo "$module_mcp_config" | jq empty 2>/dev/null; then
        echo "Invalid JSON in $mcp_json_file"
        return 1
    fi

    # Read current Claude config
    local current_config
    current_config=$(read_mcp_config)

    # Ensure mcpServers key exists
    if ! echo "$current_config" | jq -e '.mcpServers' > /dev/null 2>&1; then
        current_config=$(echo "$current_config" | jq '. + {"mcpServers": {}}')
    fi

    # Merge module's MCP servers into current config
    local new_config
    new_config=$(echo "$current_config" | jq --argjson mcp "$module_mcp_config" '.mcpServers += $mcp')

    # Write back
    write_mcp_config "$new_config"

    echo "MCP server configured for module '$module_name'"
}

# Remove an MCP server configuration
remove_mcp_server() {
    local module_name="$1"

    # Read current Claude config
    local current_config
    current_config=$(read_mcp_config)

    # Check if mcpServers exists
    if ! echo "$current_config" | jq -e '.mcpServers' > /dev/null 2>&1; then
        return 0
    fi

    # Remove the module's server
    local new_config
    new_config=$(echo "$current_config" | jq "del(.mcpServers.$module_name)")

    # Write back
    write_mcp_config "$new_config"

    echo "MCP server removed for module '$module_name'"
}

# List configured MCP servers
list_mcp_servers() {
    local current_config
    current_config=$(read_mcp_config)

    echo "Configured MCP servers:"
    echo "$current_config" | jq -r '.mcpServers // {} | keys[]' 2>/dev/null || echo "  (none)"
}
