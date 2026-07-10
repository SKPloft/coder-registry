terraform {
  required_version = ">= 1.0"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.12"
    }
  }
}

variable "agent_id" {
  type        = string
  description = "The ID of a Coder agent."
}

variable "order" {
  type        = number
  description = "The order determines the position of app in the UI presentation. The lowest order is shown first and apps with equal order are sorted by name (ascending order)."
  default     = null
}

variable "group" {
  type        = string
  description = "The name of a group that this app belongs to."
  default     = null
}

variable "icon" {
  type        = string
  description = "The icon to use for the app."
  default     = "/icon/warp.svg"
}

variable "workdir" {
  type        = string
  description = "The folder to run the Warp Oz agent in."
  default     = "/home/coder"
}

variable "install_oz" {
  type        = bool
  description = "Whether to install the Warp Oz CLI. The Oz CLI powers the web interface and Coder Tasks."
  default     = true
}

variable "install_warp_terminal" {
  type        = bool
  description = "Whether to install the Warp GUI terminal (warp-terminal). Requires a desktop environment with OpenGL/Vulkan support; headless workspaces should leave this disabled."
  default     = false
}

variable "warp_api_key" {
  type        = string
  description = "Warp API key passed to the Oz CLI via the WARP_API_KEY env var. Required for headless/task runs; create one in the Oz web app."
  default     = ""
  sensitive   = true
}

variable "ai_prompt" {
  type        = string
  description = "Initial task prompt for the Warp Oz agent. Wire from coder_ai_task.task.prompt for Coder Tasks."
  default     = ""
}

variable "report_tasks" {
  type        = bool
  description = "Whether to enable task reporting to the Coder UI by injecting the Coder MCP server (coder_report_task) and prefixing the prompt with reporting instructions."
  default     = true
}

variable "cli_app" {
  type        = bool
  description = "Whether to create a CLI workspace app that attaches to the AgentAPI session."
  default     = false
}

variable "web_app_display_name" {
  type        = string
  description = "Display name for the web app."
  default     = "Warp"
}

variable "cli_app_display_name" {
  type        = string
  description = "Display name for the CLI app."
  default     = "Warp CLI"
}

variable "subdomain" {
  type        = bool
  description = "Whether to use a subdomain for AgentAPI."
  default     = false
}

variable "model" {
  type        = string
  description = "Override the Oz agent's default model (passed via oz --model)."
  default     = ""
}

variable "profile" {
  type        = string
  description = "Oz agent profile to use (passed via oz --profile)."
  default     = ""
}

variable "mcp" {
  type        = string
  description = "Additional MCP server configuration as inline JSON passed to oz via --mcp. Example: {\"github\":{\"url\":\"https://api.githubcopilot.com/mcp/\"}}."
  default     = ""
}

variable "pre_install_script" {
  type        = string
  description = "Custom script to run before installing Warp."
  default     = null
}

variable "post_install_script" {
  type        = string
  description = "Custom script to run after installing Warp."
  default     = null
}

variable "install_agentapi" {
  type        = bool
  description = "Whether to install AgentAPI."
  default     = true
}

variable "agentapi_version" {
  type        = string
  description = "The version of AgentAPI to install."
  default     = "v0.11.2"
}

resource "coder_env" "warp_api_key" {
  count    = var.warp_api_key != "" ? 1 : 0
  agent_id = var.agent_id
  name     = "WARP_API_KEY"
  value    = var.warp_api_key
}

locals {
  workdir         = trimsuffix(var.workdir, "/")
  app_slug        = "warp"
  install_script  = file("${path.module}/scripts/install.sh")
  start_script    = file("${path.module}/scripts/start.sh")
  module_dir_name = ".warp-module"
}

module "agentapi" {
  source  = "registry.coder.com/coder/agentapi/coder"
  version = "2.0.0"

  agent_id             = var.agent_id
  web_app_slug         = local.app_slug
  web_app_order        = var.order
  web_app_group        = var.group
  web_app_icon         = var.icon
  web_app_display_name = var.web_app_display_name
  cli_app              = var.cli_app
  cli_app_slug         = "${local.app_slug}-cli"
  cli_app_display_name = var.cli_app_display_name
  agentapi_subdomain   = var.subdomain
  folder               = local.workdir
  module_dir_name      = local.module_dir_name
  install_agentapi     = var.install_agentapi
  agentapi_version     = var.agentapi_version
  pre_install_script   = var.pre_install_script
  post_install_script  = var.post_install_script
  start_script = <<-EOT
    #!/bin/bash
    set -o errexit
    set -o pipefail

    echo -n '${base64encode(local.start_script)}' | base64 -d > /tmp/start.sh
    chmod +x /tmp/start.sh

    ARG_WORKDIR='${local.workdir}' \
    ARG_APP_SLUG='${local.app_slug}' \
    ARG_AI_PROMPT='${base64encode(var.ai_prompt)}' \
    ARG_REPORT_TASKS='${var.report_tasks}' \
    ARG_MODEL='${var.model}' \
    ARG_PROFILE='${var.profile}' \
    ARG_MCP='${var.mcp != "" ? base64encode(var.mcp) : ""}' \
    /tmp/start.sh
  EOT

  install_script = <<-EOT
    #!/bin/bash
    set -o errexit
    set -o pipefail

    echo -n '${base64encode(local.install_script)}' | base64 -d > /tmp/install.sh
    chmod +x /tmp/install.sh

    ARG_INSTALL_OZ='${var.install_oz}' \
    ARG_INSTALL_WARP_TERMINAL='${var.install_warp_terminal}' \
    /tmp/install.sh
  EOT
}

output "task_app_id" {
  value       = module.agentapi.task_app_id
  description = "The ID of the AgentAPI web app used for Coder Tasks. Wire into coder_ai_task.app_id."
}
