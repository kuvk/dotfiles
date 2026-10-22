#!/usr/bin/env bash
set -euo pipefail

FLAG="/tmp/hypr-gamemode"
WAYBAR_CSS="$HOME/.config/waybar/mode.css"
SWAYNC_CSS="$HOME/.config/swaync/mode.css"
ROFI_LAUNCHER="$HOME/.config/rofi/launcher.rasi"

HYPR_MON="$HOME/.config/scripts/hypr-monitors.py"
WAYBAR_LOG="$HOME/.local/share/waybar/waybar.log"

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "Hyprland Gamemode" -t 1500 "󰊴" "$1"
}

restart_waybar() {
    mkdir -p "$(dirname "$WAYBAR_LOG")"
    pkill waybar || true
    waybar &> "$WAYBAR_LOG" &
}

# Only update background-color for:
#   .control-center { background-color: ...; }
#   .notification-row .notification-background { background-color: ...; }
set_swaync_gamemode_colors() {
    local token="$1"  # @base or @base-rgba
    local f="$SWAYNC_CSS"

    awk -v tok="$token" '
    BEGIN { in_cc=0; in_nr=0 }
    /^\s*\.control-center\s*\{/ { in_cc=1 }
    /^\s*\.notification-row[[:space:]]+\.notification-background\s*\{/ { in_nr=1 }

    in_cc && /^\s*background-color\s*:/ {
      sub(/background-color[[:space:]]*:[[:space:]]*[^;]+;/, "background-color: " tok ";")
      in_cc=0
    }
    in_nr && /^\s*background-color\s*:/ {
      sub(/background-color[[:space:]]*:[[:space:]]*[^;]+;/, "background-color: " tok ";")
      in_nr=0
    }
    { print }
  ' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
}

set_rofi_window_bg() {
    local token="$1"   # @BG or @BGA
    local f="$ROFI_LAUNCHER"
    [[ -f "$f" ]] || return 0

    awk -v tok="$token" '
    BEGIN { in_win=0; done=0 }

    /^\s*window\s*\{/ { in_win=1 }

    in_win && !done && /^\s*background-color\s*:/ {
      sub(/background-color[[:space:]]*:[[:space:]]*[^;]+;/, "background-color: " tok ";")
      done=1
    }

    in_win && /^\s*\}/ { in_win=0 }

    { print }
  ' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
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

    sed -i -E 's/^( *background: *).*/\1@base;/' "$WAYBAR_CSS"

    set_swaync_gamemode_colors "@base"
    swaync-client -rs
    set_rofi_window_bg "@BG"
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
        gaps_in = 0,
        gaps_out = 0,
        border_size = 2,
        col = {
            active_border = 'rgb(fab387)',
            inactive_border = 'rgb(89b4fa)',
        },
    },
})
hl.window_rule({ name = 'kitty', match = { class = 'kitty' }, opaque = true, no_blur = true  })
hl.window_rule({ name = 'spotify', match = { class = 'spotify' }, opaque = true, no_blur = true })
hl.window_rule({ name = 'thunderbird', match = { class = 'org.mozilla.Thunderbird' }, opaque = true, no_blur = true })
"

    restart_waybar
    notify "Gamemode is ON."
}

disable() {
    rm -f "$FLAG"
    sed -i -E 's/^( *background: *).*/\1@base-rgba;/' "$WAYBAR_CSS"

    set_swaync_gamemode_colors "@base-rgba"
    swaync-client -rs

    set_rofi_window_bg "@BGA"
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
        gaps_in = 2,
        gaps_out = 4,
        border_size = 2,
        col = {
            active_border = 'rgba(fab387ee)',
            inactive_border = 'rgba(89b4faaa)',
        },
    },
})
hl.window_rule({ name = 'kitty', match = { class = 'kitty' }, opaque = false, no_blur = false })
hl.window_rule({ name = 'spotify', match = { class = 'spotify' }, opaque = false, no_blur = false })
hl.window_rule({ name = 'thunderbird', match = { class = 'org.mozilla.Thunderbird' }, opaque = false, no_blur = false  })
"
    restart_waybar
    notify "Gamemode is OFF."
}

if [[ -e "$FLAG" ]]; then
    disable
else
    enable
fi
