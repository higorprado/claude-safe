#!/bin/bash
set -e

echo "📦 Cleaning old versions..."
OLD_CONTAINERS=$(docker ps -a -q --filter ancestor=claude-safe:latest 2>/dev/null)
if [ -n "$OLD_CONTAINERS" ]; then
    docker rm -f $OLD_CONTAINERS
    echo "✅ Old containers removed."
else
    echo "✅ No old containers found."
fi

echo "📦 Building image..."
chmod +x entrypoint.sh claude-safe.sh
docker build -t claude-safe:latest .

INSTALL_DIR="$HOME/bin"
mkdir -p "$INSTALL_DIR"
cp claude-safe.sh "$INSTALL_DIR/claude-safe"
chmod +x "$INSTALL_DIR/claude-safe"

echo ""
echo "✅ Installation Completed."
echo "------------------------------------------------"
echo "NOTE: The container runs as the user 'claude' (UID 1000)."
echo "On Docker Desktop (macOS/Windows), file ownership is"
echo "automatically mapped to your host user."
echo "On Linux, files may be owned by UID 1000."
echo "------------------------------------------------"