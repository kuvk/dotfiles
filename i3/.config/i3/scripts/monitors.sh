#!/usr/bin/bash

if xrandr | grep " connected " | awk '{ print$1 }' | grep HDMI-1-0; then
    xrandr --auto --output HDMI-1-0 --primary --mode 1920x1080 --set "Broadcast RGB" "Full"
    xrandr --auto --output eDP-1 --mode 1280x720 --right-of HDMI-1-0 --set "Broadcast RGB" "Full"
    feh --bg-fill ~/wallpapers/wallpaper.jpg
elif xrandr | grep " connected " | awk '{ print$1 }' | grep DP-0; then
    xrandr --auto --output DP-0 --primary --mode 2560x1440
    xrandr --auto --output HDMI-0 --mode 1920x1080 --right-of DP-0
    feh --bg-fill --no-xinerama ~/wallpapers/wallpaper.jpg
else
    xrandr --auto --output eDP-1 --set "Broadcast RGB" "Full"
    feh --bg-fill ~/wallpapers/wallpaper.jpg
fi
