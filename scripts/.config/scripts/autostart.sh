#!/bin/bash

# # OBS
# if command -v obs >/dev/null; then
#     obs --minimize-to-tray &
# fi

# # RGB
# if command -v openrgb >/dev/null; then
#     openrgb --startminimized -p vuk &
# fi

# Clipboard history (ALT+SHIFT+V)
if command -v cliphist >/dev/null; then
    wl-paste --type text --watch cliphist store &
    wl-paste --type image --watch cliphist store &
fi

# ROG Control Center
if command -v rog-control-center >/dev/null; then
    sleep 10 && rog-control-center &
fi
