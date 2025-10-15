#!/bin/bash

# --- CONFIG ---
WALLPAPER_DIR="$HOME/wallpapers/live"
SOCKET_BASE="/tmp/mpv-socket"

# --- VIDEO SELECTION ---
mapfile -t FILES < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.webm" \) | sort)
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

SELECTED_TRUNC=$(printf '%s\n' "${DISPLAY_NAMES[@]}" | rofi -dmenu -p "󰸉" -theme "$HOME"/.config/rofi/config/wallpapers.rasi)
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
    notify-send "Live Wallpapers" "Selected wallpaper does not exist."
    exit 1
fi
SELECTED_FILE="$WALLPAPER_DIR/$SELECTED_NAME"

# --- MONITOR SELECTION ---
mapfile -t ACTIVE_MONITORS < <(hyprctl monitors -j | jq -r '.[].name' | sort)
MONITORS=("ALL" "${ACTIVE_MONITORS[@]}") # Add "ALL" option

if ((${#ACTIVE_MONITORS[@]} == 1)); then
    SELECTED_MONITOR="${ACTIVE_MONITORS[0]}"
else
    SELECTED_MONITOR=$(printf '%s\n' "${MONITORS[@]}" | rofi -dmenu -p "󰍺" -theme "$HOME"/.config/rofi/config/wallpapers.rasi)
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
    notify-send "Live Wallpapers" "Selected monitor does not exist."
    exit 1
fi

SOCKET_ALL="$SOCKET_BASE-ALL"
SOCKET_PATH="$SOCKET_BASE-$SELECTED_MONITOR"

# --- Gather current mpvpaper assignments ---
declare -A monitor_to_video

# Check for ALL instance
ALL_CMD=$(pgrep -a mpvpaper | grep -w "mpvpaper .*ALL")
if [ -n "$ALL_CMD" ]; then
    ALL_VIDEO=$(echo "$ALL_CMD" | awk '{print $NF}')
    monitor_to_video["ALL"]="$ALL_VIDEO"
fi

# Check for per-monitor instances
for m in "${ACTIVE_MONITORS[@]}"; do
    # skip if ALL is running (ALL overrides per-monitor)
    if [[ -n "${monitor_to_video["ALL"]}" ]]; then
        break
    fi
    MON_CMD=$(pgrep -a mpvpaper | grep -w "mpvpaper .*${m}")
    if [ -n "$MON_CMD" ]; then
        MON_VIDEO=$(echo "$MON_CMD" | awk '{print $NF}')
        monitor_to_video["$m"]="$MON_VIDEO"
    fi
done

# --- COLLAPSE TO ALL LOGIC ---
collapse_to_all=false
if [[ "$SELECTED_MONITOR" == "ALL" ]]; then
    collapse_to_all=true
else
    # Simulate the per-monitor assignments after this action
    declare -A new_monitor_to_video
    if [[ -n "${monitor_to_video["ALL"]}" ]]; then
        for m in "${ACTIVE_MONITORS[@]}"; do
            new_monitor_to_video["$m"]="${monitor_to_video["ALL"]}"
        done
        new_monitor_to_video["$SELECTED_MONITOR"]="$SELECTED_FILE"
    else
        for m in "${ACTIVE_MONITORS[@]}"; do
            new_monitor_to_video["$m"]="${monitor_to_video["$m"]}"
        done
        new_monitor_to_video["$SELECTED_MONITOR"]="$SELECTED_FILE"
    fi
    # Check if all monitors have the same video
    unique=""
    all_same=true
    for m in "${ACTIVE_MONITORS[@]}"; do
        v="${new_monitor_to_video["$m"]}"
        if [[ -z "$v" ]]; then
            all_same=false
            break
        fi
        if [[ -z "$unique" ]]; then
            unique="$v"
        elif [[ "$v" != "$unique" ]]; then
            all_same=false
            break
        fi
    done

    if $all_same && [[ -n "$unique" ]] && [[ "$unique" == "$SELECTED_FILE" ]]; then
        collapse_to_all=true
    fi
fi

# --- Logic for setting wallpaper ALL ---
if $collapse_to_all; then

    if [[ "${monitor_to_video["ALL"]}" == "$SELECTED_FILE" ]]; then
        notify-send "Live Wallpapers" "Wallpaper \"${SELECTED_NAME}\" is already active on ALL monitors"
        exit 0
    fi

    killall mpvpaper
    rm -f "$SOCKET_BASE"-*

    # --- KILL HYPRPAPER ---
    if pgrep -x hyprpaper >/dev/null; then
        pkill hyprpaper
        rm -f /tmp/hyprpaper-config*
    fi

    notify-send "Live Wallpapers" "Setting wallpaper \"${SELECTED_NAME}\" on ALL monitors"
    mpvpaper -vsp -o "no-config no-audio loop input-ipc-server=$SOCKET_ALL" -p ALL "$SELECTED_FILE"
    exit 0
fi

# --- Otherwise, per-monitor logic ---
if [[ "$SELECTED_MONITOR" != "ALL" ]]; then
    if [[ "${monitor_to_video["ALL"]}" == "$SELECTED_FILE" ]]; then
        notify-send "Live Wallpapers" "Wallpaper \"${SELECTED_NAME}\" is already active on ALL monitors"
        exit 0
    fi

    if [[ "${monitor_to_video["$SELECTED_MONITOR"]}" == "$SELECTED_FILE" ]]; then
        notify-send "Live Wallpapers" "Wallpaper \"${SELECTED_NAME}\" is already active on $SELECTED_MONITOR"
        exit 0
    fi

    # If ALL is running (but with a different video), split ALL and assign ALL's video to others
    if [[ -n "${monitor_to_video["ALL"]}" ]]; then
        ALL_VIDEO="${monitor_to_video["ALL"]}"

        pkill -f "mpvpaper .*ALL"
        rm -f "$SOCKET_ALL"

        # Assign ALL_VIDEO to all monitors except the one being changed
        for m in "${ACTIVE_MONITORS[@]}"; do
            if [[ "$m" != "$SELECTED_MONITOR" ]]; then
                SOCKET_M="$SOCKET_BASE-$m"
                pkill -f "mpvpaper .*${m}"
                rm -f "$SOCKET_M"
                mpvpaper -vsp -o "no-config no-audio loop input-ipc-server=$SOCKET_M" -p "$m" "$ALL_VIDEO" &
            fi
        done
    fi

    pkill -f "mpvpaper .*${SELECTED_MONITOR}"
    [ -e "$SOCKET_PATH" ] && rm -f "$SOCKET_PATH"

    # --- KILL HYPRPAPER ---
    if pgrep -x hyprpaper >/dev/null; then
        pkill hyprpaper
        rm -f /tmp/hyprpaper-config*
    fi

    notify-send "Live Wallpapers" "Setting wallpaper \"$SELECTED_NAME\" on $SELECTED_MONITOR"
    mpvpaper -vsp -p -o "no-config no-audio loop input-ipc-server=$SOCKET_PATH" -p "$SELECTED_MONITOR" "$SELECTED_FILE"
    exit 0
fi

# --- ALL selected but not collapse case ---
killall mpvpaper
rm -f "$SOCKET_BASE"-*

# --- KILL HYPRPAPER ---
if pgrep -x hyprpaper >/dev/null; then
    pkill hyprpaper
    rm -f /tmp/hyprpaper-config*
fi

notify-send "Live Wallpapers" "Setting wallpaper \"$SELECTED_NAME\" on ALL monitors"
mpvpaper -vsp -o "no-config no-audio loop input-ipc-server=$SOCKET_ALL" -p ALL "$SELECTED_FILE"
