#!/usr/bin/env bash
# Installs the kuvk boot splash: the fastfetch logo, a password field for the encrypted
# drives and a progress bar after it. Plymouth reads it from the initramfs, so this
# rebuilds the initramfs; run it again to change colors.
#
#   sudo plymouth/install.sh               Catppuccin Mocha colors
#   sudo plymouth/install.sh --theme       the current theme's colors (theme-set.py)
#   plymouth/install.sh --preview FILE     draw the password step to an image, without installing
#   plymouth/install.sh --preview-progress FILE   the same for the progress bar (at 60%)
#
# Also installs the luks-poweroff mkinitcpio hook (after sd-encrypt): failing to unlock the
# drives powers off. The limits come from the kernel options in /etc/kernel/cmdline:
# rd.luks.options=timeout=90s,tries=3 systemd.default_device_timeout_sec=infinity
#
# Back to the previous splash: sudo plymouth-set-default-theme -R rog_2
set -euo pipefail

here=$(dirname "$(readlink -f "$0")")
mode=install
use_theme=false
preview=
while (($#)); do
    case $1 in
        --theme) use_theme=true ;;
        --preview) mode=preview; preview=${2:?--preview needs a file}; shift ;;
        --preview-progress) mode=preview-progress; preview=${2:?--preview-progress needs a file}; shift ;;
        *) echo "usage: $0 [--theme] [--preview FILE | --preview-progress FILE]" >&2; exit 1 ;;
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

# Catppuccin Mocha, or the current theme's slots
base="#1e1e2e" surface0="#313244" text="#cdd6f4" subtext0="#a6adc8" mauve="#cba6f7"
accent="#fab387" accent2="#89b4fa"
if $use_theme; then
    colors="$home/.config/theme/current/colors.sh"
    [[ -r $colors ]] || { echo "No $colors; run theme-set.py first" >&2; exit 1; }
    # shellcheck source=/dev/null
    . "$colors"
fi

logo_text="$home/.config/fastfetch/fastfetch-logo.txt"
font=$(fc-match -f '%{file}' "JetBrainsMono Nerd Font")
[[ -r $logo_text ]] || { echo "No fastfetch logo at $logo_text" >&2; exit 1; }

# "#rrggbb" as Plymouth's "r, g, b" from 0 to 1
rgb() { awk -v r=$((16#${1:1:2})) -v g=$((16#${1:3:2})) -v b=$((16#${1:5:2})) 'BEGIN { printf "%.3f, %.3f, %.3f", r/255, g/255, b/255 }'; }

build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT

# Images: the hint under the password field in subtext0 (accent2, then accent after wrong passwords; the farewell line in mauve), the logo in fastfetch's color, the password field in surface0 with an accent outline, dots and progress bar in accent2
magick -background none -fill "$mauve" -font "$font" -pointsize 18 label:@"$logo_text" "$build/logo.png"
# The password field and progress bar are as wide as the logo
ew=$(magick identify -format %w "$build/logo.png")
magick -size "${ew}x48" xc:none -fill "$surface0" -stroke "$accent" -strokewidth 2 \
    -draw "roundrectangle 1,1 $((ew - 2)),46 23,23" "$build/entry.png"
magick -background none -fill "$subtext0" -font "$font" -pointsize 16 label:"Speak, friend, and enter!" "$build/hint.png"
magick -background none -fill "$accent2" -font "$font" -pointsize 16 label:"Tell me, friend, when did you abandon reason for madness?" "$build/wrong1.png"
magick -background none -fill "$accent" -font "$font" -pointsize 16 label:"You shall not pass!" "$build/wrong2.png"
magick -background none -fill "$mauve" -font "$font" -pointsize 28 label:"Go back to the Shadow!" "$build/farewell.png"
magick -size 14x14 xc:none -fill "$accent2" -draw "circle 7,7 7,1" "$build/bullet.png"
magick -size "${ew}x10" xc:none -fill "$surface0" -draw "roundrectangle 0,0 $((ew - 1)),9 5,5" "$build/progress_box.png"
magick -size "${ew}x10" xc:none -fill "$accent2" -draw "roundrectangle 0,0 $((ew - 1)),9 5,5" "$build/progress_bar.png"
sed -e "s/@BG_RGB@/$(rgb "$base")/" -e "s/@TEXT_RGB@/$(rgb "$subtext0")/" "$here/kuvk.script" >"$build/kuvk.script"
sed -e "s/@BG@/${base#\#}/" "$here/kuvk.plymouth" >"$build/kuvk.plymouth"

if [[ $mode == preview* ]]; then
    # 1920x1080, laid out like the script does it
    lw=$(magick identify -format %w "$build/logo.png"); lh=$(magick identify -format %h "$build/logo.png")
    ly=$((540 - lh / 2)); ey=$((ly + lh + 40)); ex=$((960 - ew / 2))
    if [[ $mode == preview-progress ]]; then
        py=$((ey + 24 - 5))
        magick -size 1920x1080 "xc:$base" \
            "$build/logo.png" -geometry +$((960 - lw / 2))+$ly -composite \
            "$build/progress_box.png" -geometry +$ex+$py -composite \
            \( "$build/progress_bar.png" -resize "$((ew * 6 / 10))x10!" \) -geometry +$ex+$py -composite \
            "$preview"
        echo "Preview: $preview"
        exit 0
    fi
    magick -size 1920x1080 "xc:$base" \
        "$build/logo.png" -geometry +$((960 - lw / 2))+$ly -composite \
        "$build/entry.png" -geometry +$ex+$ey -composite \
        \( "$build/bullet.png" -resize 7x7 \) -geometry +$((ex + ew / 2 - 15))+$((ey + 20)) -composite \
        \( "$build/bullet.png" -resize 7x7 \) -geometry +$((ex + ew / 2 - 3))+$((ey + 20)) -composite \
        \( "$build/bullet.png" -resize 7x7 \) -geometry +$((ex + ew / 2 + 9))+$((ey + 20)) -composite \
        "$build/hint.png" -geometry +$((960 - $(magick identify -format %w "$build/hint.png") / 2))+$((ey + 48 + 16)) -composite \
        "$preview"
    echo "Preview: $preview"
    exit 0
fi

theme=/usr/share/plymouth/themes/kuvk
install -d -m 0755 "$theme"
install -m 0644 "$build"/* "$theme"/
install -D -m 0644 "$here/luks-poweroff" /etc/initcpio/install/luks-poweroff
if ! grep -q '^HOOKS=.*\bluks-poweroff\b' /etc/mkinitcpio.conf; then
    sed -i '/^HOOKS=/s/\bsd-encrypt\b/sd-encrypt luks-poweroff/' /etc/mkinitcpio.conf
fi
plymouth-set-default-theme -R kuvk
echo "Installed. The boot splash shows at the next boot."
