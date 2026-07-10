#!/bin/bash
set -euo pipefail

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

ARG_INSTALL_OZ=${ARG_INSTALL_OZ:-true}
ARG_INSTALL_WARP_TERMINAL=${ARG_INSTALL_WARP_TERMINAL:-false}

printf "=== INSTALL CONFIG ===\n"
printf "ARG_INSTALL_OZ: %s\n" "$ARG_INSTALL_OZ"
printf "ARG_INSTALL_WARP_TERMINAL: %s\n" "$ARG_INSTALL_WARP_TERMINAL"
printf "==================================\n"

install_apt() {
  if ! command_exists apt-get; then
    return 1
  fi
  sudo apt-get update -qq
  sudo apt-get install -y wget gpg ca-certificates
  wget -qO- https://releases.warp.dev/linux/keys/warp.asc | gpg --dearmor > /tmp/warpdotdev.gpg
  sudo install -D -o root -g root -m 644 /tmp/warpdotdev.gpg /etc/apt/keyrings/warpdotdev.gpg
  rm -f /tmp/warpdotdev.gpg
  arch=$(dpkg --print-architecture)
  if [ "$arch" = "arm64" ]; then
    repo_arch="arm64"
  else
    repo_arch="amd64"
  fi
  sudo sh -c "echo \"deb [arch=${repo_arch} signed-by=/etc/apt/keyrings/warpdotdev.gpg] https://releases.warp.dev/linux/deb stable main\" > /etc/apt/sources.list.d/warpdotdev.list"
  sudo apt-get update -qq
  if [ "$ARG_INSTALL_OZ" = "true" ]; then
    sudo apt-get install -y oz-stable || echo "Warning: Failed to install oz-stable via apt."
  fi
  if [ "$ARG_INSTALL_WARP_TERMINAL" = "true" ]; then
    sudo apt-get install -y warp-terminal || echo "Warning: Failed to install warp-terminal via apt. It requires a desktop environment with OpenGL/Vulkan support."
  fi
}

install_dnf() {
  if ! command_exists dnf; then
    return 1
  fi
  sudo rpm --import https://releases.warp.dev/linux/keys/warp.asc
  sudo sh -c "echo -e \"[warpdotdev]\nname=warpdotdev\nbaseurl=https://releases.warp.dev/linux/rpm/stable\nenabled=1\ngpgcheck=1\ngpgkey=https://releases.warp.dev/linux/keys/warp.asc\" > /etc/yum.repos.d/warpdotdev.repo"
  if [ "$ARG_INSTALL_OZ" = "true" ]; then
    sudo dnf install -y oz-stable || echo "Warning: Failed to install oz-stable via dnf."
  fi
  if [ "$ARG_INSTALL_WARP_TERMINAL" = "true" ]; then
    sudo dnf install -y warp-terminal || echo "Warning: Failed to install warp-terminal via dnf. It requires a desktop environment with OpenGL/Vulkan support."
  fi
}

install_pacman() {
  if ! command_exists pacman; then
    return 1
  fi
  sudo sh -c "echo -e '\n[warpdotdev]\nServer = https://releases.warp.dev/linux/pacman/\$repo/\$arch' >> /etc/pacman.conf"
  sudo pacman-key -r "linux-maintainers@warp.dev" || echo "Warning: pacman-key -r failed; you may need to manually sign the Warp key."
  sudo pacman-key --lsign-key "linux-maintainers@warp.dev" || echo "Warning: pacman-key --lsign-key failed."
  sudo pacman -Sy
  if [ "$ARG_INSTALL_OZ" = "true" ]; then
    sudo pacman -S --noconfirm oz-stable || echo "Warning: Failed to install oz-stable via pacman."
  fi
  if [ "$ARG_INSTALL_WARP_TERMINAL" = "true" ]; then
    sudo pacman -S --noconfirm warp-terminal || echo "Warning: Failed to install warp-terminal via pacman. It requires a desktop environment with OpenGL/Vulkan support."
  fi
}

if [ "$ARG_INSTALL_OZ" = "true" ] || [ "$ARG_INSTALL_WARP_TERMINAL" = "true" ]; then
  if ! install_apt && ! install_dnf && ! install_pacman; then
    echo "Warning: No supported package manager (apt/dnf/pacman) found. Install the Warp Oz CLI manually: https://docs.warp.dev/reference/cli/"
  fi
fi

if [ "$ARG_INSTALL_OZ" = "true" ]; then
  if command_exists oz; then
    printf "Oz CLI installed: %s\n" "$(command -v oz)"
  else
    echo "Warning: oz command not found on PATH after install. The package name may differ on your distribution; see https://docs.warp.dev/reference/cli/"
  fi
fi

if [ "$ARG_INSTALL_WARP_TERMINAL" = "true" ]; then
  if command_exists warp-terminal; then
    printf "Warp terminal installed: %s\n" "$(command -v warp-terminal)"
  else
    echo "Warning: warp-terminal command not found on PATH after install."
  fi
fi

echo "Warp module install completed."
