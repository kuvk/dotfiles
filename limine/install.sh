#!/usr/bin/env bash
# Installs Limine on the ESP and writes its menu: one entry per kernel in /efi/arch
# (mkinitcpio's presets put kernels and images there), styled like the boot splash:
# the fastfetch logo in magenta above an "Arch Linux" tree of kernels in accent.
# Run it again after a Limine update, a new kernel, or to change colors.
#
#   sudo limine/install.sh             the current theme's colors, accents included
#                                      (hyprdori-theme-set; Catppuccin Mocha before it has run)
#   sudo limine/install.sh --theme     the same, but stop if there's no theme yet
#   limine/install.sh --print          print the config instead, without installing
#   limine/install.sh --preview FILE   draw the wallpaper (the logo, no menu text) to FILE
#   --resolution WxH                   the menu's resolution; by default the native mode of the
#                                      boot display's screen (the logo is placed for it)
#
# Kernel options come from /etc/kernel/cmdline (made from the running system's on first run).
# At boot, E on an entry edits its options for that boot only.
set -euo pipefail

here=$(dirname "$(readlink -f "$0")")
esp=/efi
kernels=/efi/arch
mode=install
use_theme=false
resolution=
options="$*"  # kept in limine.conf, so hyprdori-update can run this again the same way
while (($#)); do
    case $1 in
        --theme) use_theme=true ;;
        --print) mode=print ;;
        --preview) mode=preview; preview=${2:?--preview needs a file}; shift ;;
        --resolution) resolution=${2:?--resolution needs WxH}; shift ;;
        *) echo "usage: $0 [--theme] [--resolution WxH] [--print | --preview FILE]" >&2; exit 1 ;;
    esac
    shift
done

if [[ $mode == install ]]; then
    if ((EUID != 0)) || [[ -z ${SUDO_USER:-} || $SUDO_USER == root ]]; then
        echo "Run through sudo from your own account: sudo $0" >&2
        exit 1
    fi
    home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    [[ -r /usr/share/limine/BOOTX64.EFI ]] || { echo "Install Limine first: pacman -S limine" >&2; exit 1; }
else
    home=$HOME
fi

# The current theme's colors, or Catppuccin's before hyprdori-theme-set has run
background="#1e1e2e" selection="#45475a" muted="#585b70" foreground="#cdd6f4"
light_foreground="#bac2de" bright_foreground="#cdd6f4" accent="#89b4fa" magenta="#cba6f7"
red="#f38ba8" green="#a6e3a1" yellow="#fab387" blue="#89b4fa" cyan="#94e2d5"
bright_red="#f38ba8" bright_green="#a6e3a1" bright_yellow="#f9e2af" bright_blue="#89b4fa"
bright_magenta="#f5c2e7" bright_cyan="#94e2d5"
colors="$home/.config/theme/current/colors.sh"
if [[ -r $colors ]]; then
    # shellcheck source=/dev/null
    . "$colors"
elif $use_theme; then
    echo "No $colors; run hyprdori-theme-set first" >&2
    exit 1
fi
hex() { local c; for c; do printf '%s;' "${c#\#}"; done | sed 's/;$//'; }

# Kernel options: the running system's, without the initrd= the old loader added
if [[ ! -s /etc/kernel/cmdline ]]; then
    cmdline=$(sed -E 's/(^| )initrd=[^ ]*//g; s/  +/ /g; s/ $//' /proc/cmdline)
    if [[ $mode == install ]]; then
        echo "$cmdline" >/etc/kernel/cmdline
        echo "Wrote /etc/kernel/cmdline from the running system"
    fi
else
    cmdline=$(</etc/kernel/cmdline)
fi

found_kernels() {
    local k
    for k in linux linux-g14 linux-lts $(ls "$kernels" 2>/dev/null | sed -n 's/^vmlinuz-//p' | grep -vx 'linux\|linux-g14\|linux-lts'); do
        [[ -e $kernels/vmlinuz-$k && -e $kernels/initramfs-$k.img ]] && echo "$k"
    done
    return 0
}
mapfile -t found < <(found_kernels)
((${#found[@]})) || { echo "No kernels with images in $kernels" >&2; exit 1; }

# The resolution: given, or the first connected screen's native mode on the boot display's
# card (the one the firmware, and so Limine, draws on)
if [[ -z $resolution ]]; then
    for card in /sys/class/drm/card[0-9]; do
        [[ $(cat "$card/device/boot_vga" 2>/dev/null) == 1 ]] || continue
        for conn in "$card"-*; do
            [[ $(cat "$conn/status" 2>/dev/null) == connected ]] || continue
            resolution=$(head -1 "$conn/modes"); break 2
        done
    done
fi
[[ ${resolution:-} =~ ^([0-9]+)x([0-9]+)$ ]] || { echo "No resolution found; pass --resolution WxH" >&2; exit 1; }
res_w=${BASH_REMATCH[1]} res_h=${BASH_REMATCH[2]}

# Limine doubles its 8x16 font from 2560x1440 up; each cell also has a 1 pixel letter gap.
# The logo goes above the tree, centered on it.
scale=1
((res_w >= 2560 && res_h >= 1440)) && scale=2
cell_w=$((9 * scale)) cell_h=$((16 * scale))
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT

wallpaper() {
    local logo_text lw lh top k line max_len=0 cols prefix center
    logo_text="$home/.config/theme/logo/ascii-dori"
    [[ -r $logo_text ]] || { echo "No logo at $logo_text" >&2; exit 1; }
    # drawn like kitty draws it, in 12px rows (24 on large screens), by Hyprdori's hyprdori-logo-render
    "$here/../bin/.local/bin/hyprdori-logo-render" --logo "$logo_text" --color "$magenta" --cell-height $((12 * scale)) --out "$build/logo.png"
    lw=$(magick identify -format %w "$build/logo.png"); lh=$(magick identify -format %h "$build/logo.png")
    top=$(((res_h / cell_h - ${#found[@]} - 1) / 2 * cell_h))
    # Limine's centering (menu.c): each line is its tree marks plus " name ", the widest
    # sets the indent (cols - widest - 3) / 2; "[-] Arch Linux " is 15, "  ──► kernel " is 7 + name.
    max_len=15
    for k in "${found[@]}"; do line=$((7 + ${#k})); ((line > max_len)) && max_len=$line; done
    cols=$((res_w / cell_w)); prefix=$(((cols - max_len - 3) / 2))
    center=$(((res_w - cols * cell_w) / 2 + prefix * cell_w + (max_len - 1) * cell_w / 2))
    magick -size "${res_w}x$res_h" "xc:$background" \
        "$build/logo.png" -geometry +$((center - lw / 2))+$((top - 32 * scale - lh)) -composite "$1"
}

config() {
    cat <<EOF
# Written by limine/install.sh in Hyprdori; edit that and run it again.
# Options: $options
timeout: 3
default_entry: 2
terse: yes
interface_resolution: ${res_w}x$res_h
interface_branding: HYPRDORI
interface_branding_colour: $(hex "$accent")
interface_help_hidden: yes
interface_help_colour: $(hex "$accent")
interface_help_colour_bright: $(hex "$bright_foreground")
wallpaper: boot():/EFI/limine/wallpaper.png
wallpaper_style: centered
backdrop: $(hex "$background")
term_font_scale: ${scale}x$scale
term_background: ff$(hex "$background")
term_foreground: $(hex "$accent")
term_background_bright: $(hex "$selection")
term_foreground_bright: $(hex "$accent")
term_palette: $(hex "$selection" "$red" "$green" "$yellow" "$blue" "$magenta" "$cyan" "$light_foreground")
term_palette_bright: $(hex "$muted" "$bright_red" "$bright_green" "$bright_yellow" "$bright_blue" "$bright_magenta" "$bright_cyan" "$bright_foreground")
term_margin: 0
term_margin_gradient: 0

/+Arch Linux
EOF
    local k
    for k in "${found[@]}"; do
        cat <<EOF
//$k
    protocol: linux
    path: boot():/${kernels#"$esp"/}/vmlinuz-$k
    module_path: boot():/${kernels#"$esp"/}/initramfs-$k.img
    cmdline: $cmdline
EOF
    done
}

if [[ $mode == print ]]; then
    config
    exit 0
fi
if [[ $mode == preview ]]; then
    wallpaper "$preview"
    echo "Preview: $preview"
    exit 0
fi

conf=$(config)
wallpaper "$build/wallpaper.png"
install -D -m 0644 /usr/share/limine/BOOTX64.EFI "$esp/EFI/limine/BOOTX64.EFI"
install -m 0644 "$build/wallpaper.png" "$esp/EFI/limine/"
printf '%s\n' "$conf" >"$esp/EFI/limine/limine.conf"

# A firmware boot entry, first in the boot order, made once
if ! efibootmgr | grep -q '\\EFI\\limine\\BOOTX64.EFI'; then
    part=$(findmnt -no SOURCE "$esp")
    efibootmgr --create --disk "/dev/$(lsblk -no PKNAME "$part")" \
        --part "$(<"/sys/class/block/${part#/dev/}/partition")" \
        --label "Limine" --loader '\EFI\limine\BOOTX64.EFI' --unicode >/dev/null
    echo "Added the Limine boot entry, first in the boot order"
fi
echo "Installed. Limine shows at the next boot."
