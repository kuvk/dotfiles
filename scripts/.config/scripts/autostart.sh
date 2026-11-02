#!/bin/bash

# # OBS
# if command -v obs >/dev/null; then
#     obs --minimize-to-tray &
# fi

# # RGB
# if command -v openrgb >/dev/null; then
#     openrgb --startminimized -p vuk &
# fi

# Clipboard history (SUPER+SHIFT+V), kept in RAM so a reboot wipes it. Skipped if
# someone else owns the folder. To keep it across reboots, delete ~/.config/cliphist/config
# and these lines up to the watchers.
if command -v cliphist >/dev/null; then
    clipboard_dir=/tmp/cliphist-$UID
    mkdir -p -m 700 "$clipboard_dir"
    if [[ -O $clipboard_dir ]]; then
        mkdir -p "$HOME/.config/cliphist"
        printf 'db-path %s/db\n' "$clipboard_dir" >"$HOME/.config/cliphist/config"
        wl-paste --type text --watch cliphist store &
        wl-paste --type image --watch cliphist store &
    fi
fi

# ROG Control Center
if command -v rog-control-center >/dev/null; then
    sleep 10 && rog-control-center &
fi
