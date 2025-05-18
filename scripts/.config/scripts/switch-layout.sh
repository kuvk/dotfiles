#!/bin/bash
for kb in $(hyprctl devices | awk '/Keyboard at/ {getline; print $1}'); do
  hyprctl switchxkblayout "$kb" next 2>/dev/null
done
