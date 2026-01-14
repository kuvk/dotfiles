#!/bin/bash

# --- CONFIG ---
WALLPAPER_DIR="$HOME/wallpapers"

# --- IMAGE SELECTION ---
mapfile -t FILES < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | sort)
FILENAMES=("${FILES[@]##*/}")

truncate_name() {
    local maxlen=30
    local name="$1"
    if (( ${#name} > maxlen )); then
        echo "${name:0:maxlen-2}.."
    else
        echo "$name"
    fi
}

DISPLAY_NAMES=()
for name in "${FILENAMES[@]}"; do
    DISPLAY_NAMES+=("$(truncate_name "$name")")
done

SELECTED_TRUNC=$(printf '%s\n' "${DISPLAY_NAMES[@]}" | rofi -dmenu -p "󰸉" -theme "$HOME/.config/rofi/config/wallpapers.rasi")
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
    notify-send "Wallpapers" "Selected wallpaper does not exist."
    exit 1
fi
SELECTED_FILE="$WALLPAPER_DIR/$SELECTED_NAME"

# --- MONITOR SELECTION ---
mapfile -t ACTIVE_MONITORS < <(hyprctl monitors -j | jq -r '.[].name' | sort)
MONITORS=("ALL" "${ACTIVE_MONITORS[@]}")

if (( ${#ACTIVE_MONITORS[@]} == 1 )); then
    SELECTED_MONITOR="${ACTIVE_MONITORS[0]}"
else
    SELECTED_MONITOR=$(printf '%s\n' "${MONITORS[@]}" | rofi -dmenu -p "󰍺" -theme "$HOME/.config/rofi/config/wallpapers.rasi")
    [ -z "$SELECTED_MONITOR" ] && exit 0
fi

# --- APPLY WALLPAPER ---
if [[ "$SELECTED_MONITOR" == "ALL" ]]; then
    hyprctl hyprpaper wallpaper ", $SELECTED_FILE, cover"
    notify-send "Wallpapers" "Wallpaper \"${SELECTED_NAME}\" set on ALL monitors"
else
    hyprctl hyprpaper wallpaper "$SELECTED_MONITOR, $SELECTED_FILE, cover"
    notify-send "Wallpapers" "Wallpaper \"${SELECTED_NAME}\" set on $SELECTED_MONITOR"
fi

exit 0
