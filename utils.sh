#!/usr/bin/env bash
set -euo pipefail

info() {
  echo -e "\033[1;34m[INFO]\033[0m $*"
}

error() {
  echo -e "\033[1;31m[ERROR]\033[0m $*" >&2
}

# Check if a package is installed
is_installed() {
  yay -Q "$1" &>/dev/null
}

# Install packages by category name
install_category() {
  local category_name="$1"
  local -n pkgs="$category_name"
  local to_install=()

  for pkg in "${pkgs[@]}"; do
    if ! is_installed "$pkg"; then
      to_install+=("$pkg")
    else
      info "$pkg is already installed."
    fi
  done

  if [ "${#to_install[@]}" -gt 0 ]; then
    info "Installing: ${to_install[*]}"
    yay -S --needed --noconfirm "${to_install[@]}"
  else
    info "All packages in $category_name are already installed."
  fi
}
