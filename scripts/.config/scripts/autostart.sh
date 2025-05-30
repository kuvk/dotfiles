#!/bin/bash

IDLE="$HOME/.config/scripts/idle.sh"

if command -v openrgb >/dev/null; then
    openrgb --startminimized -p vuk &
fi

if command -v swayidle >/dev/null; then
    swayidle -w \
        timeout 290 'notify-send "Idle" "Locking in 10 seconds..."' \
        timeout 300 "if $IDLE; then pidof hyprlock || (hyprlock &); fi" \
        timeout 1800 "if $IDLE; then pidof hyprlock || (hyprlock &); sleep 0.1; systemctl suspend; fi"
fi
exit 0
