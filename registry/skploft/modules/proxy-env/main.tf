terraform {
  required_version = ">= 1.0"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 0.12"
    }
  }
}

variable "agent_id" {
  description = "The ID of a Coder agent."
  type        = string
}

variable "proxy_url" {
  description = "Unified proxy URL written to HTTP_PROXY/HTTPS_PROXY (and lowercase variants). Set in the template; should not be exposed as a workspace parameter. Leave empty to install no environment variables at all."
  type        = string
  default     = ""

  validation {
    condition     = var.proxy_url == "" || can(regex("^https?://", var.proxy_url))
    error_message = "proxy_url must be empty or start with http:// or https://."
  }
}

variable "no_proxy" {
  description = "Comma-separated hosts/CIDRs that bypass the proxy. Default covers loopback, host.docker.internal, and the IANA private IPv4 ranges."
  type        = string
  default     = "localhost,127.0.0.1,host.docker.internal,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
}

locals {
  env_vars = var.proxy_url == "" ? {} : {
    HTTP_PROXY  = var.proxy_url
    HTTPS_PROXY = var.proxy_url
    http_proxy  = var.proxy_url
    https_proxy = var.proxy_url
    NO_PROXY    = var.no_proxy
    no_proxy    = var.no_proxy
  }
}

resource "coder_env" "proxy" {
  for_each = local.env_vars
  agent_id = var.agent_id
  name     = each.key
  value    = each.value
}

output "applied" {
  description = "Whether proxy environment variables were installed for this workspace."
  value       = var.proxy_url != ""
}
