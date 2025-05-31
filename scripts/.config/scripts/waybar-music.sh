#!/bin/bash

CACHE="$HOME/.cache/current_player"

mapfile -t AVAILABLE_PLAYERS < <(playerctl -l 2>/dev/null)

get_next_player() {
    local current="$1"
    local found_current=0
    for p in "${AVAILABLE_PLAYERS[@]}"; do
        if [[ $found_current -eq 1 ]]; then
            echo "$p"
            return
        fi
        if [[ "$p" == "$current" ]]; then found_current=1; fi
    done
    echo "${AVAILABLE_PLAYERS[0]}"
}

pick_player() {
    if [ -f "$CACHE" ]; then
        local cached
        cached=$(cat "$CACHE")
        for p in "${AVAILABLE_PLAYERS[@]}"; do
            if [[ "$p" == "$cached" ]]; then
                echo "$cached"
                return
            fi
        done
    fi
    # default to first player
    echo "${AVAILABLE_PLAYERS[0]}"
}

get_icon() {
    local p="$1"
    case "$p" in
        *spotify*) echo "  " ;;
        *vlc*) echo "󰕼  " ;;
        *firefox*) echo "  " ;;
        *brave*) echo "  " ;;
        *chrome*) echo "  " ;;
        *) echo "  " ;;
    esac
}

case "$1" in
    play-pause | next | previous)
        if [ -f "$CACHE" ]; then
            player=$(cat "$CACHE")
            playerctl -p "$player" "$1" 2>/dev/null
        fi
        ;;
    switch)
        # Only switch if more than one player is present
        if [ "${#AVAILABLE_PLAYERS[@]}" -le 1 ]; then
            exit 0
        fi
        if [ -f "$CACHE" ]; then
            player=$(cat "$CACHE")
            # If player is missing, fall back to the first
            found=0
            for p in "${AVAILABLE_PLAYERS[@]}"; do
                if [[ "$p" == "$player" ]]; then
                    found=1
                    break
                fi
            done
            if [ $found -eq 1 ]; then
                next=$(get_next_player "$player")
            else
                next="${AVAILABLE_PLAYERS[0]}"
            fi
        else
            next="${AVAILABLE_PLAYERS[0]}"
        fi
        echo "$next" >"$CACHE"
        ;;
    *)
        if [ "${#AVAILABLE_PLAYERS[@]}" -eq 0 ]; then
            echo ""
            rm -f "$CACHE"
            exit 0
        fi

        player=$(pick_player)
        echo "$player" >"$CACHE"
        icon=$(get_icon "$player")

        artist=""
        title=""
        filename=""

        artist=$(playerctl -p "$player" metadata artist 2>/dev/null)
        title=$(playerctl -p "$player" metadata title 2>/dev/null)

        if [ -z "$artist" ] && [ -z "$title" ]; then
            url=$(playerctl -p "$player" metadata xesam:url 2>/dev/null | sed 's|file://||')
            if [ -n "$url" ]; then
                basefile=$(basename "$url")
                # Decode URL-encoded string
                filename=$(python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))" "$basefile")
                if [ -n "$filename" ]; then
                    echo "$icon$filename"
                    exit 0
                fi
            fi
            echo "$icon"
            exit 0
        fi

        output="$icon$artist - $title"
        output=$(echo "$output" | sed 's/^ - //' | sed 's/ - $//' | sed 's/^ - $//')
        echo "$output"
        ;;
esac
