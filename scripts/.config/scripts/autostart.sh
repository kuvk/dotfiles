#!/bin/bash

# RGB
if command -v openrgb >/dev/null; then
    openrgb --startminimized -p vuk &
fi

exit 0
