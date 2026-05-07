#!/usr/bin/env bash
set -euo pipefail

FLAG="/tmp/hypr-gamemode"
WAYBAR_CSS="$HOME/.config/waybar/mode.css"
SWAYNC_CSS="$HOME/.config/swaync/mode.css"
ROFI_LAUNCHER="$HOME/.config/rofi/launcher.rasi"

HYPR_MON="$HOME/.config/scripts/hypr-monitors.sh"
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

enable() {
    touch "$FLAG"

    sed -i -E 's/^( *background: *).*/\1@base;/' "$WAYBAR_CSS"

    set_swaync_gamemode_colors "@base"
    swaync-client -rs

	set_rofi_window_bg "@BG"

    hyprctl --batch "\
    keyword animations:enabled 0;\
    keyword decoration:shadow:enabled 0;\
    keyword decoration:blur:enabled 0;\
    keyword general:gaps_in 0;\
    keyword general:gaps_out 0;\
    keyword general:border_size 1;\
	keyword general:col.active_border rgb(fab387);\
	keyword general:col.inactive_border rgb(89b4fa);\
    keyword decoration:inactive_opacity 1;\
    keyword decoration:rounding 0;\
    keyword decoration:rounding_power 0;\
    keyword windowrule[kitty]:enable false;\
    keyword windowrule[spotify]:enable false;\
    keyword windowrule[thunderbird]:enable false"

    restart_waybar
    notify "Gamemode is ON."
}

disable() {
    rm -f "$FLAG"

    sed -i -E 's/^( *background: *).*/\1@base-rgba;/' "$WAYBAR_CSS"

    set_swaync_gamemode_colors "@base-rgba"
    swaync-client -rs

	set_rofi_window_bg "@BGA"

    hyprctl --batch "\
    keyword animations:enabled 1;\
    keyword decoration:shadow:enabled 1;\
    keyword decoration:blur:enabled 1;\
    keyword general:gaps_in 2;\
    keyword general:gaps_out 4;\
    keyword general:border_size 2;\
	keyword general:col.active_border rgba(fab387ee);\
	keyword general:col.inactive_border rgba(89b4faaa);\
    keyword decoration:inactive_opacity 0.9;\
    keyword decoration:rounding 6;\
    keyword decoration:rounding_power 2;\
    keyword windowrule[kitty]:enable true;\
    keyword windowrule[spotify]:enable true;\
    keyword windowrule[thunderbird]:enable true"

    restart_waybar
    notify "Gamemode is OFF."
}

if [[ -e "$FLAG" ]]; then
    disable
else
    enable
fi
