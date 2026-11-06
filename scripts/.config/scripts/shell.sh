#!/bin/bash
# Quickshell, started again if it crashes: the lock screen is part of it, and Hyprland keeps
# the session locked until a new one takes the lock over (it locks again at start when Hyprland
# still holds a lock). Stops with Hyprland, when the shell quits on its own (exit 0), or after
# it failed within seconds of starting 5 times in a row: Hyprland restarted after its own crash
# can refuse it, and retrying wouldn't help (journalctl -t shell.sh says so).
socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock"
quick_failures=0
while [[ -S $socket ]]; do
    started=$SECONDS
    qs && break
    if ((SECONDS - started < 10)); then
        ((++quick_failures >= 5)) && {
            logger -t shell.sh "Quickshell failed 5 times in a row right after starting; not starting it again"
            break
        }
    else
        quick_failures=0
    fi
    sleep 1
done
