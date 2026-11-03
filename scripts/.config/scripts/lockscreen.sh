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
#   solid    (Solid color) the theme color chosen in Settings, opaque.
set -uo pipefail

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/lockscreen.lock"
flock -n 9 || exit 0
pidof hyprlock >/dev/null && exit 0

TITLE=MATRIXLOCK
TEMPLATE="$HOME/.config/theme/current/hyprlock.conf"
config="$XDG_RUNTIME_DIR/hyprlock.conf"
settings=("$HOME"/.local/state/quickshell/by-shell/*/settings.json)
IFS=$'\x1f' read -r saved image matrix clock date avatar box_outline box_bg box_opacity \
    input_outline input_bg input_opacity dots user_color text_name check fail caps solid show_box < <(jq -r '[
    .lockStyle // "picture", .lockImage // "", .lockMatrixColor // "magenta", .lockClockColor // "accent2", .lockDateColor // "accent2",
    .lockAvatarColor // "accent2", .lockBoxOutlineColor // "accent", .lockBoxColor // "base", .lockBoxOpacity // 85,
    .lockInputOutlineColor // "accent2", .lockInputColor // "subtext0", .lockInputOpacity // 25,
    .lockDotsColor // "accent2", .lockUserColor // "accent", .lockTextColor // "text",
    .lockCheckColor // "green", .lockFailColor // "red", .lockCapsColor // "yellow", .lockSolidColor // "base",
    (if .lockBox == false then "off" else "on" end)
] | join("\u001f")' "${settings[0]}" 2>/dev/null)
style=${1:-${saved:-picture}}

# Theme color by name, without the #
. "$HOME/.config/theme/current/colors.sh"
hex() {
    local value=${!1:-}
    value=${value:-$text}
    printf '%s' "${value#\#}"
}

# Color and opacity (percent) as rrggbbaa
hex_alpha() {
    printf '%s%02x' "$(hex "$1")" $(($2 * 255 / 100))
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
        hyprctl eval "hl.exec_cmd('kitty --title $TITLE --start-as=fullscreen unimatrix -c ${matrix:-magenta} -b -s 96 -f -l m', { workspace = '$workspace' })" >/dev/null
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

hyprlock_args=()
picture=""
color=$rain_color
if [[ $style == rain ]]; then
    start_rain
else
    color=$solid_color
    if [[ $style == solid ]]; then
        color="rgb($(hex "${solid:-base}"))"
    else
        [[ $style == image && -f $image ]] && picture=$image
        [[ -n $picture ]] || picture=$(readlink -f "$HOME/.local/state/wallpaper/current")
        [[ -f $picture ]] || picture=""
    fi
    # The first frame is the whole lock: a suspend can freeze the screen right after it,
    # and partway through a fade the desktop would still show on wake
    hyprlock_args+=(--no-fade-in --immediate-render)
fi

# Settings > Lock Screen > Box off: the card is drawn fully transparent
box_fill=$(hex_alpha "${box_bg:-base}" "${box_opacity:-85}")
box_border="$(hex "${box_outline:-accent}")ff"
if [[ $show_box == off ]]; then
    box_fill=00000000
    box_border=00000000
fi

escape() { sed 's/[&|\\]/\\&/g' <<<"$1"; }

install -m 600 /dev/null "$config"
sed -e "s|@MONITOR@|$focused|g" -e "s|@PICTURE@|$(escape "$picture")|" -e "s|@COLOR@|$color|" \
    -e "s|@CLOCK@|$(hex "${clock:-accent2}")|g" -e "s|@DATE@|$(hex "${date:-accent2}")|g" -e "s|@AVATAR@|$(hex "${avatar:-accent2}")|g" \
    -e "s|@BOX_OUTLINE@|$box_border|g" -e "s|@BOX_BG@|$box_fill|g" \
    -e "s|@INPUT_OUTLINE@|$(hex "${input_outline:-accent2}")|g" -e "s|@INPUT_BG@|$(hex_alpha "${input_bg:-subtext0}" "${input_opacity:-25}")|g" \
    -e "s|@DOTS@|$(hex "${dots:-accent2}")|g" -e "s|@USER@|$(hex "${user_color:-accent}")|g" -e "s|@TEXT@|$(hex "${text_name:-text}")|g" \
    -e "s|@CHECK@|$(hex "${check:-green}")|g" -e "s|@FAIL@|$(hex "${fail:-red}")|g" -e "s|@CAPS@|$(hex "${caps:-yellow}")|g" "$TEMPLATE" >"$config"
hyprlock --config "$config" "${hyprlock_args[@]}" &
wait $!

if [[ -n $focused ]]; then
    hyprctl dispatch "hl.dsp.focus({ monitor = \"$focused\" })" >/dev/null
fi
