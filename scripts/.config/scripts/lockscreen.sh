#!/bin/bash
# hyprlock with the clock and password on the monitor focused now, over one of two
# backgrounds (Settings > Lock Screen, or the first argument):
#
#   rain     a fullscreen unimatrix on every monitor, seen through hyprlock. The rain goes
#            up first: the desktop shows through hyprlock, and a wake-up shows the last
#            frame before the suspend, so that frame has to be the rain. The bar and
#            notifications are off meanwhile, or they'd draw over it.
#   picture  the current wallpaper, opaque, locking immediately.
set -uo pipefail

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/lockscreen.lock"
flock -n 9 || exit 0
pidof hyprlock >/dev/null && exit 0

TITLE=MATRIXLOCK
THEME="$HOME/.config/theme/current/hyprlock.conf"
config="$XDG_RUNTIME_DIR/hyprlock.conf"
settings=("$HOME"/.local/state/quickshell/by-shell/*/settings.json)
style=${1:-$(jq -r '.lockStyle // "rain"' "${settings[0]}" 2>/dev/null)}

monitors=$(hyprctl -j monitors)
focused=$(jq -r '.[] | select(.focused) | .name' <<<"$monitors" | head -n1)
rain_color=$(sed -n 's/.*@RAIN=\([^ ]*\).*/\1/p' "$THEME")
solid_color=$(sed -n 's/.*@SOLID=\([^ ]*\).*/\1/p' "$THEME")

cleanup_rain() {
    pkill -f "kitty --title $TITLE" 2>/dev/null
    qs ipc call bar reveal >/dev/null 2>&1
    qs ipc call notifications dnd false >/dev/null 2>&1
}

start_rain() {
    trap cleanup_rain EXIT INT TERM
    qs ipc call bar hide >/dev/null 2>&1
    qs ipc call notifications dnd true >/dev/null 2>&1

    local windows mapped workspace
    windows=$(jq length <<<"$monitors")
    jq -r '.[].activeWorkspace.id' <<<"$monitors" | while read -r workspace; do
        hyprctl eval "hl.exec_cmd('kitty --title $TITLE --start-as=fullscreen unimatrix -c cyan -b -s 96 -f -l m', { workspace = '$workspace' })" >/dev/null
    done
    # Capped, so it locks even if kitty fails
    for _ in {1..30}; do
        mapped=$(hyprctl -j clients | jq --arg title "$TITLE" '[.[] | select(.title == $title and .mapped)] | length')
        ((mapped >= windows)) && break
        sleep 0.05
    done
    # Mapped isn't drawn yet: give it time to reach the screen
    sleep 0.5
}

picture=""
color=$rain_color
if [[ $style == picture ]]; then
    picture=$(readlink -f "$HOME/.local/state/wallpaper/current")
    [[ -f $picture ]] || picture=""
    color=$solid_color
else
    start_rain
fi

install -m 600 /dev/null "$config"
sed -e "s|@MONITOR@|$focused|" -e "s|@PICTURE@|$picture|" -e "s|@COLOR@|$color|" "$THEME" >"$config"
hyprlock --config "$config" &
wait $!

if [[ -n $focused ]]; then
    hyprctl dispatch "hl.dsp.focus({ monitor = \"$focused\" })" >/dev/null
fi
