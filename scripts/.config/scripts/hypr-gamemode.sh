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
    notify-send -a "Work-Game Mode" -t 1500 "󰊴" "$1"
}

# Work-Game Mode: no animations, blur or rounding. Quickshell goes opaque,
# applies the Work-Game gaps from its Settings and keeps the screen awake.
set_shell_gamemode() {
    qs ipc call theme gamemode "$1" >/dev/null 2>&1 || true
}

# set_mainmod_for_gaming() {
#     local gamemode="$1"
#     local file="$HOME/.config/hypr/configs/bindings.lua"
#
#     if [[ ! -f "$file" ]]; then
#         notify "Error: file not found: $file"
#         echo "Error: file not found: $file" >&2
#         return 1
#     fi
#
#     # Normalize boolean-ish input
#     case "${gamemode,,}" in
#         true|1|yes|on)   target="SUPER" ;;
#         false|0|no|off)  target="ALT" ;;
#         *)
#             echo "Usage: set_mainmod_for_gaming <true|false>" >&2
#             return 2
#             ;;
#     esac
#
#     # If already set correctly, do nothing
#     if grep -Eq "^local[[:space:]]+mainMod[[:space:]]*=[[:space:]]*\"$target\"[[:space:]]*$" "$file"; then
#         echo "mainMod already $target (no change)"
#         notify "mainMod already $target (no change)"
#         return 0
#     fi
#
#     # Change only the opposite value; if neither exists, report
#     if [[ "$target" == "SUPER" ]]; then
#         if grep -Eq '^local[[:space:]]+mainMod[[:space:]]*=[[:space:]]*"ALT"[[:space:]]*$' "$file"; then
#             sed -i 's/^local[[:space:]]\+mainMod[[:space:]]*=[[:space:]]*"ALT"[[:space:]]*$/local mainMod = "SUPER"/' "$file"
#             echo 'mainMod changed: ALT -> SUPER'
#             notify 'mainMod changed: ALT -> SUPER'
#         else
#             echo 'No mainMod line found to change. Check bindings.lua'
#             notify 'No mainMod line found to change. Check bindings.lua'
#             return 1
#         fi
#     else
#         if grep -Eq '^local[[:space:]]+mainMod[[:space:]]*=[[:space:]]*"SUPER"[[:space:]]*$' "$file"; then
#             sed -i 's/^local[[:space:]]\+mainMod[[:space:]]*=[[:space:]]*"SUPER"[[:space:]]*$/local mainMod = "ALT"/' "$file"
#             echo 'mainMod changed: SUPER -> ALT'
#             notify 'mainMod changed: SUPER -> ALT'
#         else
#             echo 'No ALT/SUPER mainMod line found to change'
#             notify 'No mainMod line found to change. Check bindings.lua'
#             return 1
#         fi
#     fi
# }

# set_kb_options_by_gamemode() {
#     local gamemode="$1"
#     local file="$HOME/.config/hypr/configs/input.lua"
#     local target
#
#     if [[ ! -f "$file" ]]; then
#         echo "Error: file not found: $file" >&2
#         return 1
#     fi
#
#     case "${gamemode,,}" in
#         true|1|yes|on)   target='ctrl:nocaps,grp:alt_space_toggle' ;;
#         false|0|no|off)  target='ctrl:nocaps,grp:win_space_toggle' ;;
#         *)
#             echo "Usage: set_kb_options_by_gamemode <true|false>" >&2
#             return 2
#             ;;
#     esac
#
#     # Already in desired state
#     if grep -Eq "^[[:space:]]*kb_options[[:space:]]*=[[:space:]]*\"$target\",[[:space:]]*$" "$file"; then
#         echo "kb_options already set to: $target (no change)"
#         return 0
#     fi
#
#     # Replace only the grp toggle part on the kb_options line, keep indent/comma and other options
#     sed -Ei \
#         's/^([[:space:]]*kb_options[[:space:]]*=[[:space:]]*"[^"]*grp:)(win_space_toggle|alt_space_toggle)([^"]*",?[[:space:]]*)$/\1'"$([[ "$target" == *alt_space_toggle ]] && echo alt_space_toggle || echo win_space_toggle)"'\3/' \
#         "$file"
#
#     # Verify
#     if grep -Eq "^[[:space:]]*kb_options[[:space:]]*=[[:space:]]*\"$target\",[[:space:]]*$" "$file"; then
#         echo "kb_options updated to: $target"
#         return 0
#     else
#         echo "No matching kb_options grp toggle found to change" >&2
#         return 1
#     fi
# }

enable() {
    touch "$FLAG"

    set_shell_gamemode true
    # set_mainmod_for_gaming true
    # set_kb_options_by_gamemode true    # -> grp:alt_space_toggle

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

    notify "Work-Game Mode is on."
}

disable() {
    rm -f "$FLAG"
    set_shell_gamemode false
    # set_mainmod_for_gaming false
    # set_kb_options_by_gamemode false   # -> grp:win_space_toggle

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
    notify "Work-Game Mode is off."
}

if [[ -e "$FLAG" ]]; then
    disable
else
    enable
fi
