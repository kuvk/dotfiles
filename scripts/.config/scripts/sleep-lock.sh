#!/bin/bash
# Lock before a suspend and wait until the session lock is secure (sleep-monitor.sh runs this
# when logind announces a sleep, holding it back with a delay inhibitor meanwhile). After
# Omarchy's omarchy-system-sleep-lock (github.com/basecamp/omarchy, MIT).
#
# logind sleeps when its inhibitor delay runs out, locked or not, so every step is bounded by
# what's left of that window: InhibitDelayMaxSec (15 s with install.sh's drop-in, 5 s by
# default) less a fifth of it (at least 1 s) for logind itself, at most 12 s.

delay_us=$(timeout 1 busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
    org.freedesktop.login1.Manager InhibitDelayMaxUSec 2>/dev/null)
delay_us=${delay_us##* }
[[ $delay_us =~ ^[0-9]+$ ]] && ((delay_us > 0)) || delay_us=5000000
window=$((delay_us / 1000))
reserve=$((window / 5 > 1000 ? window / 5 : 1000))
budget=$((window - reserve))
((budget > 12000)) && budget=12000
((budget < 1)) && budget=1

now_ms() { echo $((10#${EPOCHREALTIME//[!0-9]/} / 1000)); }
deadline=$(($(now_ms) + budget))

# qs ipc call, cut short by what's left of the budget
ipc() {
    local left=$((deadline - $(now_ms)))
    ((left > 0)) || return 1
    ((left > 1000)) && left=1000
    timeout "$(printf '%d.%03d' $((left / 1000)) $((left % 1000)))" qs ipc call lock "$@" 2>/dev/null
}

ipc lock >/dev/null
while (($(now_ms) < deadline)); do
    case $(ipc status | jq -r 'if .secure then "secure" elif .requested then "locking" else "idle" end' 2>/dev/null) in
        secure) exit 0 ;;
        locking) ;;
        *) ipc lock >/dev/null ;;
    esac
    sleep 0.1
done

# The machine sleeps anyway: say so on the screen it wakes up to
echo "sleep-lock.sh: suspending without a secure lock (not locked within ${budget} ms)" >&2
notify-send -u critical -a "Lock screen" "Slept without locking" \
    "Not locked within ${budget} ms." 2>/dev/null
exit 1
