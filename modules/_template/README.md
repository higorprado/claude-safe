# Creating a Claude Safe Module

This template provides the structure for creating a new Claude Safe module. Modules allow you to add MCP (Model Context Protocol) servers as sidecar containers that Claude Code can interact with.

## Quick Start

1. Copy this `_template` directory:
   ```bash
   cp -r modules/_template modules/my-module
   ```

2. Edit `module.conf` with your module's details

3. Customize `docker-compose.yml` for your container

4. Update `mcp.json` with your MCP server configuration

5. Customize `enable.sh` and `disable.sh` hooks as needed

## File Reference

### module.conf

Configuration file that defines module metadata:

| Variable | Required | Description |
|----------|----------|-------------|
| `MODULE_NAME` | Yes | Identifier (lowercase, no spaces) |
| `MODULE_DISPLAY_NAME` | Yes | Human-readable name |
| `MODULE_DESCRIPTION` | Yes | Short description |
| `MODULE_IMAGE` | Yes | Docker image to use |
| `MODULE_TRANSPORT` | Yes | MCP transport: `sse` or `stdio` |
| `MODULE_MCP_URL` | For SSE | MCP endpoint URL |
| `MODULE_PORTS` | No | Ports to expose (space-separated) |

### docker-compose.yml

Docker Compose file for the sidecar container. Available environment variables:

- `${WORKSPACE_DIR}` - Host path to the mounted project directory
- `${CLAUDE_SAFE_DIR}` - Path to `~/.claude-safe`

Best practices:
- Use `network_mode: host` for seamless localhost access (don't add `ports:` section)
- Add a `command:` to start the MCP server (many images don't have a default command)
- Don't set `working_dir` - let the container use its default (often `/app`)
- For persistent config, mount `${CLAUDE_SAFE_DIR}/module-name/config` instead of Docker volumes

### mcp.json

MCP server configuration that gets merged into Claude's settings:

```json
{
  "server-name": {
    "type": "sse",
    "url": "http://localhost:PORT/sse"
  }
}
```

For stdio transport:
```json
{
  "server-name": {
    "type": "stdio",
    "command": "docker",
    "args": ["exec", "-i", "container-name", "command"]
  }
}
```

### enable.sh

Runs once when the module is enabled. Use for:
- Pulling Docker images
- Creating config volumes
- One-time setup

### disable.sh

Runs when the module is disabled (`--disable`). Use for:
- Stopping containers
- Keep it simple - full cleanup is handled by `--remove`

## Testing Your Module

1. Enable your module:
   ```bash
   claude-safe --enable my-module
   ```

2. Check status:
   ```bash
   claude-safe --status
   ```

3. Run Claude Safe:
   ```bash
   claude-safe ~/my-project
   ```

4. Inside Claude, verify your MCP tools are available

## Module Lifecycle

| Command | What happens |
|---------|--------------|
| `--enable` | Pulls image, creates volumes, configures MCP |
| `--disable` | Stops container, removes MCP config (keeps image/volumes) |
| `--remove` | Full cleanup: removes image and volumes |

## Tips

- Use `localhost` URLs since containers share the host network
- Always specify a `command:` in docker-compose.yml if the image doesn't have a default
- Keep `disable.sh` simple - it should just stop the container
- Use `${CLAUDE_SAFE_DIR}/module-name/config` for persistent config (not Docker volumes)
- Test the full lifecycle: enable → run → disable → remove
