#!/bin/bash

# --- CONFIG ---
WALLPAPER_DIR="$HOME/wallpapers/live"
SOCKET_BASE="/tmp/mpv-socket"

# --- VIDEO SELECTION ---
mapfile -t FILES < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.webm" \) | sort)
FILENAMES=("${FILES[@]##*/}")
SELECTED_NAME=$(printf '%s\n' "${FILENAMES[@]}" | wofi --dmenu --prompt "Select wallpaper")

[ -z "$SELECTED_NAME" ] && exit 0

# Match filename back to full path
for i in "${!FILENAMES[@]}"; do
    if [[ "${FILENAMES[$i]}" == "$SELECTED_NAME" ]]; then
        SELECTED_FILE="${FILES[$i]}"
        break
    fi
done

# --- MONITOR SELECTION ---
mapfile -t MONITORS < <(hyprctl monitors -j | jq -r '.[].name' | sort)
MONITORS=("ALL" "${MONITORS[@]}")  # Add "ALL" option

SELECTED_MONITOR=$(printf '%s\n' "${MONITORS[@]}" | wofi --dmenu --prompt "Select monitor (or ALL)")
[ -z "$SELECTED_MONITOR" ] && exit 0

SOCKET_ALL="$SOCKET_BASE-ALL"
SOCKET_PATH="$SOCKET_BASE-$SELECTED_MONITOR"

# Get list of per-monitor sockets currently existing
EXISTING_MONITOR_SOCKETS=()
for m in "${MONITORS[@]}"; do
    [ "$m" != "ALL" ] && [ -e "$SOCKET_BASE-$m" ] && EXISTING_MONITOR_SOCKETS+=("$SOCKET_BASE-$m")
done

# --- LOGIC ---

if [[ "$SELECTED_MONITOR" == "ALL" ]]; then
    # Kill all mpvpaper and remove sockets
    killall mpvpaper
    [ -e "$SOCKET_ALL" ] && rm -f "$SOCKET_ALL"
    for sock in "${EXISTING_MONITOR_SOCKETS[@]}"; do
        rm -f "$sock"
    done
    SOCKET_PATH="$SOCKET_ALL"

else
    # If "ALL" is running, kill it and reuse its video for remaining monitors
    if [ -e "$SOCKET_ALL" ]; then
        ALL_CMD=$(pgrep -a mpvpaper | grep -w "mpvpaper .*ALL")
        ALL_VIDEO=$(echo "$ALL_CMD" | awk '{print $NF}')

        # Kill the ALL instance
        echo "$ALL_CMD" | awk '{print $1}' | xargs -r kill
        rm -f "$SOCKET_ALL"

        # Start wallpaper for other monitors using ALL's video
        for m in "${MONITORS[@]}"; do
            [ "$m" != "ALL" ] && [ "$m" != "$SELECTED_MONITOR" ] && {
                notify-send "Wallpapers" "Moving \"$(basename "$ALL_VIDEO")\" from ALL monitors to $m"
                mpvpaper -vsp -o "no-config no-audio loop input-ipc-server=$SOCKET_BASE-$m" -p "$m" "$ALL_VIDEO" &
            }
        done
    fi

    # Kill mpvpaper for selected monitor if already running
    pgrep -a mpvpaper | grep -w "mpvpaper .*${SELECTED_MONITOR}" | awk '{print $1}' | xargs -r kill
    [ -e "$SOCKET_PATH" ] && rm -f "$SOCKET_PATH"
fi

# --- START MPVPAPER ---
notify-send "Wallpapers" "Setting wallpaper \"$SELECTED_NAME\" on $SELECTED_MONITOR"
mpvpaper -vsp -o "no-config no-audio loop input-ipc-server=$SOCKET_PATH" -p "$SELECTED_MONITOR" "$SELECTED_FILE"
