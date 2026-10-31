#!/bin/bash
# hyprlock with the clock and password on the monitor focused now. The style and colors come
# from Settings > Lock Screen; the first argument overrides the style:
#
#   rain     (Matrix) a fullscreen unimatrix on every monitor, seen through hyprlock. It goes
#            up first: the desktop shows through hyprlock, and a wake-up shows the last frame
#            before the suspend, so that frame has to be the rain. The bar and notifications
#            are off meanwhile, or they'd draw over it.
#   picture  (Background) the current wallpaper, opaque.
#   image    (Image) the chosen image, opaque; the wallpaper if there is none.
set -uo pipefail

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/lockscreen.lock"
flock -n 9 || exit 0
pidof hyprlock >/dev/null && exit 0

TITLE=MATRIXLOCK
TEMPLATE="$HOME/.config/theme/current/hyprlock.conf"
config="$XDG_RUNTIME_DIR/hyprlock.conf"
settings=("$HOME"/.local/state/quickshell/by-shell/*/settings.json)
IFS=$'\x1f' read -r saved image matrix clock outline dots text_name < <(jq -r '[
    .lockStyle // "rain", .lockImage // "", .lockMatrixColor // "cyan", .lockClockColor // "sky",
    .lockOutlineColor // "accent2", .lockDotsColor // "peach", .lockTextColor // "text"
] | join("\u001f")' "${settings[0]}" 2>/dev/null)
style=${1:-${saved:-rain}}

# Theme color by name, without the #
. "$HOME/.config/theme/current/colors.sh"
hex() {
    local value=${!1:-}
    value=${value:-$text}
    printf '%s' "${value#\#}"
}

monitors=$(hyprctl -j monitors)
focused=$(jq -r '.[] | select(.focused) | .name' <<<"$monitors" | head -n1)
rain_color=$(sed -n 's/.*@RAIN=\([^ ]*\).*/\1/p' "$TEMPLATE")
solid_color=$(sed -n 's/.*@SOLID=\([^ ]*\).*/\1/p' "$TEMPLATE")

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
        hyprctl eval "hl.exec_cmd('kitty --title $TITLE --start-as=fullscreen unimatrix -c ${matrix:-cyan} -b -s 96 -f -l m', { workspace = '$workspace' })" >/dev/null
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
if [[ $style == rain ]]; then
    start_rain
else
    color=$solid_color
    [[ $style == image && -f $image ]] && picture=$image
    [[ -n $picture ]] || picture=$(readlink -f "$HOME/.local/state/wallpaper/current")
    [[ -f $picture ]] || picture=""
    # Hold a suspend until the lock has reached the screen, so a wake-up shows it first
    systemd-inhibit --what=sleep --mode=delay --who=lockscreen --why="Showing the lock screen" sleep 1 9>&- >/dev/null 2>&1 &
fi

escape() { sed 's/[&|\\]/\\&/g' <<<"$1"; }

install -m 600 /dev/null "$config"
sed -e "s|@MONITOR@|$focused|g" -e "s|@PICTURE@|$(escape "$picture")|" -e "s|@COLOR@|$color|" \
    -e "s|@CLOCK@|$(hex "${clock:-sky}")|g" -e "s|@OUTLINE@|$(hex "${outline:-accent2}")|g" \
    -e "s|@DOTS@|$(hex "${dots:-peach}")|g" -e "s|@TEXT@|$(hex "${text_name:-text}")|g" "$TEMPLATE" >"$config"
hyprlock --config "$config" &
wait $!

if [[ -n $focused ]]; then
    hyprctl dispatch "hl.dsp.focus({ monitor = \"$focused\" })" >/dev/null
fi
