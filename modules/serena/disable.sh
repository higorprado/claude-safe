#!/bin/bash
# Serena module disable hook
# Note: Full cleanup (image + volumes) is handled by --remove command

set -e

echo "Stopping Serena container..."
docker stop claude-safe-serena 2>/dev/null || true
docker rm claude-safe-serena 2>/dev/null || true
