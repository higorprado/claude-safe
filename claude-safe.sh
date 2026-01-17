#!/bin/bash
set -e

PROJECT_DIR="${1:-$(pwd)}"

BLOCKED_PATHS=(
    "/" 
    "$HOME" 
    "/Applications" 
    "/Library" 
    "/System" 
    "/Users" 
    "/Volumes" 
    "/bin" 
    "/dev" 
    "/etc" 
    "/net" 
    "/opt" 
    "/private" 
    "/sbin" 
    "/usr" 
    "/var"
)

for blocked in "${BLOCKED_PATHS[@]}"; do
    if [ "$PROJECT_DIR" = "$blocked" ]; then
        echo "❌ Mounting $blocked is not allowed for security reasons"
        exit 1
    fi
done

if [ ! -d "$PROJECT_DIR" ]; then
    echo "❌ Directory not found: $PROJECT_DIR"
    exit 1
fi

PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)
PROJECT_NAME=$(basename "$PROJECT_DIR")

echo "🔒 Claude Safe"
echo "📁 Project: $PROJECT_NAME"

if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker does not seem to be running. Please start Docker and try again."
    exit 1
fi

if ! docker volume create claude-data > /dev/null 2>&1; then
    # Volume likely already exists, which is fine
    if ! docker volume inspect claude-data > /dev/null 2>&1; then
        echo "❌ Failed to create or access Docker volume 'claude-data'"
        exit 1
    fi
fi

DOCKER_ARGS=(
    -it --rm
    -v "$PROJECT_DIR:/workspace"
    -v claude-data:/persist
    -w /workspace
    --name "claude-safe-${PROJECT_NAME}-$(date +%s)"
)

if [ -f "$HOME/.gitconfig" ]; then
    echo "✅ Git Config detected and mounted."
    DOCKER_ARGS+=(-v "$HOME/.gitconfig:/home/claude/.gitconfig:ro")
fi

DOCKER_ARGS+=(--network host)  

docker run "${DOCKER_ARGS[@]}" claude-safe:latest