#/usr/bin/env bash

set -euo pipefail

# Wallpapers Directory
WALLPAPERS_DIR="$HOME/.config/hypr/wallpapers"

# Current Directory
CWD="$(pwd)"

cd "$WALLPAPERS_DIR" || exit 1

# Handle spaces in filenames
IFS=$'\n'

# Grab the user-selected wallpaper
SELECTED_WALLPAPER=$(for a in *.jpg *.png; do echo -en "$a\0icon\x1f$a\n"; done | rofi -dmenu -p "Select your wallpaper")

# If not empty
if [ -n "$SELECTED_WALLPAPER" ]; then
  notify-send "Setting wallpaper to $SELECTED_WALLPAPER"

  swww img "$WALLPAPERS_DIR/$SELECTED_WALLPAPER" --transition-type grow --transition-pos top-right --transition-step 90

  notify-send "Wallpaper set to $SELECTED_WALLPAPER"
fi

# Go back to the original directory
cd "$CWD" || exit 1
