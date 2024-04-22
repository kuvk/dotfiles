#!/usr/bin/env bash

if xrandr | grep " connected " | awk '{ print$1 }' | grep HDMI-1-0; then
    xrandr --auto --output eDP-1 --mode 1280x720
    xrandr --auto --output HDMI-1-0 --mode 1920x1080 --left-of eDP-1
fi
feh --bg-max ~/Pictures/wallpapers/shaded_landscape.png
