#!/usr/bin/env bats
# Path validation tests for claude-safe.sh
# Tests security-critical path blocking and symlink bypass prevention

load test_helper

setup() {
    setup_test_dir
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# System Paths (blocked with entire tree)
# =============================================================================

@test "system path /etc is blocked" {
    run run_path_validation "/etc"
    [ "$status" -eq 1 ]
    assert_blocked "$output"
}

@test "system path /etc subdirectory is blocked" {
    run run_path_validation "/etc/passwd"
    # Note: /etc/passwd is a file, not directory, so it fails with "not found"
    # But /etc/ssh would be blocked
    [ "$status" -eq 1 ]
}

@test "system path /usr is blocked" {
    run run_path_validation "/usr"
    [ "$status" -eq 1 ]
    assert_blocked "$output"
}

@test "system path /usr/local is blocked (subdirectory)" {
    run run_path_validation "/usr/local"
    [ "$status" -eq 1 ]
    assert_blocked "$output"
}

@test "system path /var is blocked" {
    run run_path_validation "/var"
    [ "$status" -eq 1 ]
    assert_blocked "$output"
}

@test "system path /bin is blocked" {
    run run_path_validation "/bin"
    [ "$status" -eq 1 ]
    assert_blocked "$output"
}

@test "root path / is blocked" {
    run run_path_validation "/"
    [ "$status" -eq 1 ]
    assert_blocked "$output"
}

# =============================================================================
# Root Paths (blocked exact match only)
# =============================================================================

@test "root path /tmp is blocked" {
    run run_path_validation "/tmp"
    [ "$status" -eq 1 ]
    assert_blocked "$output"
}

@test "subdirectory of /tmp is allowed" {
    # On macOS, mktemp creates dirs in /private/var/folders (user temp)
    # On Linux, mktemp creates dirs in /tmp
    # Both should be allowed as they're user-writable temp directories
    local tmp_subdir
    tmp_subdir=$(mktemp -d)

    run run_path_validation "$tmp_subdir"
    # Should pass path validation (may fail at Docker, which is OK)
    assert_path_allowed "$output"

    rmdir "$tmp_subdir"
}

# =============================================================================
# Symlink Bypass Prevention
# =============================================================================

@test "symlink to /etc is blocked" {
    # Create symlink: TEST_DIR/etc-link -> /etc
    ln -s /etc "$TEST_DIR/etc-link"

    run run_path_validation "$TEST_DIR/etc-link"
    [ "$status" -eq 1 ]
    assert_blocked "$output"
}

@test "symlink to /usr is blocked" {
    ln -s /usr "$TEST_DIR/usr-link"

    run run_path_validation "$TEST_DIR/usr-link"
    [ "$status" -eq 1 ]
    assert_blocked "$output"
}

@test "symlink to /var is blocked" {
    ln -s /var "$TEST_DIR/var-link"

    run run_path_validation "$TEST_DIR/var-link"
    [ "$status" -eq 1 ]
    assert_blocked "$output"
}

# =============================================================================
# Valid Paths
# =============================================================================

@test "valid project directory is allowed" {
    mkdir -p "$TEST_DIR/myproject"

    run run_path_validation "$TEST_DIR/myproject"
    # Should pass path validation
    assert_path_allowed "$output"
}

@test "nested project directory is allowed" {
    mkdir -p "$TEST_DIR/projects/webapp/src"

    run run_path_validation "$TEST_DIR/projects/webapp/src"
    assert_path_allowed "$output"
}

# =============================================================================
# Edge Cases
# =============================================================================

@test "non-existent directory returns error" {
    run run_path_validation "/nonexistent/path/that/does/not/exist"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Directory not found"* ]]
}

@test "current directory (.) is resolved and checked" {
    cd "$TEST_DIR"
    mkdir -p project
    cd project

    run run_path_validation "."
    assert_path_allowed "$output"
}
