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
  paru -Q "$1" &>/dev/null
}


