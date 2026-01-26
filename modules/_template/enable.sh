#!/bin/bash
# Enable hook - runs when module is enabled
# Use this for one-time setup like pulling images, creating volumes, etc.

set -e

source module.conf

echo "Pulling Docker image..."
docker pull "$MODULE_IMAGE"

echo "Creating config volume..."
docker volume create claude-safe-my-module-config 2>/dev/null || true

echo "Module enabled."
