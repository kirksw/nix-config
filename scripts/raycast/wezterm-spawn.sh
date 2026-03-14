#!/usr/bin/env zsh

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title New WezTerm Window
# @raycast.mode silent

# Optional parameters:
# @raycast.icon wezterm.svg

# Documentation:
# @raycast.author kirksw
# @raycast.authorURL https://raycast.com/kirksw

wezterm start
# if pgrep -x "WezTerm" >/dev/null 2>&1; then
#   wezterm cli spawn --new-window 2>/dev/null
# else
#   wezterm start
# fi
