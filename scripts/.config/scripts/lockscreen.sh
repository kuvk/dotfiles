#!/bin/bash
mtrx_command="kitty --start-as=fullscreen /home/kuvk/.config/scripts/matrix.sh"

(hyprlock && kill -9 $(pgrep -f "$mtrx_command")) &

checkpid=$(pgrep hyprlock) # Check if hyprlock is running
if ! [ -z $checkpid ]; then
	screens=$(hyprctl -j monitors | jq length) # Get the number of screens
	for (( i = -1; i < $screens; i++ ))
	do
		sleep 0.3
		hyprctl dispatch focusmonitor $i 
		eval $mtrx_command & # Run unimatrix 
	done 
fi
