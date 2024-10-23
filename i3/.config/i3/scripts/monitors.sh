#!/usr/bin/env bash

if xrandr | grep " connected " | awk '{ print$1 }' | grep DP-0; then
    xrandr --auto --output DP-0 --mode 2560x1440 --rate 165.00
    xrandr --auto --output HDMI-0 --mode 1920x1080 --right-of DP-0
fi
# backround
feh --bg-max ~/wallpapers/wallpaper.jpg
