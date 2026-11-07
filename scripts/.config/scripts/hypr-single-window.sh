#!/usr/bin/env bash
# Single window: a lone tiled window keeps the shape set in
# ~/.config/hypr/configs/single-window.lua (layout:single_window_aspect_ratio) instead
# of filling the screen. SUPER+SHIFT+S turns it on and off; it stays as left across
# reloads and restarts (hyprland.lua loads the file while the flag exists).
#
#   hypr-single-window.sh          on, or off if on
#   hypr-single-window.sh on|off
set -euo pipefail

FLAG="$HOME/.local/state/kuvk-shell/single-window"

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "Single window" -i view-restore "$@"
}

on() {
    mkdir -p "${FLAG%/*}"
    touch "$FLAG"
    # the file itself, as hyprland.lua loads it (pasted, its "--" comments read as flags)
    hyprctl eval "package.loaded['configs.single-window'] = nil; require('configs.single-window')" >/dev/null
    notify "Single window is ON" 
}

off() {
    rm -f "$FLAG"
    # Hyprland's default: fill the screen
    hyprctl eval "hl.config({ layout = { single_window_aspect_ratio = { 0, 0 } } })" >/dev/null
    notify "Single window is OFF"
}

case ${1:-toggle} in
    toggle) [[ -e $FLAG ]] && off || on ;;
    on) on ;;
    off) off ;;
    *)
        echo "usage: hypr-single-window.sh [on|off]" >&2
        exit 1
        ;;
esac
