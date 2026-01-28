#!/bin/bash
# Serena module enable hook

set -e

source module.conf

CLAUDE_SAFE_DIR="${CLAUDE_SAFE_DIR:-$HOME/.claude-safe}"
SERENA_CONFIG_DIR="$CLAUDE_SAFE_DIR/serena/config"

echo "Pulling Serena Docker image..."
docker pull "$MODULE_IMAGE"

echo "Creating Serena config directory..."
mkdir -p "$SERENA_CONFIG_DIR"

# Create default config if it doesn't exist
# The config must include all required keys that Serena expects
if [ ! -f "$SERENA_CONFIG_DIR/serena_config.yml" ]; then
    echo "Creating default Serena configuration..."
    # First, extract the default config from the Serena container
    docker run --rm "$MODULE_IMAGE" cat /workspaces/serena/config/serena_config.yml >"$SERENA_CONFIG_DIR/serena_config.yml" 2>/dev/null || {
        echo "Warning: Could not extract default config, creating minimal config..."
        cat >"$SERENA_CONFIG_DIR/serena_config.yml" <<'EOF'
# Serena Configuration for Claude Safe
# Generated from Serena defaults

projects: []

# Web dashboard settings
web_dashboard_open_on_launch: false

# Memory system
enable_memory_system: true
EOF
    }
fi

echo "Serena module enabled."
