#!/bin/bash
# hyprlock over a fullscreen unimatrix on every monitor, with the clock and password on
# the monitor focused now. The bar and notifications are off meanwhile, as they'd
# otherwise draw over the rain, showing notification text on the locked screen.
set -uo pipefail

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/lockscreen.lock"
flock -n 9 || exit 0
pidof hyprlock >/dev/null && exit 0

TITLE=MATRIXLOCK
config="$XDG_RUNTIME_DIR/hyprlock.conf"

cleanup() {
    pkill -f "kitty --title $TITLE" 2>/dev/null
    qs ipc call bar show >/dev/null 2>&1
    qs ipc call notifications dnd false >/dev/null 2>&1
}
trap cleanup EXIT INT TERM

monitors=$(hyprctl -j monitors)
focused=$(jq -r '.[] | select(.focused) | .name' <<<"$monitors" | head -n1)

qs ipc call bar hide >/dev/null 2>&1
qs ipc call notifications dnd true >/dev/null 2>&1

install -m 600 /dev/null "$config"
sed "s/@MONITOR@/$focused/" "$HOME/.config/theme/current/hyprlock.conf" >"$config"
hyprlock --config "$config" &
lock=$!

# Locked first, so input is never open; then the rain covers the desktop
sleep 0.2
jq -r '.[].activeWorkspace.id' <<<"$monitors" | while read -r workspace; do
    hyprctl eval "hl.exec_cmd('kitty --title $TITLE --start-as=fullscreen unimatrix -c cyan -b -s 96 -f -l m', { workspace = '$workspace' })" >/dev/null
done

wait "$lock"

if [[ -n $focused ]]; then
    hyprctl dispatch "hl.dsp.focus({ monitor = \"$focused\" })" >/dev/null
fi
