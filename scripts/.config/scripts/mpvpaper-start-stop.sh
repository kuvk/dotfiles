#!/bin/bash

# Check if any mpvpaper process is running
if pgrep -x mpvpaper > /dev/null; then
    # Kill all mpvpaper processes
    pkill -x mpvpaper

    # Remove all related mpvpaper socket files
    find /tmp -maxdepth 1 -type s -name 'mpv-socket-*' -delete

    notify-send "Wallpapers" "Stopped all live wallpapers"
else
    # Launch Wofi selection script
    ~/.config/scripts/mpvpaper-set-wallpaper.sh
fi
