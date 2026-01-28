#!/bin/bash
# Module Manager - Core functions for Claude Safe module system

# Configuration
CLAUDE_SAFE_DIR="${CLAUDE_SAFE_DIR:-$HOME/.claude-safe}"
MODULES_DIR="${MODULES_DIR:-$CLAUDE_SAFE_DIR/modules}"
ENABLED_MODULES_FILE="$CLAUDE_SAFE_DIR/enabled-modules"

# UI Helper - Print a header box
print_header() {
    local title="$1"
    local width=60
    local title_len=${#title}
    local padding=$(((width - title_len) / 2))
    local padding_right=$((width - title_len - padding))

    echo ""
    echo "╔$(printf '═%.0s' $(seq 1 $width))╗"
    printf "║%*s%s%*s║\n" $padding "" "$title" $padding_right ""
    echo "╚$(printf '═%.0s' $(seq 1 $width))╝"
    echo ""
}

# UI Helper - Print a footer line
print_footer() {
    echo ""
    echo "$(printf '═%.0s' $(seq 1 62))"
}

# UI Helper - Print success message
print_success() {
    echo "✓ $1"
}

# UI Helper - Print info message
print_info() {
    echo "  • $1"
}

# Ensure directories exist
ensure_dirs() {
    mkdir -p "$CLAUDE_SAFE_DIR"
    touch "$ENABLED_MODULES_FILE"
}

# List all available modules
list_available_modules() {
    ensure_dirs

    print_header "AVAILABLE MODULES"

    local found=0
    for module_dir in "$MODULES_DIR"/*/; do
        [ -d "$module_dir" ] || continue
        local module_name=$(basename "$module_dir")

        # Skip lib and template directories
        [[ "$module_name" == "lib" || "$module_name" == "_template" ]] && continue

        local conf_file="$module_dir/module.conf"
        [ -f "$conf_file" ] || continue

        # Source module config
        source "$conf_file"

        local status_icon="○"
        local status_text="disabled"
        if is_module_enabled "$module_name"; then
            status_icon="●"
            status_text="enabled"
        fi

        printf "  %s %-12s  %s\n" "$status_icon" "$module_name" "${MODULE_DESCRIPTION:-No description}"
        found=1
    done

    if [ "$found" -eq 0 ]; then
        echo "  No modules found."
    fi

    echo ""
    echo "  ● = enabled    ○ = disabled"
    print_footer
}

# Check if a module is enabled
is_module_enabled() {
    local module_name="$1"
    ensure_dirs
    grep -qx "$module_name" "$ENABLED_MODULES_FILE" 2>/dev/null
}

# Get list of enabled modules
get_enabled_modules() {
    ensure_dirs
    cat "$ENABLED_MODULES_FILE" 2>/dev/null | grep -v '^$' || true
}

# Enable a module
enable_module() {
    local module_name="$1"
    ensure_dirs

    local module_dir="$MODULES_DIR/$module_name"

    if [ ! -d "$module_dir" ]; then
        echo "Error: Module '$module_name' not found."
        return 1
    fi

    if is_module_enabled "$module_name"; then
        echo "Module '$module_name' is already enabled."
        return 0
    fi

    local conf_file="$module_dir/module.conf"
    if [ ! -f "$conf_file" ]; then
        echo "Error: Module '$module_name' is missing module.conf"
        return 1
    fi

    # Source module config
    source "$conf_file"

    print_header "ENABLE MODULE: ${MODULE_DISPLAY_NAME:-$module_name}"

    # Run enable hook if exists
    local enable_script="$module_dir/enable.sh"
    if [ -f "$enable_script" ] && [ -x "$enable_script" ]; then
        if ! (cd "$module_dir" && bash "$enable_script"); then
            echo "Error: Enable hook failed."
            return 1
        fi
    fi

    # Configure MCP server
    if [ -f "$module_dir/mcp.json" ]; then
        echo "Configuring MCP server..."
        source "$MODULES_DIR/lib/mcp-config.sh"
        if ! configure_mcp_server "$module_name" "$module_dir/mcp.json"; then
            echo "Error: Failed to configure MCP server."
            return 1
        fi
    fi

    # Add to enabled modules
    echo "$module_name" >>"$ENABLED_MODULES_FILE"

    print_footer
    print_success "Module '${MODULE_DISPLAY_NAME:-$module_name}' enabled successfully."
    echo ""
}

# Disable a module
disable_module() {
    local module_name="$1"
    ensure_dirs

    local module_dir="$MODULES_DIR/$module_name"

    if [ ! -d "$module_dir" ]; then
        echo "Error: Module '$module_name' not found."
        return 1
    fi

    if ! is_module_enabled "$module_name"; then
        echo "Module '$module_name' is not enabled."
        return 0
    fi

    # Source module config
    local conf_file="$module_dir/module.conf"
    [ -f "$conf_file" ] && source "$conf_file"

    print_header "DISABLE MODULE: ${MODULE_DISPLAY_NAME:-$module_name}"

    # Stop container if running
    echo "Stopping container..."
    stop_module_container "$module_name"

    # Run disable hook if exists
    local disable_script="$module_dir/disable.sh"
    if [ -f "$disable_script" ] && [ -x "$disable_script" ]; then
        (cd "$module_dir" && bash "$disable_script") || true
    fi

    # Remove MCP configuration
    echo "Removing MCP configuration..."
    source "$MODULES_DIR/lib/mcp-config.sh"
    remove_mcp_server "$module_name"

    # Remove from enabled modules
    local temp_file=$(mktemp)
    grep -vx "$module_name" "$ENABLED_MODULES_FILE" >"$temp_file" 2>/dev/null || true
    mv "$temp_file" "$ENABLED_MODULES_FILE"

    print_footer
    print_success "Module '${MODULE_DISPLAY_NAME:-$module_name}' disabled."
    print_info "Docker image kept for fast re-enable"
    print_info "Use --remove to fully uninstall"
    echo ""
}

# Start a module's container
start_module_container() {
    local module_name="$1"
    local workspace_dir="$2"

    local module_dir="$MODULES_DIR/$module_name"
    local compose_file="$module_dir/docker-compose.yml"

    if [ ! -f "$compose_file" ]; then
        echo "Warning: No docker-compose.yml for module '$module_name'"
        return 0
    fi

    # Source module config for environment variables
    local conf_file="$module_dir/module.conf"
    [ -f "$conf_file" ] && source "$conf_file"

    echo "Starting $module_name container..."

    # Export workspace directory for compose file
    export WORKSPACE_DIR="$workspace_dir"
    export CLAUDE_SAFE_DIR="$CLAUDE_SAFE_DIR"

    if ! docker compose -f "$compose_file" -p "claude-safe-$module_name" up -d; then
        echo "Failed to start $module_name container."
        return 1
    fi

    # Wait for health check if specified
    if [ -n "$MODULE_MCP_URL" ]; then
        echo "Waiting for $module_name to be ready..."
        # Extract port from URL (e.g., http://localhost:9121/sse -> 9121)
        local port=$(echo "$MODULE_MCP_URL" | sed -n 's|.*://[^:]*:\([0-9]*\).*|\1|p')
        local retries=30
        while [ $retries -gt 0 ]; do
            # Check if port is open using bash's built-in /dev/tcp (no external tools needed)
            if (echo >/dev/tcp/localhost/$port) 2>/dev/null; then
                echo "$module_name is ready."
                return 0
            fi
            sleep 1
            retries=$((retries - 1))
        done
        echo "Warning: $module_name health check timed out (may still be starting)."
    fi

    return 0
}

# Stop a module's container
stop_module_container() {
    local module_name="$1"

    local module_dir="$MODULES_DIR/$module_name"
    local compose_file="$module_dir/docker-compose.yml"

    if [ ! -f "$compose_file" ]; then
        return 0
    fi

    echo "Stopping $module_name container..."
    docker compose -f "$compose_file" -p "claude-safe-$module_name" down 2>/dev/null || true
}

# Remove a module completely (image + volumes)
remove_module() {
    local module_name="$1"
    ensure_dirs

    local module_dir="$MODULES_DIR/$module_name"

    if [ ! -d "$module_dir" ]; then
        echo "Error: Module '$module_name' not found."
        return 1
    fi

    # Source module config
    local conf_file="$module_dir/module.conf"
    if [ ! -f "$conf_file" ]; then
        echo "Error: Module '$module_name' is missing module.conf"
        return 1
    fi
    source "$conf_file"

    print_header "REMOVE MODULE: ${MODULE_DISPLAY_NAME:-$module_name}"

    # Disable first if enabled (stops container, removes MCP config)
    if is_module_enabled "$module_name"; then
        echo "Disabling module first..."
        # Inline disable to avoid duplicate headers
        stop_module_container "$module_name"
        local disable_script="$module_dir/disable.sh"
        if [ -f "$disable_script" ] && [ -x "$disable_script" ]; then
            (cd "$module_dir" && bash "$disable_script") || true
        fi
        source "$MODULES_DIR/lib/mcp-config.sh"
        remove_mcp_server "$module_name"
        local temp_file=$(mktemp)
        grep -vx "$module_name" "$ENABLED_MODULES_FILE" >"$temp_file" 2>/dev/null || true
        mv "$temp_file" "$ENABLED_MODULES_FILE"
    else
        # Still stop container if running
        echo "Stopping container..."
        stop_module_container "$module_name"
    fi

    # Remove Docker image
    if [ -n "$MODULE_IMAGE" ]; then
        echo "Removing Docker image..."
        docker rmi "$MODULE_IMAGE" 2>/dev/null || echo "  Image not found or already removed."
    fi

    # Remove config volumes (pattern: claude-safe-$module_name-*)
    echo "Removing config volumes..."
    docker volume ls -q --filter "name=claude-safe-$module_name" 2>/dev/null | while read -r vol; do
        docker volume rm "$vol" 2>/dev/null || echo "  Could not remove $vol"
    done

    # Remove local config directory
    if [ -d "$CLAUDE_SAFE_DIR/$module_name" ]; then
        echo "Removing local configuration..."
        rm -rf "$CLAUDE_SAFE_DIR/$module_name"
    fi

    print_footer
    print_success "Module '${MODULE_DISPLAY_NAME:-$module_name}' removed completely."
    echo ""
}

# Start all enabled module containers
start_all_enabled_modules() {
    local workspace_dir="$1"

    for module_name in $(get_enabled_modules); do
        start_module_container "$module_name" "$workspace_dir"
    done
}

# Stop all enabled module containers
stop_all_enabled_modules() {
    for module_name in $(get_enabled_modules); do
        stop_module_container "$module_name"
    done
}

# Uninstall Claude Safe completely
uninstall_claude_safe() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                    UNINSTALL CLAUDE SAFE                   ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "This will remove:"
    echo "  • All enabled modules (Docker images and volumes)"
    echo "  • Claude Safe Docker image"
    echo "  • Claude authentication data (you'll need to re-login)"
    echo "  • Claude Safe configuration (~/.claude-safe)"
    echo "  • Claude Safe executable (~/bin/claude-safe)"
    echo ""
    echo "WARNING: This action cannot be undone!"
    echo ""
    read -p "Are you sure you want to uninstall Claude Safe? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo "Uninstall cancelled."
        return 0
    fi

    echo ""
    echo "Uninstalling Claude Safe..."
    echo ""

    # Remove all modules
    echo "Removing modules..."
    for module_dir in "$MODULES_DIR"/*/; do
        [ -d "$module_dir" ] || continue
        local module_name=$(basename "$module_dir")

        # Skip lib and template directories
        [[ "$module_name" == "lib" || "$module_name" == "_template" ]] && continue

        local conf_file="$module_dir/module.conf"
        [ -f "$conf_file" ] || continue

        echo "  Removing module: $module_name"
        remove_module "$module_name" 2>/dev/null || true
    done

    # Remove Claude Safe Docker image
    echo ""
    echo "Removing Claude Safe Docker image..."
    docker rmi claude-safe:latest 2>/dev/null || echo "  Image not found or already removed."

    # Remove persistent data volume
    echo ""
    echo "Removing Claude authentication data..."
    docker volume rm claude-data 2>/dev/null || echo "  Volume not found or already removed."

    # Remove config directory
    echo ""
    echo "Removing configuration..."
    rm -rf "$CLAUDE_SAFE_DIR"

    # Remove executable
    echo ""
    echo "Removing executable..."
    rm -f "$HOME/bin/claude-safe"

    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "Claude Safe has been uninstalled."
    echo ""
    echo "If you cloned the repository, you can remove it manually:"
    echo "  rm -rf /path/to/claude-safe"
    echo "════════════════════════════════════════════════════════════"
}

# Show status of all modules
show_module_status() {
    ensure_dirs

    print_header "MODULE STATUS"

    local found=0
    for module_dir in "$MODULES_DIR"/*/; do
        [ -d "$module_dir" ] || continue
        local module_name=$(basename "$module_dir")

        # Skip lib and template directories
        [[ "$module_name" == "lib" || "$module_name" == "_template" ]] && continue

        local conf_file="$module_dir/module.conf"
        [ -f "$conf_file" ] || continue

        # Source module config
        source "$conf_file"

        local enabled_icon="○"
        local running_icon="◇"

        if is_module_enabled "$module_name"; then
            enabled_icon="●"

            # Check if container is running
            if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "claude-safe-$module_name"; then
                running_icon="◆"
            fi
        fi

        printf "  %s %s %-12s  %s\n" "$enabled_icon" "$running_icon" "$module_name" "${MODULE_DESCRIPTION:-}"
        found=1
    done

    if [ "$found" -eq 0 ]; then
        echo "  No modules found."
    fi

    echo ""
    echo "  ● = enabled    ○ = disabled"
    echo "  ◆ = running    ◇ = stopped"
    print_footer
}
