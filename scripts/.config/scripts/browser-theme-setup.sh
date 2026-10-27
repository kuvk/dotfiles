#!/usr/bin/env bash
# One-time setup so theme-set.py can color Chromium and Brave (Settings >
# Appearance > Theme must be "Classic"). Same approach as Omarchy: the color
# goes into the browsers' managed policy (BrowserThemeColor). Those folders
# belong to root, so this installs a small root-owned helper that only accepts
# a 6-digit hex color, and a sudoers rule that lets you run exactly that
# without a password. Nothing else gets root.
#
#   sudo ~/.config/scripts/browser-theme-setup.sh            install
#   sudo ~/.config/scripts/browser-theme-setup.sh --unlock   drop the color policy for
#        now, e.g. to switch Appearance > Theme to Classic; the next theme
#        switch (or theme-set.py) puts it back
#   sudo ~/.config/scripts/browser-theme-setup.sh --remove   undo everything
set -euo pipefail

HELPER=/usr/local/bin/browser-theme-policy
SUDOERS=/etc/sudoers.d/browser-theme-policy
POLICY_DIRS=(/etc/chromium/policies/managed /etc/brave/policies/managed)

if ((EUID != 0)); then
    echo "Run with sudo: sudo $0 ${*:-}" >&2
    exit 1
fi

user="${SUDO_USER:-}"
if [[ -z $user || $user == root ]]; then
    echo "Run through sudo from your own account, so the rule is for your user." >&2
    exit 1
fi

if [[ ${1:-} == --unlock ]]; then
    for dir in "${POLICY_DIRS[@]}"; do rm -f "$dir/color.json"; done
    cat <<'MSG'
Theme policy removed. Now:
  1. Restart the browser (close every window).
  2. Settings > Appearance > Theme: choose "Classic" (not GTK or QT).
  3. Close the browser, then run ~/.config/scripts/theme-set.py to color it again.
MSG
    exit 0
fi

if [[ ${1:-} == --remove ]]; then
    rm -f "$HELPER" "$SUDOERS"
    for dir in "${POLICY_DIRS[@]}"; do rm -f "$dir/color.json"; done
    echo "Removed. Restart the browsers to drop the theme color."
    exit 0
fi

install -d -m 0755 "${POLICY_DIRS[@]}"

cat >"$HELPER" <<'HELPER_EOF'
#!/bin/bash
# Writes the browser theme color policy. Only accepts six lowercase hex digits.
set -euo pipefail
export PATH=/usr/bin:/bin
color="${1:-}"
[[ $color =~ ^[0-9a-f]{6}$ ]] || { echo "usage: browser-theme-policy rrggbb" >&2; exit 1; }
for dir in /etc/chromium/policies/managed /etc/brave/policies/managed; do
    [[ -d $dir && ! -L $dir ]] || continue
    tmp=$(mktemp)
    printf '{"BrowserThemeColor": "#%s", "BrowserColorScheme": "device"}\n' "$color" >"$tmp"
    install -m 0644 -o root -g root -T "$tmp" "$dir/color.json"
    rm -f "$tmp"
done
HELPER_EOF
chown root:root "$HELPER"
chmod 0755 "$HELPER"

rule="$user ALL=(root) NOPASSWD: $HELPER [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]"
tmp=$(mktemp)
printf '# Lets theme-set.py write the browser theme color (browser-theme-setup.sh)\n%s\n' "$rule" >"$tmp"
if visudo -cf "$tmp" >/dev/null; then
    install -m 0440 -o root -g root -T "$tmp" "$SUDOERS"
    rm -f "$tmp"
else
    rm -f "$tmp"
    echo "visudo rejected the rule; nothing installed." >&2
    exit 1
fi

echo "Done. Switch theme once (or run ~/.config/scripts/theme-set.py) to apply the color."
