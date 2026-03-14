#!/usr/bin/env bash

export PATH="/run/current-system/sw/bin:$PATH"

current_workspace=$(aerospace list-workspaces --focused)

window_id=$(aerospace list-windows --all --format "%{window-id}|%{app-name}" | grep "|Raycast" | cut -d'|' -f1 | head -1)

if [ -n "$window_id" ]; then
  # Check if already on current workspace
  already_here=$(aerospace list-windows --workspace "$current_workspace" --format "%{window-id}" | grep -c "$window_id")

  if [ "$already_here" -gt 0 ]; then
    # Already here → just focus it
    aerospace focus --window-id "$window_id"
  else
    # On different workspace → move it here
    aerospace move-node-to-workspace "$current_workspace" --window-id "$window_id"
    aerospace focus --window-id "$window_id"
  fi
else
  # Not open → open it
  open "raycast://extensions/raycast/raycast-ai/ai-chat"
  sleep 0.4
  window_id=$(aerospace list-windows --all --format "%{window-id}|%{app-name}" | grep "|Raycast" | cut -d'|' -f1 | head -1)
  if [ -n "$window_id" ]; then
    aerospace move-node-to-workspace "$current_workspace" --window-id "$window_id"
    aerospace focus --window-id "$window_id"
  fi
fi
