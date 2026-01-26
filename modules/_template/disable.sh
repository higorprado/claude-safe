#!/bin/bash
# Disable hook - runs when module is disabled
# Note: Full cleanup (image + volumes) is handled by --remove command

set -e

echo "Stopping container..."
docker stop claude-safe-my-module 2>/dev/null || true
docker rm claude-safe-my-module 2>/dev/null || true
