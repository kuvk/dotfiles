#!/usr/bin/env bash
# Hybrid laptops (an NVIDIA card next to the built-in GPU): the NVIDIA card stays powered on
# AC, so plugging in a monitor doesn't wake it (see nvidia-ac-power). The main install.sh runs
# this on such laptops.
#
#   sudo nvidia-hybrid/install.sh            install, and apply it now
#   sudo nvidia-hybrid/install.sh --remove   back to the card powering off on AC too
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }

here=$(cd "$(dirname "$0")" && pwd)
script=/usr/local/lib/hyprdori/nvidia-ac-power
rules=/etc/udev/rules.d/90-nvidia-ac-power.rules

if [[ ${1:-} == --remove ]]; then
    rm -f "$rules" "$script"
    rmdir --ignore-fail-on-non-empty /usr/local/lib/hyprdori 2>/dev/null || true
    udevadm control --reload
    # runtime PM again, as 80-nvidia-pm.rules sets it
    for device in /sys/bus/pci/devices/*; do
        [[ $(cat "$device/vendor") == 0x10de ]] || continue
        [[ $(cat "$device/class") == 0x030[02]* && -w $device/power/control ]] && echo auto >"$device/power/control"
    done
    echo "Removed: the NVIDIA card may power off when idle on AC too."
    exit 0
fi

# root-owned copies: udev runs the script as root
install -Dm755 -o root -g root "$here/nvidia-ac-power" "$script"
install -Dm644 -o root -g root "$here/90-nvidia-ac-power.rules" "$rules"
udevadm control --reload
"$script"

for device in /sys/bus/pci/devices/*; do
    [[ $(cat "$device/vendor") == 0x10de && $(cat "$device/class") == 0x030[02]* ]] || continue
    echo "NVIDIA card $(basename "$device"): power/control = $(cat "$device/power/control")"
done
