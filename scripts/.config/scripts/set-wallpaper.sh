#!/bin/bash

# --- CONFIG ---
WALLPAPER_DIR="$HOME/wallpapers"
CONFIG_PATH="/tmp/hyprpaper-config"
PREV_CONFIG="$CONFIG_PATH.prev"

# --- IMAGE SELECTION ---
mapfile -t FILES < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | sort)
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

SELECTED_TRUNC=$(printf '%s\n' "${DISPLAY_NAMES[@]}" | wofi --dmenu --prompt "Select wallpaper")
[ -z "$SELECTED_TRUNC" ] && exit 0

# Match back to full name
SELECTED_NAME=""
SELECTED_IDX=-1
for i in "${!DISPLAY_NAMES[@]}"; do
    if [[ "${DISPLAY_NAMES[$i]}" == "$SELECTED_TRUNC" ]]; then
        SELECTED_NAME="${FILENAMES[$i]}"
        SELECTED_IDX=$i
        break
    fi
done
if [[ -z "$SELECTED_NAME" ]] || [[ $SELECTED_IDX -lt 0 ]] || [[ ! -f "$WALLPAPER_DIR/$SELECTED_NAME" ]]; then
    notify-send "Wallpapers" "Selected wallpaper does not exist."
    exit 1
fi
SELECTED_FILE="$WALLPAPER_DIR/$SELECTED_NAME"

# --- MONITOR SELECTION ---
mapfile -t ACTIVE_MONITORS < <(hyprctl monitors -j | jq -r '.[].name' | sort)
MONITORS=("ALL" "${ACTIVE_MONITORS[@]}")  # Add ALL option

if (( ${#ACTIVE_MONITORS[@]} == 1 )); then
    SELECTED_MONITOR="${ACTIVE_MONITORS[0]}"
else
    SELECTED_MONITOR=$(printf '%s\n' "${MONITORS[@]}" | wofi --dmenu --prompt "Select monitor (or ALL)")
    [ -z "$SELECTED_MONITOR" ] && exit 0
fi

# Ensure the selected monitor is valid
MONITOR_VALID=false
if [[ "$SELECTED_MONITOR" == "ALL" ]]; then
    MONITOR_VALID=true
else
    for m in "${ACTIVE_MONITORS[@]}"; do
        if [[ "$m" == "$SELECTED_MONITOR" ]]; then
            MONITOR_VALID=true
            break
        fi
    done
fi
if [[ "$MONITOR_VALID" != "true" ]]; then
    notify-send "Wallpapers" "Selected monitor does not exist."
    exit 1
fi

declare -A prev_wall  # monitor => file
prev_all_file=""

if [[ -f "$PREV_CONFIG" ]]; then
    while read -r line; do
        if [[ "$line" =~ ^wallpaper\ =\ ([^,]*),(.*)$ ]]; then
            m="${BASH_REMATCH[1]}"
            f="${BASH_REMATCH[2]}"
            if [[ "$m" == "" ]]; then
                prev_all_file="$f"
            else
                prev_wall["$m"]="$f"
            fi
        fi
    done < "$PREV_CONFIG"
fi

config_changed=false

if [[ "$SELECTED_MONITOR" == "ALL" ]]; then
    : > "$CONFIG_PATH"
    echo "preload = $SELECTED_FILE" >> "$CONFIG_PATH"
    echo "wallpaper = ,$SELECTED_FILE" >> "$CONFIG_PATH"
    notify-send "Wallpapers" "Wallpaper \"${SELECTED_NAME}\" set on ALL monitors"
    config_changed=true
else
    # Check if monitor already has the wallpaper active (either via per-monitor or previous ALL)
    if [[ "${prev_wall[$SELECTED_MONITOR]}" == "$SELECTED_FILE" ]] || \
        { [[ -n "$prev_all_file" ]] && [[ "$prev_all_file" == "$SELECTED_FILE" ]]; }; then
        notify-send "Wallpapers" "Wallpaper \"${SELECTED_NAME}\" is already active on $SELECTED_MONITOR"
        exit 0
    fi

    if [[ -n "$prev_all_file" ]]; then
        # Assign previous ALL wallpaper to all other active monitors
        for m in "${ACTIVE_MONITORS[@]}"; do
            if [[ "$m" != "$SELECTED_MONITOR" ]]; then
                prev_wall["$m"]="$prev_all_file"
            fi
        done
        unset 'prev_wall[""]'
    fi
    prev_wall["$SELECTED_MONITOR"]="$SELECTED_FILE"

    # Check if all active monitors now have the same wallpaper
    unique=""
    all_same=true
    for m in "${ACTIVE_MONITORS[@]}"; do
        f="${prev_wall[$m]}"
        if [[ -z "$f" ]]; then
            all_same=false
            break
        fi
        if [[ -z "$unique" ]]; then
            unique="$f"
        elif [[ "$f" != "$unique" ]]; then
            all_same=false
            break
        fi
    done

    : > "$CONFIG_PATH"
    if $all_same && [[ -n "$unique" ]]; then
        echo "preload = $unique" >> "$CONFIG_PATH"
        echo "wallpaper = ,$unique" >> "$CONFIG_PATH"
        notify-send "Wallpapers" "Wallpaper \"${SELECTED_NAME}\" set on ALL monitors"
    else
        declare -A seen_preload
        for m in "${ACTIVE_MONITORS[@]}"; do
            f="${prev_wall[$m]}"
            if [[ -n "$f" && -z "${seen_preload[$f]}" ]]; then
                echo "preload = $f" >> "$CONFIG_PATH"
                seen_preload["$f"]=1
            fi
        done
        for m in "${ACTIVE_MONITORS[@]}"; do
            f="${prev_wall[$m]}"
            if [[ -n "$f" ]]; then
                echo "wallpaper = $m,$f" >> "$CONFIG_PATH"
            fi
        done
        notify-send "Wallpapers" "Wallpaper \"${SELECTED_NAME}\" set on $SELECTED_MONITOR"
    fi
    config_changed=true
fi

if [[ "$config_changed" = true ]]; then
    cp "$CONFIG_PATH" "$PREV_CONFIG"
    pkill hyprpaper

    # Kill mpvpaper
    if pgrep -x mpvpaper >/dev/null; then
        pkill mpvpaper
        rm -f /tmp/mpv-socket*
    fi
    hyprpaper --config "$CONFIG_PATH" &
fi

exit 0
