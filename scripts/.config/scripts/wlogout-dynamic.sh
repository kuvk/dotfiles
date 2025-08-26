#!/bin/bash
# Launches wlogout with dynamic margins based on the focused Hyprland monitor's resolution.

resolution=$(hyprctl monitors | awk '
  /^Monitor / { inblock=1; res="" }
  /^[ \t]+[0-9]+x[0-9]+@[0-9.]+/ && inblock {
    split($1, a, "@")
    res=a[1]
  }
  /focused: yes/ && inblock {
    print res
    exit
  }
')

if [[ -z "$resolution" ]]; then
    notify-send "wlogout-dynamic" "Unable to determine focused monitor resolution."
    echo "Unable to determine focused monitor resolution."
    exit 1
fi

width="${resolution%x*}"
height="${resolution#*x}"

# Set margin ratios (1920x1080)
# left_right_ratio=0.30
# top_bottom_ratio=0.45

# Set margin ratios (2560x1600)
left_right_ratio=0.1
top_bottom_ratio=0.3

margin_left="$(awk -v w="$width" -v r="$left_right_ratio" 'BEGIN{printf "%d", w*r}')"
margin_right="$margin_left"
margin_top="$(awk -v h="$height" -v r="$top_bottom_ratio" 'BEGIN{printf "%d", h*r}')"
margin_bottom="$margin_top"

# You can customize these options to taste
buttons_per_row=5
# column_spacing=50 # (1920x1080)
column_spacing=120 # (2560x1600) 

# Launch wlogout with dynamic margins
exec wlogout \
    --buttons-per-row "$buttons_per_row" \
    --margin-left="${margin_left}px" \
    --margin-right="${margin_right}px" \
    --margin-top="${margin_top}px" \
    --margin-bottom="${margin_bottom}px" \
    -c "${column_spacing}px"
