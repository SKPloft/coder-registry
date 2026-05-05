terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.13"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

variable "docker_socket" {
  description = "(Optional) Docker socket URI."
  type        = string
  default     = ""
}

provider "docker" {
  host = var.docker_socket != "" ? var.docker_socket : null
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}
data "coder_task" "me" {}

locals {
  username = data.coder_workspace_owner.me.name

  proxy_url = "http://172.18.0.1:17891"
  no_proxy  = "localhost,127.0.0.1,host.docker.internal,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"

  use_claude_v5 = data.coder_parameter.enable_claude_code.value == "true" && data.coder_parameter.enable_claude_code_tasks.value != "true"
  use_claude_v4 = data.coder_parameter.enable_claude_code.value == "true" && data.coder_parameter.enable_claude_code_tasks.value == "true"
  use_codex     = data.coder_parameter.enable_codex.value == "true"

  task_agent_choice = data.coder_parameter.task_agent.value
  has_task_agent    = local.use_codex || local.use_claude_v4

  task_app_id = (
    local.task_agent_choice == "claude" && local.use_claude_v4
    ) ? try(module.claude-code-v4[0].task_app_id, "") : (
    local.use_codex ? try(module.codex[0].task_app_id, "") : try(module.claude-code-v4[0].task_app_id, "")
  )
}

data "coder_parameter" "git_repo_url" {
  name         = "git_repo_url"
  display_name = "Git repository URL"
  description  = "HTTPS or SSH URL of the Laravel project to clone on first start. Leave empty to skip cloning."
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_parameter" "git_branch" {
  name         = "git_branch"
  display_name = "Git branch"
  description  = "Branch to check out. Leave empty to use the repository's default branch."
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_parameter" "php_version" {
  name         = "php_version"
  display_name = "PHP version"
  description  = "PHP runtime version baked into the workspace image."
  type         = "string"
  default      = "8.3"
  mutable      = false
  form_type    = "dropdown"

  option {
    name  = "PHP 8.2"
    value = "8.2"
  }
  option {
    name  = "PHP 8.3 (recommended)"
    value = "8.3"
  }
  option {
    name  = "PHP 8.4"
    value = "8.4"
  }
}

data "coder_parameter" "enable_claude_code" {
  name         = "enable_claude_code"
  display_name = "Enable Claude Code"
  description  = "Install the Claude Code CLI in this workspace. With v5 (default), authenticate with `claude /login` after first start; the credential survives in the home volume. Pick a model with `/model` (or `claude config set -g model opus`)."
  type         = "bool"
  default      = "false"
  mutable      = true
}

data "coder_parameter" "enable_claude_code_tasks" {
  name         = "enable_claude_code_tasks"
  display_name = "Pin Claude Code to v4 for Coder Tasks"
  description  = "Install claude-code v4 instead of v5 so it can act as a Coder Tasks agent (`task_app_id`). v4 predates the v5 runtime-OAuth refactor, so this trades the cleaner login flow for Tasks compatibility. Only relevant when Enable Claude Code is on."
  type         = "bool"
  default      = "false"
  mutable      = true
}

data "coder_parameter" "task_agent" {
  name         = "task_agent"
  display_name = "Tasks agent"
  description  = "Which agent answers Coder Tasks prompts. Only matters when more than one task-capable agent is installed. If the selected agent is not installed, the other one is used as a fallback."
  type         = "string"
  default      = "codex"
  mutable      = true
  form_type    = "dropdown"

  option {
    name  = "Codex (default)"
    value = "codex"
  }
  option {
    name  = "Claude Code (requires Pin Claude Code to v4)"
    value = "claude"
  }
}

data "coder_parameter" "claude_code_use_ai_gateway" {
  name         = "claude_code_use_ai_gateway"
  display_name = "Use Coder AI Gateway for Claude Code"
  description  = "Route Claude Code through Coder AI Gateway using the workspace owner's session. Requires Coder Premium and Coder >= 2.30. When enabled, no `/login` is needed."
  type         = "bool"
  default      = "false"
  mutable      = true
}

data "coder_parameter" "enable_codex" {
  name         = "enable_codex"
  display_name = "Enable Codex CLI"
  description  = "Install the OpenAI Codex CLI in this workspace. Authenticate with `codex login` after first start; the credential survives in the home volume. Set the reasoning level with the `--reasoning-effort` flag or `~/.codex/config.toml`."
  type         = "bool"
  default      = "false"
  mutable      = true
}

data "coder_parameter" "codex_use_ai_bridge" {
  name         = "codex_use_ai_bridge"
  display_name = "Use Coder AI Bridge for Codex"
  description  = "Route Codex through Coder AI Bridge using the workspace owner's session. Requires Coder Premium and Coder >= 2.30. When enabled, no `codex login` is needed."
  type         = "bool"
  default      = "false"
  mutable      = true
}

data "coder_workspace_preset" "custom" {
  name        = "Custom"
  description = "No pre-filled values; set every parameter yourself. Use this to clone a different repo or to skip the AI agents."
  default     = true

  parameters = {}
}

data "coder_workspace_preset" "statamic_skploft" {
  name        = "SKPloft Statamic"
  description = "Clones SKPloft/statamic and enables Codex as the Tasks agent."

  parameters = {
    git_repo_url = "https://github.com/SKPloft/statamic.git"
    git_branch   = ""
    php_version  = "8.3"
    enable_codex = "true"
    task_agent   = "codex"
  }
}

resource "coder_agent" "main" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = <<-EOT
    set -e

    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~ 2>/dev/null || true
      touch ~/.init_done
    fi
  EOT

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
  }

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "2_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "PHP Version"
    key          = "3_php_version"
    script       = "php -r 'echo PHP_VERSION;'"
    interval     = 86400
    timeout      = 5
  }

  metadata {
    display_name = "Composer Version"
    key          = "4_composer_version"
    script       = "composer --version --no-ansi 2>/dev/null | awk '{print $3}'"
    interval     = 86400
    timeout      = 5
  }
}

module "proxy-env" {
  count     = data.coder_workspace.me.start_count
  source    = "git::https://github.com/SKPloft/coder-registry.git//registry/skploft/modules/proxy-env?ref=skploft/templates"
  agent_id  = coder_agent.main.id
  proxy_url = local.proxy_url
  no_proxy  = local.no_proxy
}

module "git-clone" {
  count       = data.coder_parameter.git_repo_url.value != "" ? data.coder_workspace.me.start_count : 0
  source      = "registry.coder.com/coder/git-clone/coder"
  version     = "~> 1.0"
  agent_id    = coder_agent.main.id
  url         = data.coder_parameter.git_repo_url.value
  branch_name = data.coder_parameter.git_branch.value
  base_dir    = "~/projects"
}

module "code-server" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/code-server/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  folder   = "/home/coder/projects"
  order    = 1
}

module "jetbrains" {
  count           = data.coder_workspace.me.start_count
  source          = "registry.coder.com/coder/jetbrains/coder"
  version         = "~> 1.0"
  agent_id        = coder_agent.main.id
  agent_name      = "main"
  folder          = "/home/coder/projects"
  coder_app_order = 2
}

module "claude-code" {
  count             = local.use_claude_v5 ? data.coder_workspace.me.start_count : 0
  source            = "registry.coder.com/coder/claude-code/coder"
  version           = "~> 5.0"
  agent_id          = coder_agent.main.id
  workdir           = "/home/coder/projects"
  enable_ai_gateway = data.coder_parameter.claude_code_use_ai_gateway.value == "true"
}

module "claude-code-v4" {
  count          = local.use_claude_v4 ? data.coder_workspace.me.start_count : 0
  source         = "registry.coder.com/coder/claude-code/coder"
  version        = "~> 4.0"
  agent_id       = coder_agent.main.id
  workdir        = "/home/coder/projects"
  claude_api_key = ""
  ai_prompt      = data.coder_task.me.prompt
}

module "codex" {
  count           = local.use_codex ? data.coder_workspace.me.start_count : 0
  source          = "registry.coder.com/coder-labs/codex/coder"
  version         = "~> 4.3"
  agent_id        = coder_agent.main.id
  workdir         = "/home/coder/projects"
  enable_aibridge = data.coder_parameter.codex_use_ai_bridge.value == "true"
  ai_prompt       = data.coder_task.me.prompt
  report_tasks    = true
}

resource "coder_ai_task" "task" {
  count  = local.has_task_agent ? data.coder_workspace.me.start_count : 0
  app_id = local.task_app_id
}

resource "docker_image" "main" {
  name = "coder-${data.coder_workspace.me.id}-php-laravel"
  build {
    context = "./build"
    build_args = {
      PHP_VERSION = data.coder_parameter.php_version.value
      USER        = "coder"
      HTTP_PROXY  = local.proxy_url
      HTTPS_PROXY = local.proxy_url
      NO_PROXY    = local.no_proxy
    }
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/*") : filesha1("${path.module}/${f}")]))
    proxy    = "${local.proxy_url}|${local.no_proxy}"
  }
}

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
  lifecycle {
    ignore_changes = all
  }
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

resource "docker_container" "workspace" {
  count    = data.coder_workspace.me.start_count
  image    = docker_image.main.image_id
  name     = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname = data.coder_workspace.me.name

  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }

  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}

resource "coder_metadata" "container_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = docker_container.workspace[0].id

  item {
    key   = "PHP version"
    value = data.coder_parameter.php_version.value
  }
  item {
    key   = "Git repository"
    value = data.coder_parameter.git_repo_url.value != "" ? data.coder_parameter.git_repo_url.value : "(none — clone manually)"
  }
}
