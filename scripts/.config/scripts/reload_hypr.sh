#!/bin/bash
# # Reload Hyprland and Waybar
hyprctl dispatch exec pkill waybar
hyprctl dispatch exec waybar
hyprctl reload
