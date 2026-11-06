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
    input_outline input_bg input_opacity dots user_color text_name check fail caps solid show_box show_clock \
    show_avatar < <(jq -r '[
    .lockStyle // "picture", .lockImage // "", .lockMatrixColor // "magenta", .lockClockColor // "accent2", .lockDateColor // "accent2",
    .lockAvatarColor // "accent2", .lockBoxOutlineColor // "accent", .lockBoxColor // "base", .lockBoxOpacity // 85,
    .lockInputOutlineColor // "accent2", .lockInputColor // "subtext0", .lockInputOpacity // 25,
    .lockDotsColor // "accent2", .lockUserColor // "accent", .lockTextColor // "text",
    .lockCheckColor // "green", .lockFailColor // "red", .lockCapsColor // "yellow", .lockSolidColor // "base",
    (if .lockBox == false then "off" else "on" end), (if .lockClock == false then "off" else "on" end),
    (if .lockAvatar == false then "off" else "on" end)
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

box_fill=$(hex_alpha "${box_bg:-base}" "${box_opacity:-85}")
box_border="$(hex "${box_outline:-accent}")ff"
# Settings > Lock Screen: parts switched off are left out of the config
drop=()
[[ $show_box == off ]] && drop+=(-e '/# @BOX{/,/# @BOX}/d')
[[ $show_clock == off ]] && drop+=(-e '/# @CLOCK{/,/# @CLOCK}/d')
[[ $show_avatar == off ]] && drop+=(-e '/# @AVATAR{/,/# @AVATAR}/d')

escape() { sed 's/[&|\\]/\\&/g' <<<"$1"; }

install -m 600 /dev/null "$config"
sed -e "s|@MONITOR@|$focused|g" -e "s|@PICTURE@|$(escape "$picture")|" -e "s|@COLOR@|$color|" \
    -e "s|@CLOCK@|$(hex "${clock:-accent2}")|g" -e "s|@DATE@|$(hex "${clock:-accent2}")|g" -e "s|@AVATAR@|$(hex "${avatar:-accent2}")|g" \
    -e "s|@BOX_OUTLINE@|$box_border|g" -e "s|@BOX_BG@|$box_fill|g" \
    -e "s|@INPUT_OUTLINE@|$(hex "${input_outline:-accent2}")|g" -e "s|@INPUT_BG@|$(hex_alpha "${input_bg:-subtext0}" "${input_opacity:-25}")|g" \
    -e "s|@DOTS@|$(hex "${dots:-accent2}")|g" -e "s|@USER@|$(hex "${user_color:-accent}")|g" -e "s|@TEXT@|$(hex "${text_name:-text}")|g" \
    -e "s|@CHECK@|$(hex "${check:-green}")|g" -e "s|@FAIL@|$(hex "${fail:-red}")|g" -e "s|@CAPS@|$(hex "${caps:-yellow}")|g" \
    "${drop[@]}" "$TEMPLATE" >"$config"
# hyprlock's output goes to ~/.cache/hyprlock.log (one lock's worth). It exits 0 on unlock.
# If it crashes instead, the session stays locked (misc:allow_session_lock_restore) and a new
# one takes over: after a sleep the monitors come back one by one, and with the laptop's
# screen off there's a moment with none but Hyprland's FALLBACK, which hyprlock dies on.
log="$HOME/.cache/hyprlock.log"
: >"$log"
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    hyprlock --config "$config" "${hyprlock_args[@]}" >>"$log" 2>&1 &
    wait $!
    status=$?
    ((status == 0)) && break
    echo "lockscreen.sh: hyprlock exited with $status (attempt $attempt); starting it again" >>"$log"
    sleep 2
    # its monitor may be gone now: the clock and password go to the focused one
    now=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name' | head -n1)
    if [[ -n $now && $now != "$focused" && $now != FALLBACK ]]; then
        sed -i "s|monitor = $focused\$|monitor = $now|" "$config"
        focused=$now
    fi
done

if [[ -n $focused ]]; then
    hyprctl dispatch "hl.dsp.focus({ monitor = \"$focused\" })" >/dev/null
fi
