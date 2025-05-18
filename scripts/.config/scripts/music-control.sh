#!/bin/bash

CACHE="$HOME/.cache/current_non_spotify_player"
ACTION="$1"  # play-pause, next, previous

if [ -f "$CACHE" ]; then
    player=$(cat "$CACHE")
    playerctl -p "$player" "$ACTION"
fi

