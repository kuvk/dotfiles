#!/usr/bin/env bash
# The boot splash (Plymouth) and boot menu (Limine) in the current theme: runs both
# installers with one password prompt. They read the theme and logo when they run, so a
# theme or accent change shows at boot only after this.
#
#   theme-boot.sh            update, unless they're already built from the current theme
#   theme-boot.sh --force    update anyway
#   theme-boot.sh --check    say whether an update is needed (exit 0 yes, 1 no); no root
#   theme-boot.sh --window   in a kitty window: the logo, what this does, a Y/n question, the
#                            output, then any key closes it (the notification's Update button)
#
# Asks for the password in a terminal (sudo) or, started from the desktop, in the polkit
# dialog (pkexec). Plymouth rebuilds every initramfs, which takes a while.
#
# What they were last built from is kept as a checksum in /var/lib/kuvk-shell/boot-theme:
# the theme's colors, the logo and the installers themselves.
set -euo pipefail

self=$(readlink -f "$0")
scripts=$(dirname "$self")
dotfiles=$(cd "$scripts/../../.." && pwd)
stamp=/var/lib/kuvk-shell/boot-theme

note() { printf '%s\n' "$1"; command -v notify-send >/dev/null && [[ ! -t 1 ]] && notify-send -a "Boot screens" "$1" 2>/dev/null; true; }

# Checksum of everything the two installers draw from (run as the user whose theme it is)
fingerprint() {
    local home=$1
    cat "$home/.config/theme/current/colors.sh" "$home/.config/theme/logo/ascii-dori" \
        "$dotfiles"/plymouth/* "$dotfiles/limine/install.sh" "$scripts/logo-render.py" 2>/dev/null |
        sha256sum | cut -d' ' -f1
}

# --- Root part: started by the user part below through sudo or pkexec ------------------------
if [[ ${1:-} == --as-root ]]; then
    user=${2:?user}
    home=$(getent passwd "$user" | cut -d: -f6)
    export SUDO_USER=$user
    "$dotfiles/plymouth/install.sh"
    # Limine with the options it was installed with (update.sh does the same)
    options=()
    if [[ -r /efi/EFI/limine/limine.conf ]]; then
        read -ra options <<<"$(sed -n 's/^# Options: //p' /efi/EFI/limine/limine.conf)"
    fi
    "$dotfiles/limine/install.sh" "${options[@]}"
    if [[ -d ${stamp%/*} ]]; then
        fingerprint "$home" >"$stamp"
        chown "$user" "$stamp"
    fi
    exit 0
fi

# --- In a window: the logo, what this does, a Y/n question, then the output ----------------------
if [[ ${1:-} == --window ]]; then
    exec kitty --class theme-boot --title "Boot screens" "$self" --in-window
fi
if [[ ${1:-} == --in-window ]]; then
    # The logo in accent2, from the current theme
    accent2="#cba6f7"
    # shellcheck source=/dev/null
    . "$HOME/.config/theme/current/colors.sh" 2>/dev/null
    color=$(printf '38;2;%d;%d;%d' "0x${accent2:1:2}" "0x${accent2:3:2}" "0x${accent2:5:2}")
    printf '\n\e[%sm' "$color"
    sed 's/^/  /' "$HOME/.config/theme/logo/ascii-dori" 2>/dev/null
    printf '\e[0m\n'
    cat <<'MSG'
  The boot menu (Limine) and boot splash (Plymouth) keep the colors they were installed
  with. This runs both installers again with the current theme, accents and logo, so the
  boot matches the desktop from the next start. It needs the sudo password and takes
  about a minute, as the splash is rebuilt into every initramfs.

MSG
    status=0
    read -rp "  Update the boot screens now? [Y/n] " answer
    if [[ ${answer:-y} =~ ^[yY] ]]; then
        echo
        "$self" || status=$?
    else
        echo "  Left as they are."
    fi
    printf '\n\e[2m  Press any key to close\e[0m'
    read -rsn1 _
    exit "$status"
fi

# --- User part -----------------------------------------------------------------------------------
((EUID != 0)) || { echo "Run this as yourself; it asks for the password itself." >&2; exit 1; }
current=$(fingerprint "$HOME")
installed=$(cat "$stamp" 2>/dev/null || true)

case ${1:-} in
    --check) [[ $current != "$installed" ]]; exit ;;
    --force | "") ;;
    *) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac

if [[ ${1:-} != --force && $current == "$installed" ]]; then
    note "The boot screens already use the current theme."
    exit 0
fi

if [[ -t 0 ]]; then
    sudo "$self" --as-root "$USER"
else
    pkexec "$self" --as-root "$USER"
fi && note "The boot screens use the current theme from the next boot." \
    || { note "The boot screens weren't updated."; exit 1; }
