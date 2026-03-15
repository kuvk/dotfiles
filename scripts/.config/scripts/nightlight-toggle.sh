#!/bin/bash

if pgrep -x hyprsunset >/dev/null; then
    pkill -x hyprsunset
else
    hyprsunset -t 4000 >/dev/null 2>&1 &
fi
