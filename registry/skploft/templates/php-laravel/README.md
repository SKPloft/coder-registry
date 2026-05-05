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
  - [`coder/git-clone`](https://registry.coder.com/modules/coder/git-clone) — clones the project into `~/projects/` when `git_repo_url` is set.
  - [`coder/code-server`](https://registry.coder.com/modules/coder/code-server) — browser VS Code, opens `~/projects/`.
  - [`coder/jetbrains`](https://registry.coder.com/modules/coder/jetbrains) — JetBrains Gateway connection (PhpStorm / IntelliJ) opening the same folder.
  - [`coder/claude-code`](https://registry.coder.com/modules/coder/claude-code) — installed when **Enable Claude Code** is checked.
  - [`coder-labs/codex`](https://registry.coder.com/modules/coder-labs/codex) — installed when **Enable Codex CLI** is checked.

## AI agent support

The template ships with optional AI coding agents that the workspace owner can toggle per workspace. API credentials are template-level admin variables, not workspace parameters, so they are set once at `coder templates push` time and never exposed in the create-workspace UI:

- `anthropic_api_key` — used by the Claude Code module. Leave empty to rely on workspace-owner OAuth (`claude setup-token`) or an external auth provider.
- `openai_api_key` — used by the Codex module.

Set them with `-V`:

```bash
coder templates push php-laravel \
  -d registry/skploft/templates/php-laravel/ \
  -V anthropic_api_key=sk-ant-... \
  -V openai_api_key=sk-... \
  -m "Add Claude Code and Codex" \
  -y
```

When Claude Code or Codex is enabled, the workspace also exposes a model / reasoning-effort dropdown so users can pick the runtime they want.

## Usage

1. Push the template to your Coder deployment (see the command below).
2. When creating a workspace, paste the Git URL of your Laravel or Statamic project into **Git repository URL**, optionally pin a branch, and pick a PHP version.
3. Optionally toggle **Enable Claude Code** or **Enable Codex CLI** and pick a model / reasoning effort.
4. After the workspace starts, open code-server or connect through JetBrains Gateway and run `composer install && npm install` inside the cloned project to bring up the dependencies.

> [!TIP]
> The selected PHP version bakes into the image and is therefore not changeable after creation. To switch versions, create a new workspace.

> [!IMPORTANT]
> Only enable an AI agent if its API key has been configured on the template (or, for Claude Code, if the workspace owner has run `claude setup-token`). Without credentials, the CLI will install but fail to authenticate.

> [!NOTE]
> The workspace ships with `php`, `composer`, and `node` on `PATH` but does not start a database server. Use a sidecar (e.g. `docker compose up` from within the workspace, or a separate Coder workspace) for MySQL, Postgres, or Redis when your project needs one.
