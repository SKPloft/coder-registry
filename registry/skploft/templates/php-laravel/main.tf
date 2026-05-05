terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

locals {
  username = data.coder_workspace_owner.me.name
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

resource "docker_image" "main" {
  name = "coder-${data.coder_workspace.me.id}-php-laravel"
  build {
    context = "./build"
    build_args = {
      PHP_VERSION = data.coder_parameter.php_version.value
      USER        = "coder"
    }
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/*") : filesha1("${path.module}/${f}")]))
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
