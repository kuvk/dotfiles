#!/usr/bin/env bash
set -euo pipefail

FLAG="/tmp/hypr-gamemode"

HYPR_MON="$HOME/.config/scripts/hypr-monitors.py"

# Border colors follow the current theme
accent="fab387"
accent2="89b4fa"
if [[ -f "$HOME/.config/theme/current/colors.sh" ]]; then
    # shellcheck source=/dev/null
    . "$HOME/.config/theme/current/colors.sh"
    accent="${accent#\#}"
    accent2="${accent2#\#}"
fi

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "Work-Game" -i input-gaming -t 1500 "$1"
}

# Work-Game: no animations, blur or rounding. Quickshell goes opaque,
# applies the Work-Game gaps from its Settings and keeps the screen awake.
set_shell_gamemode() {
    qs ipc call theme gamemode "$1" >/dev/null 2>&1 || true
}

enable() {
    touch "$FLAG"

    set_shell_gamemode true

    hyprctl eval "
hl.config({
    animations = { enabled = false },
    decoration = {
        shadow = { enabled = false },
        blur = { enabled = false },
        inactive_opacity = 1,
        rounding = 0,
        rounding_power = 0,
    },
    general = {
        border_size = 2,
        col = {
            active_border = 'rgb($accent)',
            inactive_border = 'rgb($accent2)',
        },
    },
})
hl.window_rule({ name = 'kitty', match = { class = 'kitty' }, opaque = true, no_blur = true  })
hl.window_rule({ name = 'spotify', match = { class = 'spotify' }, opaque = true, no_blur = true })
hl.window_rule({ name = 'thunderbird', match = { class = 'org.mozilla.Thunderbird' }, opaque = true, no_blur = true })
"

    notify "Work-Game mode is ON"
}

disable() {
    rm -f "$FLAG"
    set_shell_gamemode false

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
            active_border = 'rgba(${accent}ee)',
            inactive_border = 'rgba(${accent2}aa)',
        },
    },
})
hl.window_rule({ name = 'kitty', match = { class = 'kitty' }, opaque = false, no_blur = false })
hl.window_rule({ name = 'spotify', match = { class = 'spotify' }, opaque = false, no_blur = false })
hl.window_rule({ name = 'thunderbird', match = { class = 'org.mozilla.Thunderbird' }, opaque = false, no_blur = false  })
"
    notify "Work-Game mode is OFF"
}

if [[ -e "$FLAG" ]]; then
    disable
else
    enable
fi
