#!/bin/bash

if which openrgb >/dev/null; then
    openrgb --startminimized -p vuk &
fi

if which swayidle >/dev/null; then
    swayidle -w \
        timeout 290 'notify-send "Idle" "Going to sleep in 10 seconds..."' \
        timeout 300 \
        'if ! ~/.config/scripts/media-playing.sh; then pidof hyprlock || hyprlock; fi'
fi
exit 0
