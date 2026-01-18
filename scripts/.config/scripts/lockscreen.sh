#!/bin/bash
set -euo pipefail

LOCKFILE="/tmp/hyprlock-matrix.lock"
MATRIX_SCRIPT="$HOME/.config/scripts/matrix.sh"
KITTY_MATCH="kitty.*matrix\.sh"

exec 9>"$LOCKFILE"
flock -n 9 || exit 0

cleanup() {
    pkill -f "$KITTY_MATCH" 2>/dev/null || true
	sleep 0.1
    hyprctl dispatch exec waybar
}
trap cleanup EXIT INT TERM

FOCUSED_MONITOR="$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .name' | head -n1 || true)"

cleanup

hyprctl dispatch exec pkill waybar
hyprlock &
LOCKPID=$!

sleep 0.2

hyprctl -j monitors | jq -r '.[] | "\(.name)\t\(.activeWorkspace.id)"' | \
    while IFS=$'\t' read -r mon ws; do
    hyprctl dispatch exec "[workspace ${ws}] kitty --start-as=fullscreen \"$MATRIX_SCRIPT\"" >/dev/null
    sleep 0.1
done

wait "$LOCKPID" || true

# Restore focus
if [ -n "${FOCUSED_MONITOR:-}" ]; then
    hyprctl dispatch focusmonitor "$FOCUSED_MONITOR" >/dev/null 2>&1 || true
fi
