---
display_name: Proxy Env
description: Set HTTP_PROXY / HTTPS_PROXY / NO_PROXY (and their lowercase variants) on a Coder workspace agent.
icon: ../../../../.icons/coder.svg
verified: false
tags: [helper, proxy, network, env]
---

# Proxy Env

Sets the standard HTTP proxy environment variables on a Coder workspace agent so any tool that respects them (curl, git, npm, composer, apt, pip, gradle, etc.) routes through a corporate or local proxy.

The proxy URL is intended to be set by the **template author**, not the workspace owner — this module exposes a Terraform variable, not a `coder_parameter`. That keeps the proxy invisible in the create-workspace UI and avoids workspace owners pointing at arbitrary endpoints.

```tf
module "proxy-env" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/skploft/proxy-env/coder"
  version   = "1.0.0"
  agent_id  = coder_agent.main.id
  proxy_url = "http://172.17.0.1:17891"
}
```

The module writes six `coder_env` resources on the agent: `HTTP_PROXY`, `HTTPS_PROXY`, `http_proxy`, `https_proxy`, `NO_PROXY`, `no_proxy`. Both casings are present because some tools (notably curl, wget, and most Python libraries) only consult lowercase, while others (Go, Java) only consult uppercase.

`NO_PROXY` defaults to `localhost,127.0.0.1,host.docker.internal,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16`. Override it when the workspace needs to reach additional internal hosts directly:

```tf
module "proxy-env" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/skploft/proxy-env/coder"
  version   = "1.0.0"
  agent_id  = coder_agent.main.id
  proxy_url = "http://proxy.corp.example.com:3128"
  no_proxy  = "localhost,127.0.0.1,*.corp.example.com,10.0.0.0/8"
}
```

Leaving `proxy_url` empty (the default) installs nothing — useful when the same module is consumed in templates that only sometimes need a proxy.

> [!NOTE]
> `coder_env` values apply at workspace start, so changes to `proxy_url` take effect on the next workspace start, not on hot reload of an existing session.

> [!TIP]
> The `applied` output is `true` whenever proxy variables were installed — handy for templates that want to surface a status badge or gate downstream proxy-aware setup steps.
