#!/bin/bash

# --- CONFIG ---
WALLPAPER_DIR="$HOME/wallpapers/live"
SOCKET_BASE="/tmp/mpv-socket"
MPVPAPER_CMD="mpvpaper" # Force execution on dGPU

# --- VIDEO SELECTION ---
mapfile -t FILES < <(find "$WALLPAPER_DIR" -type f \( -iname "*.mp4" -o -iname "*.webm" \) | sort)
FILENAMES=("${FILES[@]##*/}")

truncate_name() {
    local maxlen=30
    local name="$1"
    if ((${#name} > maxlen)); then
        echo "${name:0:maxlen-2}.."
    else
        echo "$name"
    fi
}

DISPLAY_NAMES=()
for name in "${FILENAMES[@]}"; do
    DISPLAY_NAMES+=("$(truncate_name "$name")")
done

SELECTED_TRUNC=$(printf '%s\n' "${DISPLAY_NAMES[@]}" | rofi -dmenu -p "󰸉 Select Wallpaper" -theme "$HOME/.config/rofi/config/wallpapers.rasi")
[ -z "$SELECTED_TRUNC" ] && exit 0

# Match back to full name
SELECTED_NAME=""
for i in "${!DISPLAY_NAMES[@]}"; do
    if [[ "${DISPLAY_NAMES[$i]}" == "$SELECTED_TRUNC" ]]; then
        SELECTED_NAME="${FILENAMES[$i]}"
        break
    fi
done
if [[ -z "$SELECTED_NAME" ]] || [[ ! -f "$WALLPAPER_DIR/$SELECTED_NAME" ]]; then
    notify-send "Live Wallpapers" "Selected video does not exist."
    exit 1
fi
SELECTED_FILE="$WALLPAPER_DIR/$SELECTED_NAME"

# --- MONITOR SELECTION ---
mapfile -t ACTIVE_MONITORS < <(hyprctl monitors -j | jq -r '.[].name' | sort)
MONITORS=("ALL" "${ACTIVE_MONITORS[@]}") # Add "ALL" option

if ((${#ACTIVE_MONITORS[@]} == 1)); then
    SELECTED_MONITOR="${ACTIVE_MONITORS[0]}"
else
    SELECTED_MONITOR=$(printf '%s\n' "${MONITORS[@]}" | rofi -dmenu -p "󰍺 Select Monitor" -theme "$HOME/.config/rofi/config/wallpapers.rasi")
    [ -z "$SELECTED_MONITOR" ] && exit 0
fi

# --- Clean Up Existing mpvpaper Instance for Selected Monitor ---
if [[ "$SELECTED_MONITOR" == "ALL" ]]; then
    killall mpvpaper 2>/dev/null
    rm -f "$SOCKET_BASE"-*
else
    SOCKET_PATH="$SOCKET_BASE-$SELECTED_MONITOR"
    pkill -f "mpvpaper .*${SELECTED_MONITOR}" 2>/dev/null
    rm -f "$SOCKET_PATH" 2>/dev/null
fi

# --- Set Live Wallpaper ---
if [[ "$SELECTED_MONITOR" == "ALL" ]]; then
    notify-send "Live Wallpapers" "Setting video \"${SELECTED_NAME}\" on ALL monitors"
	notify-send "command" "${MPVPAPER_CMD} -vsp -o no-config no-audio loop input-ipc-server=$SOCKET_BASE-ALL --gpu-context=wayland --fullscreen --keepaspect=no -p ALL $SELECTED_FILE"

    $MPVPAPER_CMD -vsp -o "no-config no-audio loop input-ipc-server=$SOCKET_BASE-ALL --gpu-context=wayland --fullscreen --keepaspect=no" -p ALL "$SELECTED_FILE" &
else
    notify-send "Live Wallpapers" "Setting video \"${SELECTED_NAME}\" on monitor: $SELECTED_MONITOR"
    $MPVPAPER_CMD -vsp -o "no-config no-audio loop input-ipc-server=$SOCKET_PATH --gpu-context=wayland --fullscreen --keepaspect=no" -p "$SELECTED_MONITOR" "$SELECTED_FILE" &
fi

exit 0
