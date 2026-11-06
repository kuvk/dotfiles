#!/bin/bash
# Quickshell, started again if it crashes: the lock screen is part of it, and Hyprland keeps
# the session locked until a new one takes the lock over (it locks again at start when it
# was locked). Stops with Hyprland, or when the shell quits on its own (exit 0).
socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock"
while [[ -S $socket ]]; do
    qs && break
    sleep 1
done
