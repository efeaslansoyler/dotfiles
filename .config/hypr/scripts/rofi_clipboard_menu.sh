#!/usr/bin/env bash

set -euo pipefail

rofi_input=$(printf "%s\n%s" "Clear All History" "$(cliphist list)")
# List Clipboard History and capture the selected item
selected=$(echo -e "$rofi_input" | rofi -dmenu -p "Clipboard" -format 's')

# Check if the user selected something
if [ -n "$selected" ]; then
  if [[ "$selected" == "Clear All History" ]]; then
    # Clear the clipboard history
    cliphist wipe
    notify-send "Clipboard" "Cleared all history"
    exit 0
  else
    content_to_process="${selected#*$'\t'}"

    max_prompt_len=40
    prompt_content_display="$content_to_process"
    if [ ${#content_to_process} -gt $max_prompt_len ]; then
      prompt_content_display="${content_to_process:0:$max_prompt_len}..."
    fi

    action_options=$(printf "%s\n%s\n%s" \
      "Copy to Clipboard" \
      "Remove from History" \
      "Cancel")
    chosen_action=$(echo -e "$action_options" |
      rofi -dmenu -p "Item: '$prompt_content_display'" -format 's')

    if [ -z "$chosen_action" ] || [[ "$chosen_action" == "Cancel" ]]; then
      notify-send "Clipboard" "Cancelled"
      exit 0
    fi

    case "$chosen_action" in
    "Copy to Clipboard")
      # Copy the selected item to the clipboard
      printf "%s" "$content_to_process" | wl-copy
      notify-send "Clipboard" "Copied: $prompt_content_display"
      ;;
    "Remove from History")
      # Remove the selected item from the history
      if cliphist delete-query "$content_to_process"; then
        notify-send "Clipboard" "Removed: $prompt_content_display"
      else
        notify-send "Clipboard" "Failed to remove: $prompt_content_display"
      fi
      ;;
    *)
      notify-send "Clipboard" "Unknown action: $chosen_action"
      ;;
    esac
  fi
fi
