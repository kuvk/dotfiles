#!/bin/bash

CACHE="$HOME/.cache/current_non_spotify_player"

IGNORE_PATTERN='^(spotify|firefox|chromium|chrome|brave|vivaldi)(\..*)?$'

for player in $(playerctl -l 2>/dev/null); do
    if [[ "$player" =~ $IGNORE_PATTERN ]]; then
        continue
    fi

    artist=$(playerctl -p "$player" metadata artist 2>/dev/null)
    title=$(playerctl -p "$player" metadata title 2>/dev/null)

    if [ -n "$artist" ] || [ -n "$title" ]; then
        # Clean up empty sides like " - title" or "artist - "
        echo "$artist - $title" | sed 's/^ - //' | sed 's/ - $//' | sed 's/^ - $//'
        echo "$player" > "$CACHE"
        exit 0
    fi

    # Fallback: show file name if metadata is empty
    file=$(playerctl -p "$player" metadata xesam:url 2>/dev/null | sed 's|file://||' | xargs basename 2>/dev/null)
    if [ -n "$file" ]; then
        echo "$file"
        echo "$player" > "$CACHE"
        exit 0
    fi
done

# No suitable player found
rm -f "$CACHE"
exit 0
