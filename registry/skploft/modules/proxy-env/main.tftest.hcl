run "empty_proxy_creates_no_envs" {
  command = plan

  variables {
    agent_id = "test-agent-id"
  }

  assert {
    condition     = length(resource.coder_env.proxy) == 0
    error_message = "Empty proxy_url must produce zero coder_env resources."
  }

  assert {
    condition     = output.applied == false
    error_message = "applied output must be false when proxy_url is empty."
  }
}

run "proxy_url_creates_six_envs" {
  command = plan

  variables {
    agent_id  = "test-agent-id"
    proxy_url = "http://172.17.0.1:17891"
  }

  assert {
    condition     = length(resource.coder_env.proxy) == 6
    error_message = "Setting proxy_url must produce exactly six coder_env resources (3 names × 2 casings)."
  }

  assert {
    condition     = resource.coder_env.proxy["HTTP_PROXY"].value == "http://172.17.0.1:17891"
    error_message = "HTTP_PROXY value must equal proxy_url."
  }

  assert {
    condition     = resource.coder_env.proxy["http_proxy"].value == "http://172.17.0.1:17891"
    error_message = "Lowercase http_proxy value must equal proxy_url."
  }

  assert {
    condition     = resource.coder_env.proxy["HTTPS_PROXY"].value == "http://172.17.0.1:17891"
    error_message = "HTTPS_PROXY value must equal proxy_url (proxy is the same for HTTP and HTTPS by design)."
  }

  assert {
    condition     = resource.coder_env.proxy["NO_PROXY"].value == "localhost,127.0.0.1,host.docker.internal,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
    error_message = "NO_PROXY default must include the documented private/loopback ranges."
  }

  assert {
    condition     = resource.coder_env.proxy["no_proxy"].value == resource.coder_env.proxy["NO_PROXY"].value
    error_message = "no_proxy and NO_PROXY must hold the same value."
  }

  assert {
    condition     = output.applied == true
    error_message = "applied output must be true when proxy_url is set."
  }
}

run "no_proxy_override_takes_effect" {
  command = plan

  variables {
    agent_id  = "test-agent-id"
    proxy_url = "http://proxy.corp.example.com:3128"
    no_proxy  = "localhost,*.corp.example.com"
  }

  assert {
    condition     = resource.coder_env.proxy["NO_PROXY"].value == "localhost,*.corp.example.com"
    error_message = "Caller-supplied no_proxy must replace the default."
  }
}

run "rejects_invalid_proxy_url" {
  command = plan

  variables {
    agent_id  = "test-agent-id"
    proxy_url = "tcp://172.17.0.1:17891"
  }

  expect_failures = [
    var.proxy_url,
  ]
}
