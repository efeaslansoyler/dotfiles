#/usr/bin/env bash

set -euo pipefail
# Wallpapers Directory
WALLPAPERS_DIR="$HOME/.config/hypr/wallpapers"
# Hyprlock Config File Path
HYPRLOCK_CONFIG="$HOME/.config/hypr/hyprlock.conf"
# Current Directory
CWD="$(pwd)"

cd "$WALLPAPERS_DIR" || exit 1

# Handle spaces in filenames
IFS=$'\n'

# Grab the user-selected wallpaper
SELECTED_WALLPAPER=$(for a in *.jpg *.png; do echo -en "$a\0icon\x1f$a\n"; done | rofi -dmenu -show-icons \
  -p "Wallpaper" \
  -theme-str "entry { placeholder: 'Search Wallpaper...'; }")

notify-send "Generating theme according to $SELECTED_WALLPAPER"

swww img "$SELECTED_WALLPAPER" --transition-type grow --transition-pos top-right --transition-step 90 --transition-fps 180

matugen image "$SELECTED_WALLPAPER"

wal -i "$SELECTED_WALLPAPER" -n -t -e

FULL_PATH="$WALLPAPERS_DIR/$SELECTED_WALLPAPER"

sed -i "/^background {/,/}/s|^\(\s*path\s*=\s*\).*|\1$FULL_PATH|" "$HYPRLOCK_CONFIG"

systemctl --user restart waybar

pywalfox update

notify-send "Theme generated according to $SELECTED_WALLPAPER"

cd "$CWD" || exit 1
