#!/usr/bin/env bash

if pgrep -x "wlogout" >/dev/null; then
    pkill -x "wlogout"
    exit 0
fi

monitor_info=$(hyprctl -j monitors | jq -r '
    .[] |
    select(.focused == true) |
    "\(.name) \(.width) \(.height) \(.scale)"
')

read -r monitor x_mon y_mon hypr_scale <<< "$monitor_info"

if [[ -z "$monitor" || -z "$x_mon" || -z "$y_mon" || -z "$hypr_scale" ]]; then
    notify-send "ERROR: Could not determine focused monitor."
    exit 1
fi

buttons_per_row=5

margin_left=$(awk -v x="$x_mon" -v s="$hypr_scale" \
    'BEGIN { printf "%d", x * 0.15 / s }')

margin_right="$margin_left"

margin_top=$(awk -v y="$y_mon" -v s="$hypr_scale" \
    'BEGIN { printf "%d", y * 0.42 / s }')

margin_bottom="$margin_top"

column_spacing=$(awk -v x="$x_mon" -v s="$hypr_scale" \
    'BEGIN { printf "%d", x * 0.05 / s }')

MAX_MARGIN=32000

(( margin_left > MAX_MARGIN )) && margin_left=$MAX_MARGIN
(( margin_right > MAX_MARGIN )) && margin_right=$MAX_MARGIN
(( margin_top > MAX_MARGIN )) && margin_top=$MAX_MARGIN
(( margin_bottom > MAX_MARGIN )) && margin_bottom=$MAX_MARGIN

exec wlogout \
    --buttons-per-row "$buttons_per_row" \
    --margin-left "${margin_left}px" \
    --margin-right "${margin_right}px" \
    --margin-top "${margin_top}px" \
    --margin-bottom "${margin_bottom}px" \
    --column-spacing "${column_spacing}px"
