#!/bin/bash

SOCKETS=(/tmp/mpv-socket*)
ENTRIES=()
STATE=""
ICON=" 󰶐 "
CLASS="inactive"

for socket in "${SOCKETS[@]}"; do
    [ -S "$socket" ] || continue

    MONITOR=${socket#/tmp/mpv-socket-}

    # Get pause status
    STATUS=$(echo '{ "command": ["get_property", "pause"] }' | socat - "$socket" 2>/dev/null)
    if [[ "$STATUS" == *"true"* ]]; then
        STATE="Paused"
        ICON=" 󰍹 "
        CLASS="paused"
    elif [[ "$STATUS" == *"false"* ]]; then
        STATE="Playing"
        ICON=" 󰷜 "
        CLASS="playing"
    fi

    # Get filename
    RAW_PATH=$(echo '{ "command": ["get_property", "path"] }' | socat - "$socket" 2>/dev/null)
    FILENAME=$(basename "$(echo "$RAW_PATH" | jq -r '.data // empty')")

    ENTRIES+=("$MONITOR: $FILENAME")
done

if [ ${#ENTRIES[@]} -eq 0 ]; then
    echo '{ "text": " 󰶐 ", "class": "inactive", "tooltip": "Live wallpapers: off" }'
    exit 0
fi

TOOLTIP="$STATE"
for entry in "${ENTRIES[@]}"; do
    TOOLTIP+=$'\r'"$entry"
done

jq -nc --arg text "$ICON" --arg class "$CLASS" --arg tooltip "$TOOLTIP" \
    '{ text: $text, class: $class, tooltip: $tooltip }'
