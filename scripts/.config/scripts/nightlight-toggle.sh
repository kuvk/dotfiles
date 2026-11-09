#!/bin/bash
# Night light (hyprsunset) at the temperature from Settings > Screen & Sleep > Night light.
#
#   nightlight-toggle.sh           toggle
#   nightlight-toggle.sh on|off    set it (the schedule in services/System.qml)
#   nightlight-toggle.sh apply     restart at the saved temperature, if it's on

settings=("$HOME"/.local/state/quickshell/by-shell/*/settings.json)
temperature=$(jq -r '.nightlightTemperature // 4500' "${settings[0]}" 2>/dev/null)

start() {
    hyprsunset -t "${temperature:-4500}" >/dev/null 2>&1 &
}

running() {
    pgrep -x hyprsunset >/dev/null
}

case ${1:-toggle} in
    on) running || start ;;
    off) pkill -x hyprsunset ;;
    apply)
        if running; then
            pkill -x hyprsunset
            while running; do sleep 0.05; done
            start
        fi
        ;;
    *) if running; then pkill -x hyprsunset; else start; fi ;;
esac
