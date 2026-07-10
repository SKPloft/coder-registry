#!/bin/bash
set -euo pipefail

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

ARG_WORKDIR=${ARG_WORKDIR:-"$HOME"}
ARG_APP_SLUG=${ARG_APP_SLUG:-"warp"}
ARG_AI_PROMPT=$(echo -n "${ARG_AI_PROMPT:-}" | base64 -d 2>/dev/null || echo "")
ARG_REPORT_TASKS=${ARG_REPORT_TASKS:-true}
ARG_MODEL=${ARG_MODEL:-}
ARG_PROFILE=${ARG_PROFILE:-}
ARG_MCP=$(echo -n "${ARG_MCP:-}" | base64 -d 2>/dev/null || echo "")

printf "=== START CONFIG ===\n"
printf "ARG_WORKDIR: %s\n" "$ARG_WORKDIR"
printf "ARG_APP_SLUG: %s\n" "$ARG_APP_SLUG"
printf "ARG_REPORT_TASKS: %s\n" "$ARG_REPORT_TASKS"
printf "ARG_MODEL: %s\n" "$ARG_MODEL"
printf "ARG_PROFILE: %s\n" "$ARG_PROFILE"
if [ -n "$ARG_AI_PROMPT" ]; then
  printf "ARG_AI_PROMPT: [AI PROMPT RECEIVED]\n"
else
  printf "ARG_AI_PROMPT: [NOT PROVIDED]\n"
fi
if [ -n "$ARG_MCP" ]; then
  printf "ARG_MCP: [RECEIVED]\n"
else
  printf "ARG_MCP: [NOT PROVIDED]\n"
fi
if [ -n "${WARP_API_KEY:-}" ]; then
  printf "WARP_API_KEY: [SET]\n"
else
  printf "WARP_API_KEY: [NOT SET]\n"
fi
printf "==================================\n"

if ! command_exists oz; then
  printf "ERROR: Warp Oz CLI is not installed. Set install_oz to true.\n"
  exit 1
fi

OZ_ARGS=(agent run)

if [ -n "$ARG_MODEL" ]; then
  OZ_ARGS+=(--model "$ARG_MODEL")
fi

if [ -n "$ARG_PROFILE" ]; then
  OZ_ARGS+=(--profile "$ARG_PROFILE")
fi

if [ "$ARG_REPORT_TASKS" = "true" ]; then
  coder_mcp_config=$(cat <<EOF
{"coder":{"command":"coder","args":["exp","mcp","server"],"env":{"CODER_MCP_APP_STATUS_SLUG":"${ARG_APP_SLUG}","CODER_MCP_AI_AGENTAPI_URL":"http://localhost:3284","CODER_AGENT_URL":"${CODER_AGENT_URL:-}","CODER_AGENT_TOKEN":"${CODER_AGENT_TOKEN:-}","CODER_MCP_ALLOWED_TOOLS":"coder_report_task"}}}
EOF
)
  OZ_ARGS+=(--mcp "$coder_mcp_config")
fi

if [ -n "$ARG_MCP" ]; then
  OZ_ARGS+=(--mcp "$ARG_MCP")
fi

printf "Starting in directory: %s\n" "$ARG_WORKDIR"
cd "$ARG_WORKDIR"

if [ -n "$ARG_AI_PROMPT" ]; then
  if [ "$ARG_REPORT_TASKS" = "true" ]; then
    PROMPT="Every step of the way, report your progress using the coder_report_task tool with proper summary and statuses. Your task at hand: $ARG_AI_PROMPT"
  else
    PROMPT="$ARG_AI_PROMPT"
  fi
  OZ_ARGS+=(--prompt "$PROMPT")

  if [ -z "${WARP_API_KEY:-}" ]; then
    printf "WARNING: WARP_API_KEY is not set. Headless task runs require it. Run 'oz login' first or set warp_api_key on the module.\n"
  fi

  printf "Running: oz %s\n" "${OZ_ARGS[*]}"
  exec agentapi server --term-width 67 --term-height 1190 -- oz "${OZ_ARGS[@]}"
else
  printf "No prompt provided. Starting an interactive shell with oz on PATH.\n"
  printf "Run 'oz agent run --prompt \"...\"' inside the Warp web app to start a task.\n"
  exec agentapi server --term-width 67 --term-height 1190 -- bash -l
fi
