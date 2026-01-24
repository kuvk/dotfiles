#!/bin/bash

# OBS
if command -v obs >/dev/null; then
    obs --minimize-to-tray &
fi
# RGB
if command -v openrgb >/dev/null; then
    openrgb --startminimized -p vuk &
fi

exit 0
