#!/bin/bash

if pgrep -x hyprsunset >/dev/null; then
    pkill -x hyprsunset
else
    hyprsunset -t 5000 -g 80 >/dev/null 2>&1 &
fi
