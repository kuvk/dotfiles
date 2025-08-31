#!/bin/bash
# Change hyprland & waybar config between single and dual monitor setups
# mainMod + - to reload single monitor config file
# mainMod + = to reload with dual-monitor config file


# Hyprland config paths
HYPR_DIR="$HOME/.config/hypr"
HYPR_CONFIG="$HYPR_DIR/hyprland.conf"
SINGLE_HYPR="$HYPR_DIR/hyprland-sm.conf"
DUAL_HYPR="$HYPR_DIR/hyprland-dm.conf"

# Waybar config paths
WAYBAR_DIR="$HOME/.config/waybar"
WAYBAR_CONFIG="$WAYBAR_DIR/config.jsonc"
SINGLE_WAYBAR="$WAYBAR_DIR/config-sm.jsonc"
DUAL_WAYBAR="$WAYBAR_DIR/config-dm.jsonc"

if [[ "$1" == "single" ]]; then
    cp "$SINGLE_HYPR" "$HYPR_CONFIG"
    cp "$SINGLE_WAYBAR" "$WAYBAR_CONFIG"
elif [[ "$1" == "dual" ]]; then
    cp "$DUAL_HYPR" "$HYPR_CONFIG"
    cp "$DUAL_WAYBAR" "$WAYBAR_CONFIG"
else
    echo "Usage: $0 [single|dual]"
    exit 1
fi


# Reload Hyprland and Waybar
hyprctl dispatch exec pkill waybar
hyprctl dispatch exec waybar
hyprctl reload
