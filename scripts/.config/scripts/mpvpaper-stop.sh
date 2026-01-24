#!/bin/bash

if pgrep -x mpvpaper > /dev/null; then
    pkill -x mpvpaper
    find /tmp -maxdepth 1 -type s -name 'mpv-socket-*' -delete
    notify-send "Wallpapers" "Stopped all live wallpapers"
else
    notify-send "Wallpapers" "No live wallpapers running."
fi
if pgrep -x mpvpaper > /dev/null; then
	pkill -x hyprpaper
	hyprpaper
fi

