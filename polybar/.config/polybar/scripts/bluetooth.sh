#!/bin/sh
if [ "$(bluetoothctl show | grep "Powered: yes" | wc -c)" -eq 0 ]
then
    echo "%{F#9399b2}"
else
    if [ "$(bluetoothctl devices Connected | wc -c)" -eq 0 ]
    then
        echo "%{F#89dceb}"
    else
        echo "%{F#89b4fa}"
    fi
fi
