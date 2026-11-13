#!/usr/bin/env bash
# Installs Hyprdori's boot splash: the logo above a password field for the encrypted
# drives, a progress bar after it and the text logo at the bottom. Plymouth reads it from the
# initramfs, so this rebuilds the initramfs; run it again to change colors.
#
#   sudo plymouth/install.sh               the current theme's colors, accents included
#                                          (hyprdori-theme-set; Catppuccin Mocha before it has run)
#   sudo plymouth/install.sh --theme       the same, but stop if there's no theme yet
#   plymouth/install.sh --preview FILE     draw the password step to an image, without installing
#   plymouth/install.sh --preview-progress FILE   the same for the progress bar (at 60%)
#   plymouth/install.sh --preview-farewell FILE   the same for the farewell before powering off
#   --radius PX                            with any of these: the password field's and progress
#                                          bar's corners (0 square) instead of Settings > Style's
#
# The progress bar fills in the time this boot took from the drives unlocking (or the splash
# starting, without encryption) to its end, read from the journal (3 to 20 s; 8 s without one),
# so it matches each machine; run it again to measure again. The splash then stays on screen
# until the login screen or the desktop draws over it, with no text console in between: a
# plymouth-quit drop-in (/etc/systemd/system/plymouth-quit.service.d/hyprdori.conf) quits it
# with --retain-splash. Should those fail to start, Ctrl+Alt+F2 gives a text login.
#
# Also installs the luks-poweroff mkinitcpio hook (after sd-encrypt): failing to unlock the
# drives powers off. The limits come from the kernel options in /etc/kernel/cmdline:
# rd.luks.options=timeout=90s,tries=3 systemd.default_device_timeout_sec=infinity

set -euo pipefail

here=$(dirname "$(readlink -f "$0")")
mode=install
use_theme=false
preview=
radius=
while (($#)); do
    case $1 in
        --theme) use_theme=true ;;
        --preview) mode=preview; preview=${2:?--preview needs a file}; shift ;;
        --preview-progress) mode=preview-progress; preview=${2:?--preview-progress needs a file}; shift ;;
        --preview-farewell) mode=preview-farewell; preview=${2:?--preview-farewell needs a file}; shift ;;
        --radius)
            [[ ${2:-} =~ ^[0-9]+$ ]] || { echo "--radius takes pixels, e.g. 0 or 8" >&2; exit 1; }
            radius=$2
            shift
            ;;
        *) echo "usage: $0 [--theme] [--radius PX] [--preview FILE | --preview-progress FILE | --preview-farewell FILE]" >&2; exit 1 ;;
    esac
    shift
done

if [[ $mode == install ]]; then
    if ((EUID != 0)) || [[ -z ${SUDO_USER:-} || $SUDO_USER == root ]]; then
        echo "Run through sudo from your own account: sudo $0" >&2
        exit 1
    fi
    home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    home=$HOME
fi

# The current theme's colors, or Catppuccin's before hyprdori-theme-set has run
background="#1e1e2e" foreground="#cdd6f4" subtext="#a2a8c2" accent="#89b4fa" magenta="#cba6f7"
red="#f38ba8" yellow="#fab387" field="#272738" field_radius=8
colors="$home/.config/theme/current/colors.sh"
if [[ -r $colors ]]; then
    # shellcheck source=/dev/null
    . "$colors"
elif $use_theme; then
    echo "No $colors; run hyprdori-theme-set first" >&2
    exit 1
fi
# Settings > Style > Corner radius (square at 0), or --radius
[[ -n $radius ]] && field_radius=$radius

logo_text="$home/.config/theme/logo/dori-logo"
words_text="$home/.config/theme/logo/dori-text"
font=$(fc-match -f '%{file}' "JetBrainsMono Nerd Font")
[[ -r $logo_text ]] || { echo "No logo at $logo_text" >&2; exit 1; }

# "#rrggbb" as Plymouth's "r, g, b" from 0 to 1
rgb() { awk -v r=$((16#${1:1:2})) -v g=$((16#${1:3:2})) -v b=$((16#${1:5:2})) 'BEGIN { printf "%.3f, %.3f, %.3f", r/255, g/255, b/255 }'; }

build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT

# Images, in the lock and login screens' look: the logo and the text logo in magenta; the
# password field (the background with 5% of the text color) with an accent outline, dots in the
# text color; the hint under the field in the secondary text color (yellow, then red after wrong
# passwords); the progress bar in the accent on a faint track; the farewell line in red,
# large, alone on the screen
# The logos drawn like kitty draws them, in 24px rows (bin/.local/bin/hyprdori-logo-render); no
# text logo, an empty image
"$here/../bin/.local/bin/hyprdori-logo-render" --logo "$logo_text" --color "$magenta" --cell-height 24 --out "$build/logo.png"
if [[ -r $words_text ]]; then
    "$here/../bin/.local/bin/hyprdori-logo-render" --logo "$words_text" --color "$magenta" --cell-height 24 --out "$build/text.png"
else
    magick -size 1x1 xc:none "$build/text.png"
fi
# The password field and progress bar are 338 px wide (the logo's width), or as wide as a wider
# logo; the field 38 px high, as the lock and login screens' field: a box with a 2 px outline and
# their corners (Settings > Style > Corner radius). Plymouth draws them larger on a screen it
# scales.
ew=$(magick identify -format %w "$build/logo.png")
((ew < 338)) && ew=338
eh=38
if ((field_radius > 0)); then
    field_shape="roundrectangle 1,1 $((ew - 2)),$((eh - 2)) $field_radius,$field_radius"
else
    field_shape="rectangle 1,1 $((ew - 2)),$((eh - 2))"
fi
magick -size "${ew}x$eh" xc:none -fill "$field" -stroke "$accent" -strokewidth 2 \
    -draw "$field_shape" "$build/entry.png"
magick -background none -fill "$subtext" -font "$font" -pointsize 16 label:"Speak, friend, and enter!" "$build/hint.png"
magick -background none -fill "$yellow" -font "$font" -pointsize 16 label:"Tell me, friend, when did you abandon reason for madness?" "$build/wrong1.png"
magick -background none -fill "$red" -font "$font" -pointsize 16 label:"You shall not pass!" "$build/wrong2.png"
magick -background none -fill "$magenta" -font "$font" -pointsize 60 label:"Go back to the Shadow!" "$build/farewell.png"
magick -size 14x14 xc:none -fill "$foreground" -draw "circle 7,7 7,1" "$build/bullet.png"
# The progress bar 14 px high, rounded (fully) or square as the field: its track, and the bar in
# three parts, its ends and a middle the script stretches, so the ends keep their shape
ph=14 pr=7
if ((field_radius > 0)); then
    track_shape="roundrectangle 0,0 $((ew - 1)),$((ph - 1)) $pr,$pr" end_shape="circle $pr,$pr $pr,0"
else
    track_shape="rectangle 0,0 $((ew - 1)),$((ph - 1))" end_shape="rectangle 0,0 $((2 * pr - 1)),$((ph - 1))"
fi
magick -size "${ew}x$ph" xc:none -fill "${foreground}2e" -draw "$track_shape" "$build/progress_box.png"
magick -size "$((2 * pr))x$ph" xc:none -fill "$accent" -draw "$end_shape" "$build/end.png"
magick "$build/end.png" -crop "${pr}x$ph+0+0" +repage "$build/progress_left.png"
magick "$build/end.png" -crop "${pr}x$ph+$pr+0" +repage "$build/progress_right.png"
magick -size "1x$ph" "xc:$accent" "$build/progress_middle.png"
rm "$build/end.png"
# Encrypted drives get the password field first; without them the progress bar shows from the start
encrypted=0
grep -qE '^HOOKS=.*\b(sd-)?encrypt\b' /etc/mkinitcpio.conf && encrypted=1
# The bar's duration: from the first drive unlocked (or the splash started) to the splash
# ending, in this boot's journal; 3 to 20 s, 8 s when the journal has neither (a first install)
boot_seconds=8.0
if [[ $mode == install ]]; then
    boot_seconds=$(journalctl -b 0 -o short-monotonic _PID=1 2>/dev/null | awk -v enc="$encrypted" '
        { line = $0; sub(/^\[ */, "", line); t = line + 0 }
        !start && enc == 1 && /Finished Cryptography Setup for / { start = t }
        !start && enc == 0 && /Started Show Plymouth Boot Screen/ { start = t }
        start && /Starting Terminate Plymouth Boot Screen/ { end = t }
        END {
            d = (start && end > start) ? end - start : 8
            if (d < 3) d = 3
            if (d > 20) d = 20
            printf "%.1f", d
        }')
fi
sed -e "s/@BG_RGB@/$(rgb "$background")/" -e "s/@TEXT_RGB@/$(rgb "$subtext")/" -e "s/@ENCRYPTED@/$encrypted/" \
    -e "s/@BOOT_SECONDS@/$boot_seconds/" "$here/hyprdori.script" >"$build/hyprdori.script"
sed -e "s/@BG@/${background#\#}/" "$here/hyprdori.plymouth" >"$build/hyprdori.plymouth"

if [[ $mode == preview-farewell ]]; then
    # 1920x1080: the line alone, centered
    magick -size 1920x1080 "xc:$background" "$build/farewell.png" -gravity center -composite "$preview"
    echo "Preview: $preview"
    exit 0
fi
if [[ $mode == preview* ]]; then
    # 1920x1080, laid out like the script does it: the field centered, the logo 40 px above it,
    # the text logo 60 px from the bottom
    lw=$(magick identify -format %w "$build/logo.png"); lh=$(magick identify -format %h "$build/logo.png")
    tw=$(magick identify -format %w "$build/text.png"); th=$(magick identify -format %h "$build/text.png")
    ex=$((960 - ew / 2)); ey=$((540 - eh / 2)); ly=$((ey - 40 - lh))
    logos=("$build/logo.png" -geometry +$((960 - lw / 2))+$ly -composite
    "$build/text.png" -geometry +$((960 - tw / 2))+$((1080 - 60 - th)) -composite)
    if [[ $mode == preview-progress ]]; then
        py=$((ey + eh / 2 - ph / 2)) bw=$((ew * 6 / 10))
        magick -size 1920x1080 "xc:$background" "${logos[@]}" \
            "$build/progress_box.png" -geometry +$ex+$py -composite \
            "$build/progress_left.png" -geometry +$ex+$py -composite \
            \( "$build/progress_middle.png" -resize "$((bw - 2 * pr))x$ph!" \) -geometry +$((ex + pr))+$py -composite \
            "$build/progress_right.png" -geometry +$((ex + bw - pr))+$py -composite \
            "$preview"
        echo "Preview: $preview"
        exit 0
    fi
    magick -size 1920x1080 "xc:$background" "${logos[@]}" \
        "$build/entry.png" -geometry +$ex+$ey -composite \
        \( "$build/bullet.png" -resize 9x9 \) -geometry +$((ex + ew / 2 - 17))+$((ey + eh / 2 - 5)) -composite \
        \( "$build/bullet.png" -resize 9x9 \) -geometry +$((ex + ew / 2 - 4))+$((ey + eh / 2 - 5)) -composite \
        \( "$build/bullet.png" -resize 9x9 \) -geometry +$((ex + ew / 2 + 9))+$((ey + eh / 2 - 5)) -composite \
        "$build/hint.png" -geometry +$((960 - $(magick identify -format %w "$build/hint.png") / 2))+$((ey + eh + 16)) -composite \
        "$preview"
    echo "Preview: $preview"
    exit 0
fi

theme=/usr/share/plymouth/themes/hyprdori
install -d -m 0755 "$theme"
install -m 0644 "$build"/* "$theme"/
install -D -m 0644 "$here/luks-poweroff" /etc/initcpio/install/luks-poweroff
if ! grep -q '^HOOKS=.*\bluks-poweroff\b' /etc/mkinitcpio.conf; then
    sed -i '/^HOOKS=/s/\bsd-encrypt\b/sd-encrypt luks-poweroff/' /etc/mkinitcpio.conf
fi
# The splash kept on screen until the login screen or the desktop replaces it (sddm.service
# starts after plymouth-quit.service), so no text console shows in between
install -D -m 0644 /dev/stdin /etc/systemd/system/plymouth-quit.service.d/hyprdori.conf <<'EOF'
# Written by plymouth/install.sh in Hyprdori: the splash stays on screen until the login
# screen or the desktop draws over it, with no text console in between
[Service]
ExecStart=
ExecStart=-/usr/bin/plymouth quit --retain-splash
EOF
systemctl daemon-reload
plymouth-set-default-theme -R hyprdori
echo "Installed (the progress bar fills in ${boot_seconds} s). The boot splash shows at the next boot."
