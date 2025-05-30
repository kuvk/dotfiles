#!/bin/bash

# Media playing...
for player in $(playerctl -l 2>/dev/null); do
    status=$(playerctl -p "$player" status 2>/dev/null)
    if [ "$status" == "Playing" ]; then
        exit 1
    fi
done

# Idle
exit 0
