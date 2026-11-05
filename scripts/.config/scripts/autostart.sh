#!/bin/bash

# # OBS
# if command -v obs >/dev/null; then
#     obs --minimize-to-tray &
# fi

# # RGB
# if command -v openrgb >/dev/null; then
#     openrgb --startminimized -p vuk &
# fi

# ROG Control Center
if command -v rog-control-center >/dev/null; then
    sleep 10 && rog-control-center &
fi

# GTK header bars without window buttons (ALT+Q closes windows): the GNOME
# setting for native Wayland GTK apps, settings.ini for XWayland ones (only
# that line is touched)
gsettings set org.gnome.desktop.wm.preferences button-layout ':' 2>/dev/null
for ini in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    mkdir -p "$(dirname "$ini")"
    if [[ ! -f $ini ]]; then
        printf '[Settings]\ngtk-decoration-layout=:\n' >"$ini"
    elif grep -q '^gtk-decoration-layout=' "$ini"; then
        sed -i 's/^gtk-decoration-layout=.*/gtk-decoration-layout=:/' "$ini"
    elif grep -q '^\[Settings\]' "$ini"; then
        sed -i '/^\[Settings\]/a gtk-decoration-layout=:' "$ini"
    else
        printf '\n[Settings]\ngtk-decoration-layout=:\n' >>"$ini"
    fi
done

exit 0
