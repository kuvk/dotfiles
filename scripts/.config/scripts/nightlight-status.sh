#!/bin/bash

if pgrep -x wlsunset >/dev/null; then
    echo '{"text":"", "class":"active", "tooltip":"Nightlight: on"}'
else
    echo '{"text":"", "tooltip":"Nightlight: off"}'
fi
