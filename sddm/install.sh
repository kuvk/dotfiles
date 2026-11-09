#!/usr/bin/env bash
# Installs the login screen. SDDM reads from root-owned places, which stow can't manage.
#
#   sudo sddm/install.sh                  install or update; the previous config goes to *.bak
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

[[ -f /etc/sddm.conf ]] && cp -n /etc/sddm.conf /etc/sddm.conf.bak
install -m 0644 "$here/sddm.conf" /etc/sddm.conf
# KDE's settings module wrote this; it would override the theme chosen above
[[ -f /etc/sddm.conf.d/kde_settings.conf ]] && mv /etc/sddm.conf.d/kde_settings.conf /etc/sddm.conf.d/kde_settings.conf.bak

[[ -f $home/.face ]] && install -m 0644 "$home/.face" "/usr/share/sddm/faces/$SUDO_USER.face.icon"

# Autologin: straight into Hyprland as this user; left as it is without either option
if [[ $autologin == on ]]; then
    install -d -m 0755 /etc/sddm.conf.d
    printf '[Autologin]\nUser=%s\nSession=hyprland.desktop\n' "$SUDO_USER" >/etc/sddm.conf.d/autologin.conf
elif [[ $autologin == off ]]; then
    rm -f /etc/sddm.conf.d/autologin.conf
fi

cat <<MSG
Installed. It takes effect at your next logout. Now run these without sudo, from your session:

  ~/.local/bin/hyprdori-theme-set
  ~/.local/bin/hyprdori-wallpaper export-greeter
  ~/.local/bin/hyprdori-monitors export-greeter

MSG
