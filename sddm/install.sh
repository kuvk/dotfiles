#!/usr/bin/env bash
# Installs the login screen. SDDM reads from root-owned places, which stow can't manage.
#
#   sudo sddm/install.sh                  install or update: Hyprdori's settings in
#                                         /etc/sddm.conf.d/hyprdori.conf, local ones in /etc/sddm.conf
#                                         (read last; options to uncomment); other settings
#                                         files set aside in /etc/sddm.hyprdori-backup/<date>/
#   sudo sddm/install.sh --autologin      also log in to Hyprland without the login screen (after
#                                         the disk password, with encrypted drives)
#   sudo sddm/install.sh --no-autologin   the login screen again
#
# /var/lib/hyprdori is the user's to write and readable by the greeter, which can't read the
# home folder: hyprdori-theme-set keeps theme.conf there, hyprdori-wallpaper the lock screen's background, and
# hyprdori-monitors each monitor's scale.
set -euo pipefail

if ((EUID != 0)) || [[ -z ${SUDO_USER:-} || $SUDO_USER == root ]]; then
    echo "Run through sudo from your own account: sudo $0" >&2
    exit 1
fi

autologin=
case ${1:-} in
    --autologin) autologin=on ;;
    --no-autologin) autologin=off ;;
    "") ;;
    *) echo "usage: sudo $0 [--autologin | --no-autologin]" >&2; exit 1 ;;
esac

here=$(dirname "$(readlink -f "$0")")
home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
shared=/var/lib/hyprdori
theme=/usr/share/sddm/themes/hyprdori

install -d -m 0755 -o "$SUDO_USER" "$shared"

install -d -m 0755 "$theme"
install -m 0644 "$here"/hyprdori/* "$theme"/
ln -sfn "$shared/theme.conf" "$theme/theme.conf.user"

install -d -m 0755 /usr/share/sddm/hypr
[[ -f /usr/share/sddm/hypr/hyprland.lua ]] && cp -n /usr/share/sddm/hypr/hyprland.lua /usr/share/sddm/hypr/hyprland.lua.bak
install -m 0644 "$here/hyprland.lua" /usr/share/sddm/hypr/hyprland.lua
# the blank cursor it starts with (the session's, hypr/.config/hypr/cursors)
install -D -m 0644 "$here/../hypr/.config/hypr/cursors/hyprdori-startup/index.theme" /usr/share/sddm/hypr/cursors/hyprdori-startup/index.theme
install -D -m 0644 "$here/../hypr/.config/hypr/cursors/hyprdori-startup/cursors/left_ptr" /usr/share/sddm/hypr/cursors/hyprdori-startup/cursors/left_ptr

# SDDM's settings: Hyprdori's in /etc/sddm.conf.d (hyprdori.conf, and autologin.conf when on);
# local ones in /etc/sddm.conf, which SDDM reads last, so what's set there wins (it starts as a
# list of options to uncomment). Anything else in sddm.conf.d (another desktop's settings: SDDM
# reads every file there, a .bak too, and a later one can undo autologin or the theme) and an
# /etc/sddm.conf not written here move to /etc/sddm.hyprdori-backup/<date>/, out of SDDM's way.
backup=/etc/sddm.hyprdori-backup/$(date +%Y%m%d-%H%M%S)
set_aside() {
    install -d -m 0755 "$backup"
    mv "$1" "$backup/"
    echo "Moved $1 to $backup/"
}
install -d -m 0755 /etc/sddm.conf.d
shopt -s nullglob dotglob
for file in /etc/sddm.conf.d/*; do
    case ${file##*/} in
        hyprdori.conf | autologin.conf) ;;
        *) set_aside "$file" ;;
    esac
done
shopt -u nullglob dotglob
install -m 0644 "$here/hyprdori.conf" /etc/sddm.conf.d/hyprdori.conf
# The local file: written once (also over the /etc/sddm.conf Hyprdori used to install, which hyprdori.conf
# now holds), then left as edited
if [[ -f /etc/sddm.conf ]] && ! grep -qE '^# (Local|Your own) SDDM settings' /etc/sddm.conf &&
    ! grep -q '^# /etc/sddm.conf, installed by sddm/install.sh' /etc/sddm.conf; then
    set_aside /etc/sddm.conf
fi
grep -qsE '^# (Local|Your own) SDDM settings' /etc/sddm.conf || install -m 0644 "$here/sddm.conf" /etc/sddm.conf

[[ -f $home/.face ]] && install -m 0644 "$home/.face" "/usr/share/sddm/faces/$SUDO_USER.face.icon"

# Autologin: straight into Hyprland as this user; left as it is without either option
if [[ $autologin == on ]]; then
    install -d -m 0755 /etc/sddm.conf.d
    printf '[Autologin]\nUser=%s\nSession=hyprland.desktop\n' "$SUDO_USER" >/etc/sddm.conf.d/autologin.conf
elif [[ $autologin == off ]]; then
    rm -f /etc/sddm.conf.d/autologin.conf
fi

# Its colors, background and monitor layout follow on their own: hyprdori-theme-set,
# hyprdori-wallpaper and hyprdori-monitors write them into /var/lib/hyprdori as they change
echo "Installed. It takes effect at your next logout."

