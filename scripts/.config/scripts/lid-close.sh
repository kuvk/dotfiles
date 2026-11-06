#!/bin/bash
# The lid closed (bindings.lua): lock at once, unless an external monitor is connected, which
# makes it a docked laptop still in use (logind doesn't suspend then either): then the laptop's
# screen goes off instead (clamshell, hypr-monitors.py lid). Locking here gives the lock a head
# start on logind's suspend; sleep-lock.sh then finds it secure. After Omarchy's
# omarchy-system-lid-close (github.com/basecamp/omarchy, MIT).
for connector in /sys/class/drm/card*-*; do
    name=${connector##*/}
    name=${name#card*-}
    [[ $name =~ ^(eDP|LVDS|DSI)- ]] && continue
    [[ $(cat "$connector/status" 2>/dev/null) == connected ]] && exec "$HOME/.config/scripts/hypr-monitors.py" lid
done
qs ipc call lock lock
