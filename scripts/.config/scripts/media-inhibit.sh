#!/bin/bash
while true; do
    if playerctl status 2>/dev/null | grep -q "Playing"; then
        systemd-inhibit --what=idle --why="Media playing" sleep 10
    else
        sleep 10
    fi
done
