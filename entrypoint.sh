#!/bin/bash
set -e

PERSIST_DIR="/persist"
USER_HOME="/home/claude"
USERNAME="claude"

mkdir -p "$PERSIST_DIR"
chown -R "$USERNAME:$USERNAME" "$PERSIST_DIR"

echo "⚙️  Checking environment (User: $USERNAME)..."

link_folder() {
    local internal_path=$1
    local persist_name=$2

    mkdir -p "$PERSIST_DIR/$persist_name"

    mkdir -p "$(dirname "$internal_path")"

    rm -rf "$internal_path"
    ln -s "$PERSIST_DIR/$persist_name" "$internal_path"

    chown -h "$USERNAME:$USERNAME" "$internal_path"
}

link_file() {
    local internal_path=$1
    local persist_name=$2

    if [ ! -s "$PERSIST_DIR/$persist_name" ]; then
        echo "{}" >"$PERSIST_DIR/$persist_name"
        chown "$USERNAME:$USERNAME" "$PERSIST_DIR/$persist_name"
    fi

    mkdir -p "$(dirname "$internal_path")"
    rm -f "$internal_path"
    ln -s "$PERSIST_DIR/$persist_name" "$internal_path"
    chown -h "$USERNAME:$USERNAME" "$internal_path"
}

link_folder "$USER_HOME/.config" "config_root"
link_folder "$USER_HOME/.claude" "dot_claude"
link_folder "$USER_HOME/.local/state" "local_state"
link_folder "$USER_HOME/.local/share" "local_share"
link_folder "$USER_HOME/.cache" "cache_root"
link_file "$USER_HOME/.claude.json" "claude_token.json"

chown -R "$USERNAME:$USERNAME" "$PERSIST_DIR"

exec gosu "$USERNAME" "$@"
