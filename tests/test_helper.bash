#!/bin/bash
# Test helper functions for BATS tests

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Path to the main script
CLAUDE_SAFE_SCRIPT="$PROJECT_ROOT/claude-safe.sh"

# Create a temporary directory for tests
setup_test_dir() {
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
}

# Clean up temporary directory
teardown_test_dir() {
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# Run claude-safe.sh and capture output/status
# Returns before Docker commands by checking for path validation errors
run_path_validation() {
    local path="$1"
    bash "$CLAUDE_SAFE_SCRIPT" "$path" 2>&1
}

# Check if output contains expected error message
assert_blocked() {
    local output="$1"
    [[ "$output" == *"is not allowed for security reasons"* ]]
}

# Check if output passed path validation (reached Docker check)
assert_path_allowed() {
    local output="$1"
    # If path validation passed, it will either:
    # - Start Claude Safe successfully, or
    # - Fail at Docker check (in CI without Docker)
    # - Fail at directory not found
    [[ "$output" != *"is not allowed for security reasons"* ]]
}
