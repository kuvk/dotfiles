#!/usr/bin/env bash
## Currently configured for laptop
set -e

HYPR_MON_CONF="$HOME/.config/hypr/configs/generated/monitors.conf"

mkdir -p "$(dirname "$HYPR_MON_CONF")"

# Detect monitors
MONITORS_JSON=$(hyprctl monitors -j)
EDP_PRESENT=$(echo "$MONITORS_JSON" | jq -r '.[].name' | grep -x "eDP-1" || true)

# Any external (not eDP-1)
EXTERNAL=$(echo "$MONITORS_JSON" | jq -r '.[].name' | grep -v "^eDP-1$" | head -n1 || true)
INTERNAL="eDP-1"

# CASE 1: ONLY INTERNAL or MAIN DISPLAY
if [[ -n "$EDP_PRESENT" && -z "$EXTERNAL" ]]; then
  cat > "$HYPR_MON_CONF" <<EOF
monitor = $INTERNAL, highrr, auto, 1.33333
workspace = 1, monitor:$INTERNAL, persistent:true
workspace = 2, monitor:$INTERNAL, persistent:true
workspace = 3, monitor:$INTERNAL, persistent:true
workspace = 4, monitor:$INTERNAL, persistent:true
workspace = 5, monitor:$INTERNAL
EOF

# CASE 2: EXTERNAL + INTERNAL|MAIN
else
  cat > "$HYPR_MON_CONF" <<EOF
monitor = $EXTERNAL, highrr, 0x0, 1
monitor = eDP-1, highrr, auto, 1.6

workspace = 1, monitor:$EXTERNAL, persistent:true
workspace = 2, monitor:$EXTERNAL, persistent:true
workspace = 3, monitor:$EXTERNAL, persistent:true
workspace = 4, monitor:$EXTERNAL, persistent:true
workspace = 5, monitor:$EXTERNAL

workspace = 6, monitor:$INTERNAL, persistent:true
workspace = 7, monitor:$INTERNAL, persistent:true
workspace = 8, monitor:$INTERNAL, persistent:true
workspace = 9, monitor:$INTERNAL, persistent:true
workspace = 10, monitor:$INTERNAL
EOF
fi

hyprctl reload
pkill waybar || true
waybar &> "$HOME/.local/share/waybar/waybar.log" &
