---
display_name: Warp
description: Run the Warp Oz AI agent in your workspace with a web interface and Coder Tasks support
icon: ../../../../.icons/warp.svg
verified: false
tags: [agent, warp, ai, oz, tasks]
---

# Warp

Run the [Warp Oz CLI](https://docs.warp.dev/reference/cli/) AI agent in your workspace for intelligent code generation, analysis, and development assistance. The module wraps the Oz CLI with [AgentAPI](https://github.com/coder/agentapi) to provide a web interface and seamless task reporting in the Coder UI.

The Oz CLI is Warp's headless agent runtime: `oz agent run --prompt "..."` runs an agent locally in the workspace, authenticating non-interactively with a Warp API key. This makes it suitable for Coder Tasks and unattended runs, unlike the Warp desktop terminal which requires a display.

```tf
module "warp" {
  source   = "registry.coder.com/skploft/warp/coder"
  version  = "0.1.0"
  agent_id = coder_agent.main.id
  workdir  = "/home/coder/project"
}
```

## Prerequisites

- **Warp API key** — required for headless/task runs. Create one in the [Oz web app](https://docs.warp.dev/reference/cli/) and pass it as `warp_api_key`. It is set as the `WARP_API_KEY` environment variable for the agent. For interactive use in the web terminal, you can instead run `oz login` once inside the workspace.

## Examples

### Basic Usage with Tasks

```tf
resource "coder_ai_task" "task" {
  app_id = module.warp.task_app_id
}

module "warp" {
  source       = "registry.coder.com/skploft/warp/coder"
  version      = "0.1.0"
  agent_id     = coder_agent.main.id
  workdir      = "/home/coder/project"
  warp_api_key = "wk-xxxx-xxxx"
  ai_prompt    = coder_ai_task.task.prompt
}
```

### Standalone CLI Mode

Run Warp as a command-line tool without task reporting. The web app becomes an interactive shell where you can run `oz agent run` yourself.

```tf
module "warp" {
  source       = "registry.coder.com/skploft/warp/coder"
  version      = "0.1.0"
  agent_id     = coder_agent.main.id
  workdir      = "/home/coder"
  warp_api_key = "wk-xxxx-xxxx"
  report_tasks = false
  cli_app      = true
}
```

### Custom model, profile, and MCP servers

```tf
module "warp" {
  source       = "registry.coder.com/skploft/warp/coder"
  version      = "0.1.0"
  agent_id     = coder_agent.main.id
  workdir      = "/home/coder/project"
  warp_api_key = "wk-xxxx-xxxx"
  model        = "claude-sonnet-4"
  profile      = "backend"
  mcp          = "{\"github\":{\"url\":\"https://api.githubcopilot.com/mcp/\"}}"
}
```

> [!NOTE]
> The Warp GUI terminal (`warp-terminal`) is not installed by default because it requires a desktop environment with OpenGL/Vulkan support. Set `install_warp_terminal = true` on a desktop workspace (e.g. one using the `kasmvnc` or `windows-rdp` modules) to install it.

> [!NOTE]
> The Oz CLI is task/session-oriented: `oz agent run` executes one prompt and exits. When no `ai_prompt` is provided, the web app opens an interactive shell so you can run `oz agent run` yourself.

## Troubleshooting

If you encounter issues, check the log files in the `~/.warp-module` directory within your workspace for detailed information.

```bash
cat ~/.warp-module/agentapi-start.log
```

If `oz` is not found on PATH after install, the package name may differ on your distribution. See the [Oz CLI install docs](https://docs.warp.dev/reference/cli/) for manual installation.

## References

- [Warp Oz CLI Reference](https://docs.warp.dev/reference/cli/)
- [Warp Installation](https://docs.warp.dev/getting-started/quickstart/installation-and-setup/)
- [AgentAPI Documentation](https://github.com/coder/agentapi)
- [Coder AI Agents Guide](https://coder.com/docs/tutorials/ai-agents)
