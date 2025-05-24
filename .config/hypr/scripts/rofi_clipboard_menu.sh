#!/usr/bin/env bash

set -euo pipefail

rofi_input=$(printf "%s\n%s" "Clear All History" "$(cliphist list)")
# List Clipboard History and capture the selected item
selected=$(
  echo -e "$rofi_input" | rofi -dmenu -show-icons \
    -p "Clipboard" \
    -mesg "Select an item to copy or remove" \
    -theme-str "window { width: 600; }" \
    -theme-str "listview { lines: 10; scrollbar: true; }" \
    -theme-str "entry { placeholder: 'Search history...'; }" \
    -format 's'
)

# Check if the user selected something
if [ -n "$selected" ]; then
  if [[ "$selected" == "Clear All History" ]]; then
    # Clear the clipboard history
    cliphist wipe
    notify-send "Clipboard" "Cleared all history"
    exit 0
  else
    content_to_process="${selected#*$'\t'}"

    action_options=$(printf "%s\n%s\n%s" \
      "Copy to Clipboard" \
      "Remove from History" \
      "Cancel")
    chosen_action=$(echo -e "$action_options" |
      rofi -dmenu -show-icons -p "" -format 's')

    if [ -z "$chosen_action" ] || [[ "$chosen_action" == "Cancel" ]]; then
      notify-send "Clipboard" "Cancelled"
      exit 0
    fi

    case "$chosen_action" in
    "Copy to Clipboard")
      # Copy the selected item to the clipboard
      printf "%s" "$content_to_process" | wl-copy
      notify-send "Clipboard" "Copied: $content_to_process"
      ;;
    "Remove from History")
      # Remove the selected item from the history
      if cliphist delete-query "$content_to_process"; then
        notify-send "Clipboard" "Removed: $content_to_process"
      else
        notify-send "Clipboard" "Failed to remove: $content_to_process"
      fi
      ;;
    *)
      notify-send "Clipboard" "Unknown action: $chosen_action"
      ;;
    esac
  fi
fi
