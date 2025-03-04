#!/usr/bin/sh

# laptop
# if xrandr | grep " connected " | awk '{ print$1 }' | grep HDMI-1-0; then
#     xrandr --auto --output HDMI-1-0 --primary --mode 1920x1080
#     xrandr --auto --output eDP-1 --mode 1368x768 --right-of HDMI-1-0
#     feh --bg-fill ~/wallpapers/wallpaper.jpg
# else
#     xrandr --auto --output eDP-1 --mode 1920x1080
#     feh --bg-fill ~/wallpapers/wallpaper.jpg
# fi
#
# desktop
xrandr --auto --output HDMI-0 --primary --mode 1920x1080
feh --bg-fill ~/wallpapers/wallpaper.jpg
