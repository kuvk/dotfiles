#!/usr/bin/env bash
# Using for Nothing headphones (1) issue

# Get the current Bluetooth card
CARD=$(pactl list short cards | awk '/bluez_card/{print $2}')

# Get current active profile
CURRENT=$(pactl list cards | awk -v c="$CARD" '
    $0 ~ "Name: " c {flag=1} 
    flag && /Active Profile:/ {print $3; exit}
')

# Toggle between HQ audio (A2DP) and mic (headset)
if [[ "$CURRENT" == "a2dp-sink" ]]; then
    pactl set-card-profile "$CARD" headset-head-unit
    notify-send "Headphones" "Mic Enabled (Headset Mode)"
else
    pactl set-card-profile "$CARD" a2dp-sink
    notify-send "Headphones" "High Quality Audio Enabled (A2DP)"
fi
