run "defaults_are_correct" {
  command = plan

  variables {
    agent_id = "test-agent"
    workdir  = "/home/coder/project"
  }

  assert {
    condition     = var.install_oz == true
    error_message = "Oz CLI installation should be enabled by default"
  }

  assert {
    condition     = var.install_warp_terminal == false
    error_message = "Warp GUI terminal installation should be disabled by default"
  }

  assert {
    condition     = var.install_agentapi == true
    error_message = "AgentAPI installation should be enabled by default"
  }

  assert {
    condition     = var.agentapi_version == "v0.11.2"
    error_message = "Default AgentAPI version should be 'v0.11.2'"
  }

  assert {
    condition     = var.report_tasks == true
    error_message = "Task reporting should be enabled by default"
  }

  assert {
    condition     = var.cli_app == false
    error_message = "CLI app should be disabled by default"
  }

  assert {
    condition     = var.subdomain == false
    error_message = "Subdomain should be disabled by default"
  }

  assert {
    condition     = var.web_app_display_name == "Warp"
    error_message = "Default web app display name should be 'Warp'"
  }

  assert {
    condition     = var.cli_app_display_name == "Warp CLI"
    error_message = "Default CLI app display name should be 'Warp CLI'"
  }

  assert {
    condition     = local.app_slug == "warp"
    error_message = "App slug should be 'warp'"
  }

  assert {
    condition     = local.module_dir_name == ".warp-module"
    error_message = "Module dir name should be '.warp-module'"
  }

  assert {
    condition     = local.workdir == "/home/coder/project"
    error_message = "Workdir should be trimmed of trailing slash"
  }

  assert {
    condition     = var.warp_api_key == ""
    error_message = "Warp API key should default to empty"
  }

  assert {
    condition     = !can(resource.coder_env.warp_api_key[0])
    error_message = "No WARP_API_KEY env should be created when warp_api_key is empty"
  }
}

run "workdir_trailing_slash_trimmed" {
  command = plan

  variables {
    agent_id = "test-agent"
    workdir  = "/home/coder/project/"
  }

  assert {
    condition     = local.workdir == "/home/coder/project"
    error_message = "Workdir should be trimmed of trailing slash"
  }
}

run "warp_api_key_creates_env" {
  command = plan

  variables {
    agent_id     = "test-agent"
    workdir      = "/home/coder/project"
    warp_api_key = "wk-test-key"
  }

  assert {
    condition     = can(resource.coder_env.warp_api_key[0])
    error_message = "WARP_API_KEY env should be created when warp_api_key is set"
  }

  assert {
    condition     = resource.coder_env.warp_api_key[0].name == "WARP_API_KEY"
    error_message = "Env var name should be WARP_API_KEY"
  }
}

run "cli_app_configuration" {
  command = plan

  variables {
    agent_id             = "test-agent"
    workdir              = "/home/coder/project"
    cli_app              = true
    cli_app_display_name = "Custom Warp CLI"
  }

  assert {
    condition     = var.cli_app == true
    error_message = "CLI app should be enabled when specified"
  }

  assert {
    condition     = var.cli_app_display_name == "Custom Warp CLI"
    error_message = "Custom CLI app display name should be set"
  }
}

run "install_flags_configuration" {
  command = plan

  variables {
    agent_id              = "test-agent"
    workdir               = "/home/coder/project"
    install_oz            = false
    install_warp_terminal = true
    install_agentapi      = false
  }

  assert {
    condition     = var.install_oz == false
    error_message = "Oz CLI installation should be disabled when specified"
  }

  assert {
    condition     = var.install_warp_terminal == true
    error_message = "Warp GUI terminal installation should be enabled when specified"
  }

  assert {
    condition     = var.install_agentapi == false
    error_message = "AgentAPI installation should be disabled when specified"
  }
}

run "ai_configuration_variables" {
  command = plan

  variables {
    agent_id  = "test-agent"
    workdir   = "/home/coder/project"
    ai_prompt = "Refactor the auth module"
    model     = "claude-sonnet-4"
    profile   = "backend"
    mcp       = "{\"github\":{\"url\":\"https://api.githubcopilot.com/mcp/\"}}"
  }

  assert {
    condition     = var.ai_prompt == "Refactor the auth module"
    error_message = "AI prompt should be set correctly"
  }

  assert {
    condition     = var.model == "claude-sonnet-4"
    error_message = "Model should be set correctly"
  }

  assert {
    condition     = var.profile == "backend"
    error_message = "Profile should be set correctly"
  }

  assert {
    condition     = can(jsondecode(var.mcp))
    error_message = "MCP should be valid JSON"
  }
}

run "task_reporting_configuration" {
  command = plan

  variables {
    agent_id     = "test-agent"
    workdir      = "/home/coder/project"
    report_tasks = false
  }

  assert {
    condition     = var.report_tasks == false
    error_message = "Task reporting should be disabled when specified"
  }
}

run "custom_scripts_configuration" {
  command = plan

  variables {
    agent_id            = "test-agent"
    workdir             = "/home/coder/project"
    pre_install_script  = "#!/bin/bash\necho 'pre-install'"
    post_install_script = "#!/bin/bash\necho 'post-install'"
  }

  assert {
    condition     = var.pre_install_script != null
    error_message = "Pre-install script should be set"
  }

  assert {
    condition     = var.post_install_script != null
    error_message = "Post-install script should be set"
  }
}
