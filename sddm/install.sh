#!/usr/bin/env bash
# Installs the login screen. SDDM reads from root-owned places, which stow can't manage.
#
#   sudo sddm/install.sh     install or update; the previous config goes to *.bak
#
# /var/lib/kuvk-shell is yours to write and readable by the greeter, which can't read your
# home folder: theme-set.py keeps theme.conf there, wallpaper.py the wallpaper, and
# hypr-monitors.py each monitor's scale.
set -euo pipefail

if ((EUID != 0)) || [[ -z ${SUDO_USER:-} || $SUDO_USER == root ]]; then
    echo "Run through sudo from your own account: sudo $0" >&2
    exit 1
fi

here=$(dirname "$(readlink -f "$0")")
home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
shared=/var/lib/kuvk-shell
theme=/usr/share/sddm/themes/kuvk

install -d -m 0755 -o "$SUDO_USER" "$shared"

rm -rf /usr/share/sddm/themes/kuvk-shell
install -d -m 0755 "$theme"
install -m 0644 "$here"/kuvk/* "$theme"/
ln -sfn "$shared/theme.conf" "$theme/theme.conf.user"

install -d -m 0755 /usr/share/sddm/hypr
[[ -f /usr/share/sddm/hypr/hyprland.lua ]] && cp -n /usr/share/sddm/hypr/hyprland.lua /usr/share/sddm/hypr/hyprland.lua.bak
install -m 0644 "$here/hyprland.lua" /usr/share/sddm/hypr/hyprland.lua

[[ -f /etc/sddm.conf ]] && cp -n /etc/sddm.conf /etc/sddm.conf.bak
install -m 0644 "$here/sddm.conf" /etc/sddm.conf
# KDE's settings module wrote this; it would override the theme chosen above
[[ -f /etc/sddm.conf.d/kde_settings.conf ]] && mv /etc/sddm.conf.d/kde_settings.conf /etc/sddm.conf.d/kde_settings.conf.bak

[[ -f $home/.face ]] && install -m 0644 "$home/.face" "/usr/share/sddm/faces/$SUDO_USER.face.icon"

cat <<MSG
Installed. It takes effect at your next logout. Now run these without sudo, from your session:

  ~/.config/scripts/theme-set.py
  ~/.config/scripts/wallpaper.py export-greeter
  ~/.config/scripts/hypr-monitors.py export-greeter

MSG
