#!/usr/bin/env bash

set -euo pipefail

options=(
  "Reboot"
  "Shutdown"
)

chosen=$(printf '%s\n' "${options[@]}" | rofi -dmenu -p "Power Menu" -lines 2)

case $chosen in
"Reboot")
  systemctl reboot
  ;;
"Shutdown")
  systemctl poweroff
  ;;
*)
  echo "Invalid option"
  exit 1
  ;;
esac

exit 0
