# Claude Safe
![CI Status](https://github.com/higorprado/claude-safe/actions/workflows/ci.yml/badge.svg)

Run **Claude Code** in a fully isolated, persistent, and secure Docker container. Works on **macOS**, **Linux**, and **WSL** to protect your system from unwanted modifications while maintaining your authentication session and Git identity.

## Why?

Claude Code is an autonomous AI agent capable of editing files and running commands. Running it directly on your host machine gives it access to your entire system.

**Claude Safe** creates a sandboxed Ubuntu environment that:
1.  **Isolates Execution**: The AI can only see and modify the specific project directory you mount.
2.  **Runs Securely**: Uses a non-privileged user inside the container (no running as root).
3.  **Persists Authentication**: Log in once inside the container, and your session remains active across restarts.
4.  **Integrates with Git**: Automatically mounts your `.gitconfig` so commits made by Claude are correctly attributed to you.
5.  **Uses your Subscription**: Works with your existing Claude.ai Pro/Team plan (no API keys required).

## Prerequisites

- **Docker** (Docker Desktop on macOS/Windows, or Docker Engine on Linux)
- **Claude.ai Account** (Pro or Team subscription recommended)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/higorprado/claude-safe.git
   cd claude-safe
   ```

2. Run the installer:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. Add the binary to your PATH (if prompted):
   - **Fish:** `fish_add_path ~/bin`
   - **Zsh/Bash:** `echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc` (then reload shell)

## First Time Setup

You need to authenticate **inside** the container once. The credentials will be saved in a persistent Docker volume.

1. Start the environment:
   ```bash
   claude-safe
   ```

2. Inside the container, run:
   ```bash
   claude auth login
   ```

3. **Copy the URL** provided in the terminal and open it in your browser to authorize.

4. Once authorized, verify it works:
   ```bash
   claude
   # Should show the Claude Code welcome screen
   ```

5. Exit the container:
   ```bash
   exit
   ```

Your session is now saved. You won't need to log in again.

## Usage

Navigate to any project directory and run:

```bash
cd ~/Code/my-cool-project
claude-safe
```

You will be dropped into a secure shell inside the container. From here, you can use Claude normally:

```bash
# Ask Claude to do work
claude "Analyze this project and suggest refactoring"
claude "Fix the bug in main.py"
```

Any changes Claude makes are reflected immediately in your host file system (in that specific folder only).

### Run on a specific path
You can also specify the target directory:

```bash
claude-safe ~/Code/another-project
```

## Modules (Optional)

Claude Code has a native plugin system for MCP servers. Claude-Safe offers an **alternative module system** that runs MCP servers in isolated Docker containers.

### Why Use Modules?

- **Full isolation**: MCP servers run in separate containers, not on your host
- **Clean system**: No dependencies installed on your machine
- **Custom modules**: Run MCP servers that aren't in the official marketplace
- **Version control**: Use a specific version different from what's available as a plugin
- **Consistent environment**: Same setup across different machines

### Available Modules

| Module | Description |
|--------|-------------|
| `serena` | AI coding assistant with semantic code understanding |

### Managing Modules

```bash
# List available modules
claude-safe --modules

# Enable a module (pulls image, configures MCP)
claude-safe --enable serena

# Disable a module (stops container, keeps image for fast re-enable)
claude-safe --disable serena

# Remove a module completely (removes image and volumes)
claude-safe --remove serena

# Show module status
claude-safe --status
```

### How Modules Work

1. **Enable** (`--enable`): Pulls the Docker image and configures Claude Code's MCP settings
2. **Disable** (`--disable`): Stops the container and removes MCP config (keeps image for fast re-enable)
3. **Remove** (`--remove`): Full cleanup - removes image, volumes, and all module data

When you run `claude-safe`, enabled modules start as sidecar containers that share your workspace directory. When you exit, module containers are automatically stopped.

### Creating Custom Modules

See `modules/_template/README.md` for instructions on creating your own modules.

## How It Works

*   **Secure Architecture**: Runs on `ubuntu:24.04` but drops privileges to a standard user (`claude`, UID 1000) using `gosu`. This ensures the application doesn't run as root.
*   **Smart Persistence**: Uses a custom `entrypoint.sh` to dynamically link a Docker volume (`claude-data`) to the user's home directory (`/home/claude/.config`, etc.). This preserves your login token while keeping the container immutable.
*   **Git Integration**: Mounts your host's `~/.gitconfig` in read-only mode, allowing Claude to make commits using your name and email.
*   **Network**: Shares the host network stack to allow low-latency API communication.

## Security Considerations

Claude Safe provides **filesystem isolation**, not complete sandboxing:

| Layer | Isolated? | Details |
|-------|-----------|---------|
| Filesystem | Yes | Container can only access the mounted project directory |
| System directories | Yes | Sensitive paths (`/etc`, `/var`, `/usr`, etc.) cannot be mounted |
| Network | No | Uses `--network host` for optimal API latency |

**Why host networking?** Claude Code makes frequent API calls to Claude's servers. Using Docker's bridge network adds latency to every request. Host networking provides the same network performance as running Claude Code directly on your machine.

**What this means:** While the AI cannot read or modify files outside your project directory, it has the same network access as any process on your host. This is intentional and mirrors how Claude Code would behave if run directly on your machine.

### Alternative: Bridge Network Mode

If you prefer complete network isolation, you can modify `claude-safe.sh` by removing the `--network host` line. Note that this will increase API call latency by 10-30ms per request.

## Troubleshooting

**"Unexpected end of JSON input"**
If you see this error, your configuration volume might have been corrupted. Reset it by running:
```bash
docker volume rm claude-data
```
Then run `claude-safe` again. The system will auto-repair the configuration.

**"Docker daemon is not running"**
Make sure Docker is running. On macOS/Windows, open Docker Desktop. On Linux, ensure the Docker service is started (`sudo systemctl start docker`).

## Uninstall

To completely remove Claude Safe and all associated data:

```bash
claude-safe --uninstall
```

This will:
- Remove all module Docker images and volumes
- Remove the Claude Safe Docker image
- Remove your Claude authentication (you'll need to re-login if you reinstall)
- Remove all configuration files
- Remove the `claude-safe` executable

You'll be asked to confirm before anything is deleted.

## License

MIT
