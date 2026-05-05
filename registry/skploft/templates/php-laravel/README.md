---
display_name: PHP / Laravel (Docker)
description: Provision a Docker workspace pre-loaded with PHP, Composer, and Node.js for Laravel and Statamic development, optionally cloning a project repository on first start.
icon: ../../../../.icons/php.svg
verified: false
tags: [docker, php, laravel, composer, statamic]
---

# PHP / Laravel (Docker)

Provisions a Linux Docker container with a complete PHP / Composer / Node toolchain ready for Laravel- and Statamic-style projects. The container image is built from a `Dockerfile` in this template, and the workspace clones a project repository on first start when one is supplied.

## Prerequisites

- A Coder deployment with a Docker-capable provisioner (Docker Engine on Linux, or Colima / OrbStack on macOS).
- Network access to the Ubuntu archive, the `ondrej/php` PPA, NodeSource, and `getcomposer.org` so the workspace image can build.
- For private project repositories, configure a [Git external auth provider](https://coder.com/docs/admin/external-auth) on your Coder deployment, or use an SSH-based clone URL with keys provisioned via dotfiles.

## Architecture

The template builds a per-deployment image and runs each workspace as a container with a persistent home volume.

- `docker_image.main` — built locally from `build/Dockerfile`. Installs PHP (selectable version), the extensions Statamic and most Laravel projects expect (`bcmath`, `curl`, `dom`, `gd`, `intl`, `mbstring`, `mysql`, `pgsql`, `redis`, `sqlite3`, `xml`, `zip`), Composer 2, and Node.js 20.
- `docker_volume.home_volume` — persistent volume mounted at `/home/coder` so projects, Composer caches, and IDE state survive workspace restarts.
- `docker_container.workspace` — ephemeral; recreated on each start. Connects back to Coder via the agent init script and uses `host.docker.internal` for access-URL routing on local deployments.
- Modules consumed:
  - [`skploft/proxy-env`](../../modules/proxy-env) — sets HTTP/HTTPS/NO_PROXY env vars on the agent. The URL is hardcoded in `main.tf` (`local.proxy_url`) and not exposed as a workspace parameter.
  - [`coder/git-clone`](https://registry.coder.com/modules/coder/git-clone) — clones the project into `~/projects/` when `git_repo_url` is set.
  - [`coder/code-server`](https://registry.coder.com/modules/coder/code-server) — browser VS Code, opens `~/projects/`.
  - [`coder/jetbrains`](https://registry.coder.com/modules/coder/jetbrains) — JetBrains Gateway connection (PhpStorm / IntelliJ) opening the same folder.
  - [`coder/claude-code`](https://registry.coder.com/modules/coder/claude-code) — installed when **Enable Claude Code** is checked. Pinned to `~> 5.0` by default; pinned to `~> 4.0` instead when **Pin Claude Code to v4 for Coder Tasks** is also on.
  - [`coder-labs/codex`](https://registry.coder.com/modules/coder-labs/codex) — installed when **Enable Codex CLI** is checked. Always task-capable.

## AI agent support

The template ships with optional AI coding agents that the workspace owner can toggle per workspace. Nothing AI-related runs unless the corresponding **Enable …** parameter is checked, so workspaces stay lean by default.

When **Enable Claude Code** or **Enable Codex CLI** is on, the workspace authenticates the same way the upstream CLIs do — interactively, on first use:

- Claude Code: open the workspace terminal and run `claude /login`. The credentials are written to `~/.claude/` on the persistent home volume, so the login survives workspace restarts.
- Codex: run `codex login`; the credentials live under `~/.codex/`.

This matches the pattern used by [`coder-labs/templates/tasks-docker`](https://github.com/coder/registry/tree/main/registry/coder-labs/templates/tasks-docker): no admin-set API keys, no secrets in template variables, and each workspace owner authenticates with their own account so billing and rate limits land on the right person.

If the deployment runs Coder Premium (>= 2.30), the workspace owner can flip **Use Coder AI Gateway for Claude Code** or **Use Coder AI Bridge for Codex** instead — the CLIs then authenticate via the workspace owner's Coder session and no `/login` is needed.

The template intentionally does not expose a model or reasoning-effort parameter. Both CLIs let the developer pick at runtime, and the choice persists on the home volume:

- Claude Code: type `/model` inside the CLI, or run `claude config set -g model opus`, or edit `~/.claude/settings.json`.
- Codex: pass `--reasoning-effort high` on invocation, or set `model_reasoning_effort` in `~/.codex/config.toml`.

> [!IMPORTANT]
> The AI Gateway / AI Bridge toggles only do anything on a Coder Premium deployment with the corresponding feature configured. On a community deployment, leave them off and authenticate with `claude /login` or `codex login` instead.

## Coder Tasks

This template is Tasks-capable. When at least one task-capable agent module is installed, the Tasks UI lets a user paste a prompt, pick a workspace preset, and the agent runs against the prompt inside an isolated workspace.

The agent that answers the prompt is selected by the **Tasks agent** parameter:

- `codex` (default) — Codex always supports Tasks. Runtime auth via `codex login`. Recommended unless you specifically need Claude.
- `claude` — requires **Pin Claude Code to v4 for Coder Tasks** to also be on. v5 of the Claude Code module dropped Tasks support pending a follow-up; v4 still has `task_app_id` and is what the official `coder-labs/tasks-docker` template uses. The tradeoff is v4 predates the v5 runtime-OAuth flow.

If the selected agent is not installed in the workspace, the other one is used as a fallback.

### Workspace presets

Presets bundle a set of parameter values into a named option that surfaces in the Tasks UI dropdown:

```tf
data "coder_workspace_preset" "statamic_skploft" {
  name    = "SKPloft Statamic"
  default = true
  parameters = {
    git_repo_url = "https://github.com/SKPloft/statamic.git"
    enable_codex = "true"
    task_agent   = "codex"
  }
}
```

Each preset = one entry in the dropdown. Adding another scenario means appending another `data "coder_workspace_preset"` block — the workspace's Dockerfile, agent, and module logic stay untouched. Users who don't want any preset's repo can deselect it and paste their own URL into **Git repository URL** at create time; that path stays free-form.

The template ships with one preset (`SKPloft Statamic`) as a starting point. To add more — or to point the existing one at a different repo — edit `main.tf` and re-push.

## Usage

1. Push the template to your Coder deployment (see the command below).
2. When creating a workspace, paste the Git URL of your Laravel or Statamic project into **Git repository URL**, optionally pin a branch, and pick a PHP version.
3. Optionally toggle **Enable Claude Code** or **Enable Codex CLI** (and the AI Gateway / AI Bridge variants if your deployment supports them).
4. After the workspace starts, open code-server or connect through JetBrains Gateway and run `composer install && npm install` inside the cloned project to bring up the dependencies.

> [!TIP]
> The selected PHP version bakes into the image and is therefore not changeable after creation. To switch versions, create a new workspace.

> [!NOTE]
> The workspace ships with `php`, `composer`, and `node` on `PATH` but does not start a database server. Use a sidecar (e.g. `docker compose up` from within the workspace, or a separate Coder workspace) for MySQL, Postgres, or Redis when your project needs one.
