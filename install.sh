#!/bin/bash
set -e

CLAUDE_SAFE_DIR="$HOME/.claude-safe"
INSTALL_DIR="$HOME/bin"

echo "Claude Safe Installer"
echo ""

echo "Cleaning old versions..."
OLD_CONTAINERS=$(docker ps -a -q --filter ancestor=claude-safe:latest 2>/dev/null)
if [ -n "$OLD_CONTAINERS" ]; then
    docker rm -f $OLD_CONTAINERS
    echo "Old containers removed."
else
    echo "No old containers found."
fi

echo "Building image..."
chmod +x entrypoint.sh claude-safe.sh
docker build -t claude-safe:latest .

echo "Setting up directories..."
mkdir -p "$CLAUDE_SAFE_DIR"
mkdir -p "$INSTALL_DIR"

echo "Installing modules..."
if [ -d "modules" ]; then
    # Remove old modules and copy fresh
    rm -rf "$CLAUDE_SAFE_DIR/modules"
    cp -r modules "$CLAUDE_SAFE_DIR/modules"

    # Make library scripts executable
    chmod +x "$CLAUDE_SAFE_DIR/modules/lib/"*.sh 2>/dev/null || true

    # Make module scripts executable
    for module_dir in "$CLAUDE_SAFE_DIR/modules"/*/; do
        [ -d "$module_dir" ] || continue
        chmod +x "$module_dir"/*.sh 2>/dev/null || true
    done

    echo "Modules installed to $CLAUDE_SAFE_DIR/modules"
else
    echo "Warning: modules directory not found, skipping module installation"
fi

echo "Installing claude-safe command..."
cp claude-safe.sh "$INSTALL_DIR/claude-safe"
chmod +x "$INSTALL_DIR/claude-safe"

echo ""
echo "Installation Completed."
echo "------------------------------------------------"
echo "NOTE: The container runs as the user 'claude' (UID 1000)."
echo "On Docker Desktop (macOS/Windows), file ownership is"
echo "automatically mapped to your host user."
echo "On Linux, files may be owned by UID 1000."
echo "------------------------------------------------"
echo ""
echo "Module System:"
echo "  claude-safe --modules         List available modules"
echo "  claude-safe --enable serena   Enable Serena module"
echo "  claude-safe --status          Show module status"
echo "------------------------------------------------"
