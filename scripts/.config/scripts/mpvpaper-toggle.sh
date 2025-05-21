#!/bin/bash

SOCKETS=(/tmp/mpv-socket*)
CHANGED=false
NEW_STATE=""

if [ ${#SOCKETS[@]} -eq 0 ]; then
    notify-send "mpvpaper" "No wallpaper sockets found"
    exit 1
fi

for socket in "${SOCKETS[@]}"; do
    if [ -S "$socket" ]; then
        echo 'cycle pause' | socat - "$socket" >/dev/null 2>&1
        CHANGED=true
    fi
done

# Check state from the first available socket
for socket in "${SOCKETS[@]}"; do
    if [ -S "$socket" ]; then
        STATUS=$(echo '{ "command": ["get_property", "pause"] }' | socat - "$socket" 2>/dev/null)
        if [[ "$STATUS" == *"true"* ]]; then
            NEW_STATE="paused"
        elif [[ "$STATUS" == *"false"* ]]; then
            NEW_STATE="resumed"
        fi
        break
    fi
done

if [ "$CHANGED" = true ] && [ -n "$NEW_STATE" ]; then
    notify-send "Wallpapers" "Live wallpapers $NEW_STATE."
fi

exit 0
