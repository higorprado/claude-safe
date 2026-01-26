#!/bin/bash
set -e

# Configuration
CLAUDE_SAFE_DIR="${CLAUDE_SAFE_DIR:-$HOME/.claude-safe}"
MODULES_DIR="${MODULES_DIR:-$CLAUDE_SAFE_DIR/modules}"

# Source module library if available
source_module_lib() {
    if [ -f "$MODULES_DIR/lib/module-manager.sh" ]; then
        source "$MODULES_DIR/lib/module-manager.sh"
        return 0
    fi
    return 1
}

# Show help
show_help() {
    echo "Claude Safe - Run Claude Code in a secure Docker container"
    echo ""
    echo "Usage: claude-safe [OPTIONS] [PROJECT_DIR]"
    echo ""
    echo "Options:"
    echo "  --help, -h        Show this help message"
    echo "  --modules         List available modules"
    echo "  --enable MODULE   Enable a module (pulls image, configures MCP)"
    echo "  --disable MODULE  Disable a module (stops container, keeps image)"
    echo "  --remove MODULE   Remove a module completely (removes image and volumes)"
    echo "  --status          Show module status"
    echo "  --uninstall       Uninstall Claude Safe and all modules"
    echo ""
    echo "Examples:"
    echo "  claude-safe                    # Run in current directory"
    echo "  claude-safe ~/Code/project     # Run in specific directory"
    echo "  claude-safe --modules          # List available modules"
    echo "  claude-safe --enable serena    # Enable Serena module"
    echo "  claude-safe --remove serena    # Remove Serena completely"
    echo ""
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --modules)
                if source_module_lib; then
                    list_available_modules
                else
                    echo "Module system not installed. Run install.sh first."
                    exit 1
                fi
                exit 0
                ;;
            --enable)
                if [ -z "$2" ]; then
                    echo "Error: --enable requires a module name"
                    exit 1
                fi
                if source_module_lib; then
                    enable_module "$2"
                else
                    echo "Module system not installed. Run install.sh first."
                    exit 1
                fi
                exit 0
                ;;
            --disable)
                if [ -z "$2" ]; then
                    echo "Error: --disable requires a module name"
                    exit 1
                fi
                if source_module_lib; then
                    disable_module "$2"
                else
                    echo "Module system not installed. Run install.sh first."
                    exit 1
                fi
                exit 0
                ;;
            --remove)
                if [ -z "$2" ]; then
                    echo "Error: --remove requires a module name"
                    exit 1
                fi
                if source_module_lib; then
                    remove_module "$2"
                else
                    echo "Module system not installed. Run install.sh first."
                    exit 1
                fi
                exit 0
                ;;
            --status)
                if source_module_lib; then
                    show_module_status
                else
                    echo "Module system not installed. Run install.sh first."
                    exit 1
                fi
                exit 0
                ;;
            --uninstall)
                if source_module_lib; then
                    uninstall_claude_safe
                else
                    echo "Module system not installed. Run install.sh first."
                    exit 1
                fi
                exit 0
                ;;
            -*)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                # This is the project directory
                PROJECT_DIR="$1"
                shift
                break
                ;;
        esac
        shift
    done
}

# Cleanup function for module containers
cleanup_modules() {
    if source_module_lib 2>/dev/null; then
        echo ""
        echo "Stopping module containers..."
        stop_all_enabled_modules
    fi
}

# Main execution starts here
PROJECT_DIR=""
parse_args "$@"

# Default to current directory if not specified
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"

# Common blocked paths for all platforms
BLOCKED_PATHS=(
    "/"
    "$HOME"
    "/bin"
    "/boot"
    "/dev"
    "/etc"
    "/lib"
    "/lib64"
    "/opt"
    "/proc"
    "/root"
    "/run"
    "/sbin"
    "/srv"
    "/sys"
    "/tmp"
    "/usr"
    "/var"
)

# Add platform-specific blocked paths
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS-specific paths
    BLOCKED_PATHS+=(
        "/Applications"
        "/Library"
        "/System"
        "/Users"
        "/Volumes"
        "/net"
        "/private"
    )
else
    # Linux-specific paths (includes WSL)
    BLOCKED_PATHS+=(
        "/home"
        "/mnt"
        "/media"
        "/snap"
    )
fi

for blocked in "${BLOCKED_PATHS[@]}"; do
    if [ "$PROJECT_DIR" = "$blocked" ]; then
        echo "Mounting $blocked is not allowed for security reasons"
        exit 1
    fi
done

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Directory not found: $PROJECT_DIR"
    exit 1
fi

PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)
PROJECT_NAME=$(basename "$PROJECT_DIR")

echo "Claude Safe"
echo "Project: $PROJECT_NAME"

if ! docker info > /dev/null 2>&1; then
    echo "Docker does not seem to be running. Please start Docker and try again."
    exit 1
fi

if ! docker volume create claude-data > /dev/null 2>&1; then
    # Volume likely already exists, which is fine
    if ! docker volume inspect claude-data > /dev/null 2>&1; then
        echo "Failed to create or access Docker volume 'claude-data'"
        exit 1
    fi
fi

# Start enabled module containers
if source_module_lib 2>/dev/null; then
    enabled_modules=$(get_enabled_modules)
    if [ -n "$enabled_modules" ]; then
        echo "Starting enabled modules..."
        start_all_enabled_modules "$PROJECT_DIR"
        # Set up trap to cleanup modules on exit
        trap cleanup_modules EXIT INT TERM
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
    echo "Git Config detected and mounted."
    DOCKER_ARGS+=(-v "$HOME/.gitconfig:/home/claude/.gitconfig:ro")
fi

DOCKER_ARGS+=(--network host)

docker run "${DOCKER_ARGS[@]}" claude-safe:latest
