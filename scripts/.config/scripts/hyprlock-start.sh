#!/bin/bash
# Starts hyprlock with the clock and password on the monitor focused right now.
pidof hyprlock >/dev/null && exit 0
config="$XDG_RUNTIME_DIR/hyprlock.conf"
monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
install -m 600 /dev/null "$config"
sed "s/@MONITOR@/$monitor/" "$HOME/.config/theme/current/hyprlock.conf" >"$config"
exec hyprlock --config "$config"
