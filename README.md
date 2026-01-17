# Claude Safe

Run **Claude Code** in a fully isolated, persistent, and secure Docker container. Protect your Mac from unwanted system modifications while maintaining your authentication session and Git identity.

## Why?

Claude Code is an autonomous AI agent capable of editing files and running commands. Running it directly on your host machine (Mac) gives it access to your entire system.

**Claude Safe** creates a sandboxed Ubuntu environment that:
1.  **Isolates Execution**: The AI can only see and modify the specific project directory you mount.
2.  **Runs Securely**: Uses a non-privileged user inside the container (no running as root).
3.  **Persists Authentication**: Log in once inside the container, and your session remains active across restarts.
4.  **Integrates with Git**: Automatically mounts your `.gitconfig` so commits made by Claude are correctly attributed to you.
5.  **Uses your Subscription**: Works with your existing Claude.ai Pro/Team plan (no API keys required).

## Prerequisites

- **Docker Desktop** (must be running)
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

3. **Copy the URL** provided in the terminal and open it in your Mac's browser to authorize.

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

Navigate to any project on your Mac and run:

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

Any changes Claude makes are reflected immediately in your Mac's file system (in that specific folder only).

### Run on a specific path
You can also specify the target directory:

```bash
claude-safe ~/Code/another-project
```

## How It Works

*   **Secure Architecture**: Runs on `ubuntu:24.04` but drops privileges to a standard user (`claude`, UID 1000) using `gosu`. This ensures the application doesn't run as root.
*   **Smart Persistence**: Uses a custom `entrypoint.sh` to dynamically link a Docker volume (`claude-data`) to the user's home directory (`/home/claude/.config`, etc.). This preserves your login token while keeping the container immutable.
*   **Git Integration**: Mounts your host's `~/.gitconfig` in read-only mode, allowing Claude to make commits using your name and email.
*   **Network**: Shares the host network stack to allow low-latency API communication.

## Troubleshooting

**"Unexpected end of JSON input"**
If you see this error, your configuration volume might have been corrupted. Reset it by running:
```bash
docker volume rm claude-data
```
Then run `claude-safe` again. The system will auto-repair the configuration.

**"Docker daemon is not running"**
Make sure Docker Desktop is open and running on your Mac.

## Uninstall

To remove everything from your system:

```bash
# 1. Remove the executable
rm ~/bin/claude-safe

# 2. Remove the Docker image
docker rmi claude-safe:latest

# 3. Remove the persistent data (WARNING: logs you out)
docker volume rm claude-data
```

## License

MIT