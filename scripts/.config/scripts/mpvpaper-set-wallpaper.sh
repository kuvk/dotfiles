#!/bin/bash

# --- CONFIG ---
WALLPAPER_DIR="$HOME/wallpapers/live"
SOCKET_BASE="/tmp/mpv-socket"

# --- VIDEO SELECTION ---
mapfile -t FILES < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.webm" \) | sort)
FILENAMES=("${FILES[@]##*/}")

# Truncate helper
truncate_name() {
    local maxlen=30
    local name="$1"
    if (( ${#name} > maxlen )); then
        echo "${name:0:maxlen-2}.."
    else
        echo "$name"
    fi
}

# Build display list (only truncated names)
DISPLAY_NAMES=()
for name in "${FILENAMES[@]}"; do
    DISPLAY_NAMES+=("$(truncate_name "$name")")
done

SELECTED_TRUNC=$(printf '%s\n' "${DISPLAY_NAMES[@]}" | wofi --dmenu --prompt "Select wallpaper")
[ -z "$SELECTED_TRUNC" ] && exit 0

# Match back to full name
SELECTED_NAME=""
for i in "${!DISPLAY_NAMES[@]}"; do
    if [[ "${DISPLAY_NAMES[$i]}" == "$SELECTED_TRUNC" ]]; then
        SELECTED_NAME="${FILENAMES[$i]}"
        break
    fi
done
SELECTED_FILE="$WALLPAPER_DIR/$SELECTED_NAME"

# --- MONITOR SELECTION ---
mapfile -t ACTIVE_MONITORS < <(hyprctl monitors -j | jq -r '.[].name' | sort)
MONITORS=("ALL" "${ACTIVE_MONITORS[@]}")  # Add "ALL" option

if (( ${#ACTIVE_MONITORS[@]} == 1 )); then
    # Only one monitor, skip menu
    SELECTED_MONITOR="${ACTIVE_MONITORS[0]}"
else
    SELECTED_MONITOR=$(printf '%s\n' "${MONITORS[@]}" | wofi --dmenu --prompt "Select monitor (or ALL)")
    [ -z "$SELECTED_MONITOR" ] && exit 0
fi

SOCKET_ALL="$SOCKET_BASE-ALL"
SOCKET_PATH="$SOCKET_BASE-$SELECTED_MONITOR"

# Get list of per-monitor sockets currently existing
EXISTING_MONITOR_SOCKETS=()
for m in "${ACTIVE_MONITORS[@]}"; do
    [ -e "$SOCKET_BASE-$m" ] && EXISTING_MONITOR_SOCKETS+=("$SOCKET_BASE-$m")
done

# --- LOGIC ---
if [[ "$SELECTED_MONITOR" == "ALL" ]]; then
    killall mpvpaper
    [ -e "$SOCKET_ALL" ] && rm -f "$SOCKET_ALL"
    for sock in "${EXISTING_MONITOR_SOCKETS[@]}"; do
        rm -f "$sock"
    done
    SOCKET_PATH="$SOCKET_ALL"

else
    # Check if ALL is actually running (not just socket exists)
    ALL_CMD=$(pgrep -a mpvpaper | grep -w "mpvpaper .*ALL")
    if [ -n "$ALL_CMD" ]; then
        ALL_VIDEO=$(echo "$ALL_CMD" | awk '{print $NF}')
        if [[ "$ALL_VIDEO" == "$SELECTED_FILE" ]]; then
            notify-send "Wallpapers" "Wallpaper \"${SELECTED_NAME}\" is already active on ALL monitors"
            exit 0
        fi

        echo "$ALL_CMD" | awk '{print $1}' | xargs -r kill
        rm -f "$SOCKET_ALL"

        for m in "${ACTIVE_MONITORS[@]}"; do
            if [ "$m" != "$SELECTED_MONITOR" ]; then
                SOCKET_M="$SOCKET_BASE-$m"
                pkill -f "mpvpaper .*${m}"
                rm -f "$SOCKET_M"
                notify-send "Wallpapers" "Moving \"${ALL_VIDEO##*/}\" from ALL to $m"
                mpvpaper -vsp -o "no-config no-audio loop input-ipc-server=$SOCKET_M" -p "$m" "$ALL_VIDEO" &
            fi
        done
    elif [ -e "$SOCKET_ALL" ]; then
        rm -f "$SOCKET_ALL"
    fi

    pkill -f "mpvpaper .*${SELECTED_MONITOR}"
    [ -e "$SOCKET_PATH" ] && rm -f "$SOCKET_PATH"
fi

# --- START MPVPAPER ---
notify-send "Wallpapers" "Setting wallpaper \"$SELECTED_NAME\" on $SELECTED_MONITOR"
mpvpaper -vsp -p -o "no-config no-audio loop input-ipc-server=$SOCKET_PATH" -p "$SELECTED_MONITOR" "$SELECTED_FILE"
