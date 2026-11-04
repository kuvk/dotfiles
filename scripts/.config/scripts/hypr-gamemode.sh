#!/usr/bin/env bash
# Work-Game has two modes on top of normal:
#   Work  no animations, blur or rounding; Quickshell goes opaque with the Work-Game gaps,
#         and live wallpapers pause
#   Game  the same, plus a plain US keyboard (Alt and Super not swapped, as input.lua
#         does, and no layout switching) so games get the printed keys, and Stay Awake
#
#   hypr-gamemode.sh work     Work mode, or back to normal if already in it (SUPER+G)
#   hypr-gamemode.sh game     Game mode, or back to normal if already in it (SUPER+CTRL+G)
#   hypr-gamemode.sh cycle    normal, Work, Game, normal (the bar and Control Center)
#   hypr-gamemode.sh normal   leave either mode
#
# /tmp/hypr-gamemode holds the mode; it exists in both, as other scripts only check that.
set -euo pipefail

FLAG="/tmp/hypr-gamemode"

HYPR_MON="$HOME/.config/scripts/hypr-monitors.py"

# Keyboard: the usual layouts and options, read from input.lua, and Work-Game's
INPUT="$HOME/.config/hypr/configs/input.lua"
KB_LAYOUT=$(sed -n 's/^ *kb_layout = "\([^"]*\)".*/\1/p' "$INPUT" | head -n1)
KB_OPTIONS=$(sed -n 's/^ *kb_options = "\([^"]*\)".*/\1/p' "$INPUT" | head -n1)
GAME_KB_LAYOUT="us"
GAME_KB_OPTIONS="ctrl:nocaps"

# Border colors follow the current theme
accent="fab387"
accent2="89b4fa"
if [[ -f "$HOME/.config/theme/current/colors.sh" ]]; then
    # shellcheck source=/dev/null
    . "$HOME/.config/theme/current/colors.sh"
    accent="${accent#\#}"
    accent2="${accent2#\#}"
fi

# notify TITLE [BODY]
notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "Work-Game" -i input-gaming "$@"
}

current_mode() {
    if [[ -e $FLAG ]]; then
        local mode
        mode=$(<"$FLAG")
        echo "${mode:-work}"
    else
        echo normal
    fi
}

style_on() {
    hyprctl eval "
hl.config({
    animations = { enabled = false },
    decoration = {
        shadow = { enabled = false },
        blur = { enabled = false },
        inactive_opacity = 1,
        rounding = 0,
    },
    general = {
        border_size = 2,
        col = {
            active_border = 'rgb($accent)',
            inactive_border = 'rgba(${accent2}e6)',
        },
    },
})
hl.window_rule({ name = 'kitty', match = { class = 'kitty' }, opaque = true, no_blur = true  })
hl.window_rule({ name = 'spotify', match = { class = 'spotify' }, opaque = true, no_blur = true })
hl.window_rule({ name = 'thunderbird', match = { class = 'org.mozilla.Thunderbird' }, opaque = true, no_blur = true })
" || true
    "$HOME/.config/scripts/wallpaper.py" pause on 2>/dev/null || true
}

style_off() {
    hyprctl eval "
hl.config({
    animations = { enabled = true },
    decoration = {
        shadow = { enabled = true },
        blur = { enabled = true },
        inactive_opacity = 0.9,
        rounding = 6,
        rounding_power = 2,
    },
    general = {
        border_size = 2,
        col = {
            active_border = 'rgb($accent)',
            inactive_border = 'rgba(${accent2}e6)',
        },
    },
})
hl.window_rule({ name = 'kitty', match = { class = 'kitty' }, opaque = false, no_blur = false })
hl.window_rule({ name = 'spotify', match = { class = 'spotify' }, opaque = false, no_blur = false })
hl.window_rule({ name = 'thunderbird', match = { class = 'org.mozilla.Thunderbird' }, opaque = false, no_blur = false  })
" || true
    "$HOME/.config/scripts/wallpaper.py" pause off 2>/dev/null || true
}

keyboard() {
    hyprctl eval "hl.config({ input = { kb_layout = '$1', kb_options = '$2' } })" >/dev/null
}

set_mode() {
    local target=$1 current
    current=$(current_mode)
    [[ $target == "$current" ]] && return

    if [[ $target == normal ]]; then
        style_off
    elif [[ $current == normal ]]; then
        style_on
    fi
    if [[ $target == game ]]; then
        keyboard "$GAME_KB_LAYOUT" "$GAME_KB_OPTIONS"
    elif [[ $current == game ]]; then
        keyboard "$KB_LAYOUT" "$KB_OPTIONS"
    fi

    if [[ $target == normal ]]; then
        rm -f "$FLAG"
    else
        echo "$target" >"$FLAG"
    fi
    # Quickshell's look, gaps and Stay Awake
    qs ipc call theme mode "$target" >/dev/null 2>&1 || true

    case $target in
        work) notify "Work mode is ON" "SUPER+CTRL+G switches to Game mode." ;;
        game) notify "Game mode is ON" "SUPER+G switches to Work mode." ;;
        normal) notify "Work-Game is OFF" ;;
    esac
}

mode=$(current_mode)
case ${1:-work} in
    work) [[ $mode == work ]] && set_mode normal || set_mode work ;;
    game) [[ $mode == game ]] && set_mode normal || set_mode game ;;
    cycle)
        case $mode in
            normal) set_mode work ;;
            work) set_mode game ;;
            *) set_mode normal ;;
        esac
        ;;
    normal) set_mode normal ;;
    *)
        echo "usage: hypr-gamemode.sh [work|game|cycle|normal]" >&2
        exit 1
        ;;
esac
