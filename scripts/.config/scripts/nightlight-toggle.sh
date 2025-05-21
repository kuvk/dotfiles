#!/bin/bash

if pgrep -x wlsunset >/dev/null; then
    pkill -x wlsunset
else
    wlsunset -t 2500 -T 5000 >/dev/null 2>&1 &
fi
