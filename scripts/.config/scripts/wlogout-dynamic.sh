#!/bin/bash

# Check if wlogout is running
if pgrep -x "wlogout" >/dev/null; then
    pkill -x "wlogout"
    exit 0
fi

# Get monitor geometry and scale
x_mon=$(hyprctl -j monitors | jq '.[] | select(.focused==true) | .width')
y_mon=$(hyprctl -j monitors | jq '.[] | select(.focused==true) | .height')
hypr_scale=$(hyprctl -j monitors | jq '.[] | select(.focused==true) | .scale' | sed 's/\.//')

# Set layout parameters (adjust these as needed)
buttons_per_row=5
margin_left=$((x_mon * 15 / hypr_scale))
margin_right=$margin_left
margin_top=$((y_mon * 42 / hypr_scale))
margin_bottom=$margin_top
column_spacing=$((x_mon * 5 / hypr_scale))

# Launch wlogout with calculated values
exec wlogout \
    --buttons-per-row "$buttons_per_row" \
    --margin-left="${margin_left}px" \
    --margin-right="${margin_right}px" \
    --margin-top="${margin_top}px" \
    --margin-bottom="${margin_bottom}px" \
    -c "${column_spacing}px"
