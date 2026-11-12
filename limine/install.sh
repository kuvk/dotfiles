#!/usr/bin/env bash
# Installs Limine on the ESP and writes its menu: one entry per kernel in /efi/arch
# (mkinitcpio's presets put kernels and images there), styled like the boot splash:
# the logo in magenta above an "Arch Linux" tree of kernels in accent, the text logo below.
# Run it again after a Limine update, a new kernel, or to change colors.
#
#   sudo limine/install.sh             the current theme's colors, accents included
#                                      (hyprdori-theme-set; Catppuccin Mocha before it has run)
#   sudo limine/install.sh --theme     the same, but stop if there's no theme yet
#   limine/install.sh --print          print the config instead, without installing
#   limine/install.sh --preview FILE   draw the wallpaper (the logos, no menu text) to FILE
#   --resolution WxH                   the menu's resolution; by default the native mode of the
#                                      boot display's screen (the logo is placed for it)
#
# Kernel options come from /etc/kernel/cmdline (made from the running system's on first run).
# At boot, E on an entry edits its options for that boot only.
#
# The menu is /efi/limine.conf (Limine's last place to look, so nothing may sit in EFI/limine).
# With snapshots (a btrfs root and limine-snapper-sync, set up by install.sh) the Arch Linux
# entry gets a Snapshots folder, which limine-snapper-sync fills: it's filled again after
# every rewrite here.
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
# Snapshots in the menu: a btrfs root with limine-snapper-sync (install.sh sets it up)
snapshots=false
[[ $(findmnt -no FSTYPE / 2>/dev/null) == btrfs ]] && command -v limine-snapper-sync >/dev/null && snapshots=true
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

# Limine doubles its 8x16 font from 2560x1440 up. It centers the kernel tree on the screen; the
# logo goes just above it and the text logo near the bottom, above the countdown; both
# centered across the screen.
scale=1
((res_w >= 2560 && res_h >= 1440)) && scale=2
cell_h=$((16 * scale))
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT

wallpaper() {
    local logo_file text_file lw lh tw th tree_top logo_top text_top
    logo_file="$home/.config/theme/logo/dori-logo" text_file="$home/.config/theme/logo/dori-text"
    [[ -r $logo_file ]] || { echo "No logo at $logo_file" >&2; exit 1; }
    # drawn like kitty draws them, in 12px rows (24 on large screens), by hyprdori-logo-render
    "$here/../bin/.local/bin/hyprdori-logo-render" --logo "$logo_file" --color "$magenta" --cell-height $((12 * scale)) --out "$build/logo.png"
    lw=$(magick identify -format %w "$build/logo.png"); lh=$(magick identify -format %h "$build/logo.png")
    # the tree's first row, as Limine centers it (the entries and "Arch Linux")
    tree_top=$(((res_h / cell_h - ${#found[@]} - 1) / 2 * cell_h))
    # the logo ending 2 rows above the tree
    logo_top=$((tree_top - 2 * cell_h - lh))
    ((logo_top < 0)) && logo_top=0
    local layers=("$build/logo.png" -geometry +$(((res_w - lw) / 2))+$logo_top -composite)
    if [[ -r $text_file ]]; then
        "$here/../bin/.local/bin/hyprdori-logo-render" --logo "$text_file" --color "$magenta" --cell-height $((12 * scale)) --out "$build/text.png"
        tw=$(magick identify -format %w "$build/text.png"); th=$(magick identify -format %h "$build/text.png")
        # its bottom 4 rows from the screen's bottom, a row clear of the countdown line
        text_top=$((res_h - 4 * cell_h - th))
        layers+=("$build/text.png" -geometry +$(((res_w - tw) / 2))+$text_top -composite)
    fi
    magick -size "${res_w}x$res_h" "xc:$background" "${layers[@]}" "$1"
}

config() {
    cat <<EOF
# Written by limine/install.sh in Hyprdori; edit that and run it again.
# Options: $options
timeout: 3
default_entry: 2
terse: yes
interface_resolution: ${res_w}x$res_h
interface_branding:
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
    # limine-snapper-sync finds this entry by the machine's id
    $snapshots && echo "    comment: machine-id=$(cat /etc/machine-id)"
    local k
    for k in "${found[@]}"; do
        cat <<EOF
//$k
    protocol: linux
    kernel_path: boot():/${kernels#"$esp"/}/vmlinuz-$k
    module_path: boot():/${kernels#"$esp"/}/initramfs-$k.img
    kernel_cmdline: $cmdline
EOF
    done
    # where limine-snapper-sync puts an entry per snapshot
    $snapshots && echo "//Snapshots"
    return 0
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
printf '%s\n' "$conf" >"$esp/limine.conf"
# Limine reads the one next to its EFI file first: none there, so it reads /efi/limine.conf
rm -f "$esp/EFI/limine/limine.conf"
if $snapshots; then
    limine-snapper-sync >/dev/null 2>&1 && echo "Snapshot entries added (limine-snapper-sync)" ||
        echo "limine-snapper-sync couldn't add the snapshot entries; they come with the next snapshot" >&2
fi

# A firmware boot entry, first in the boot order, made once
if ! efibootmgr | grep -q '\\EFI\\limine\\BOOTX64.EFI'; then
    part=$(findmnt -no SOURCE "$esp")
    efibootmgr --create --disk "/dev/$(lsblk -no PKNAME "$part")" \
        --part "$(<"/sys/class/block/${part#/dev/}/partition")" \
        --label "Limine" --loader '\EFI\limine\BOOTX64.EFI' --unicode >/dev/null
    echo "Added the Limine boot entry, first in the boot order"
fi
echo "Installed. Limine shows at the next boot."
