#!/usr/bin/env bash
# Sets up Hyprdori on a fresh Arch install. Run it as the user, not root (it asks for sudo) after
# the first boot, from a console or any session, with the network up:
#
#   git clone https://github.com/kuvk/hyprdori ~/hyprdori && ~/hyprdori/install.sh
#
# Expects what the Arch install leaves: base, linux-firmware, microcode, a user with sudo,
# the ESP mounted at /efi, and for encrypted drives the systemd initramfs (the systemd and
# sd-encrypt hooks, rd.luks.name= in the kernel options). Safe to run again: each step skips
# what's already done.
#
# Steps: pacman.conf (multilib, the g14 repo on ASUS laptops), mirrors (reflector), config links
# (stow; files in the way go to ~/.hyprdori-backup), packages (packages/*.txt by detected
# hardware, packages/guest.txt in a virtual machine), Flatpak, services, zsh and its plugins,
# the theme, snapshots on a btrfs root (snapper, limine-snapper-sync), then boot:
# initramfs and kernel options, Plymouth, Limine. The login screen (SDDM) comes with the theme, or autologin if chosen (the
# default with encrypted drives).
set -euo pipefail

hyprdori=$(dirname "$(readlink -f "$0")")
# Not stowed; hyprdori-update's Links step has the same list (hyprdori-check compares them)
not_stowed=(limine migrations packages plymouth sddm)

step() { printf '\n\e[1;34m==> %s\e[0m\n' "$1"; }
note() { printf '\e[33m%s\e[0m\n' "$1"; }
# ask "question" y|n: the default is what Enter picks
ask() {
    local answer hint="[y/N]"
    [[ $2 == y ]] && hint="[Y/n]"
    read -r -p "$1 $hint " answer </dev/tty
    [[ ${answer:-$2} =~ ^[yY] ]]
}
# Package names from a list: comments and blank lines dropped
list() { sed 's/#.*//; s/[[:space:]]//g; /^$/d' "$hyprdori/packages/$1.txt"; }
# Where an extra package (~/.config/hyprdori/user_pkg.txt) comes from: the repos (pacman's, or
# archlinux.org's for a repo not enabled yet, such as multilib), the AUR or Flathub; nothing
# printed when it's in none of them (or the lookup can't be made). Flathub IDs (two dots or more)
# are tried there first.
source_of() {
    local name=$1
    on_flathub() { [[ $(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://flathub.org/api/v2/appstream/$name") == 200 ]]; }
    if [[ $name =~ ^[A-Za-z][A-Za-z0-9_-]*(\.[A-Za-z0-9_-]+){2,}$ ]] && on_flathub; then
        echo flatpak
    elif pacman -Si -- "$name" &>/dev/null ||
        curl -fsS --max-time 10 --get --data-urlencode "name=$name" https://archlinux.org/packages/search/json/ 2>/dev/null |
        grep -qF "\"pkgname\": \"$name\""; then
        echo repo
    elif curl -fsS --max-time 10 --get --data-urlencode "arg[]=$name" https://aur.archlinux.org/rpc/v5/info 2>/dev/null |
        grep -q '"resultcount":[1-9]'; then
        echo aur
    elif on_flathub; then
        echo flatpak
    fi
    return 0
}

# --- Checks -------------------------------------------------------------------------------------
((EUID != 0)) || { echo "Run this as yourself, not root: it asks for sudo when needed." >&2; exit 1; }
[[ -f /etc/arch-release ]] || { echo "This is for Arch Linux." >&2; exit 1; }
curl -fsI --max-time 10 https://archlinux.org >/dev/null || { echo "No internet connection." >&2; exit 1; }
# the password once: sudo keeps it until the install ends, however long the downloads take
"$hyprdori/bin/.local/bin/hyprdori-sudo-hold" $$ || { echo "No password, nothing installed." >&2; exit 1; }

# --- Hardware -----------------------------------------------------------------------------------
gpus=() boot_gpu= boot_driver=
for dev in /sys/bus/pci/devices/*; do
    [[ $(cat "$dev/class") == 0x03* ]] || continue
    vendor=$(cat "$dev/vendor")
    gpus+=("$vendor")
    if [[ $(cat "$dev/boot_vga" 2>/dev/null) == 1 ]]; then
        boot_gpu=$vendor
        [[ -e $dev/driver ]] && boot_driver=$(basename "$(readlink "$dev/driver")")
    fi
done
has_gpu() { [[ " ${gpus[*]} " == *" $1 "* ]]; }
vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
chassis=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo 0)
laptop=false asus_laptop=false
[[ " 8 9 10 14 31 32 " == *" $chassis "* ]] && laptop=true
$laptop && [[ $vendor == ASUSTeK* ]] && asus_laptop=true
# Inside a virtual machine (a test install): its GPU's Vulkan and the guest agent, and no for
# the questions about real hardware and running VMs
guest=false
systemd-detect-virt --vm --quiet 2>/dev/null && guest=true

groups=(core)
$guest && groups+=(guest)
has_gpu 0x10de && groups+=(nvidia)
has_gpu 0x8086 && groups+=(intel)
has_gpu 0x1002 && groups+=(amd)
# NVIDIA next to another GPU in a laptop: prime-run
$laptop && has_gpu 0x10de && ((${#gpus[@]} >= 2)) && groups+=(hybrid)
# Both asked on every machine, as not every laptop or desktop needs them; what the hardware
# suggests is the default
if ask "ASUS laptop: the g14 repo, asusctl and ROG Control Center (packages/laptop.txt)?" "$($asus_laptop && echo y || echo n)"; then
    groups+=(laptop)
fi
if ask "Desktop PC: fan, pump and RGB control: CoolerControl, liquidctl, OpenRGB (packages/desktop.txt)?" "$($laptop || $guest && echo n || echo y)"; then
    groups+=(desktop)
fi
ask "Apps with window rules (packages/apps.txt)?" y && groups+=(apps)
if ask "Virtual machines and Docker (packages/vm.txt)?" "$($guest && echo n || echo y)"; then
    groups+=(vm)
    has_gpu 0x10de && groups+=(nvidia-docker)
fi
flatpak=false
ask "Flatpak apps (packages/flatpak.txt)?" y && flatpak=true
# The browsers' own text (tabs, address bar, menus): the font everything else uses, or always the
# display font, so a later Monospace everywhere (Settings > Fonts) leaves them alone, a monospace
# font being wide there. hyprdori-browser-theme-setup --follow-font true|false changes it later.
browser_font=true
ask "Browsers: should their tabs, address bar and menus follow the font everything else uses (also monospace, if you turn that on)?" y ||
browser_font=false
# A btrfs root laid out as the install guide's (@ and @snapshots): snapshots, also in the boot menu
snapshots=false
if [[ $(findmnt -no FSTYPE /) == btrfs ]] &&
ask "Snapshots: before and after every update, bootable from the boot menu (packages/snapshots.txt)?" y; then
    snapshots=true
    groups+=(snapshots)
fi
# With encrypted drives the disk password already guards the machine, so autologin is the default
encrypted=n
grep -qE '^HOOKS=.*\b(sd-)?encrypt\b' /etc/mkinitcpio.conf 2>/dev/null && encrypted=y
autologin=--no-autologin
if ask "Log in automatically, without the login screen (autologin)?" "$encrypted"; then
    autologin=--autologin
    note "Autologin: the disk password is the only one at boot; your account's password still unlocks the
lock screen and sudo. The keyring (saved browser and app passwords) isn't unlocked by a login: the
first app to use it asks for a keyring password, then every boot. Left empty, it never asks (the
encrypted disk still protects it)."
fi

# Extra packages (~/.config/hyprdori/user_pkg.txt), with Hyprdori's: each looked up first. One found
# nowhere leaves the whole list out, so a misspelled name never installs part of it; one already
# in a chosen list is reported and installed once, with that list
user_native=() user_flatpak=()
# The list is this machine's, outside the repo; missing, it's made with these notes and nothing
# to install, to fill in for a later run
user_pkg_file=${XDG_CONFIG_HOME:-$HOME/.config}/hyprdori/user_pkg.txt
if [[ ! -e $user_pkg_file ]]; then
    mkdir -p "${user_pkg_file%/*}"
    cat >"$user_pkg_file" <<'EOF'
# Extra packages that Hyprdori's install.sh offers to install with its own lists, on this machine
# only (the file stays out of the repo). One per line: a package from the Arch repos, an AUR
# package, or a Flathub app ID (com.example.App). Text after # and blank lines are skipped.
#
# Each entry is looked up before the question (the installed repos, archlinux.org, the AUR,
# Flathub). An entry found in none of them leaves the whole list out, so a misspelled name never
# installs part of it. An entry already in a chosen Hyprdori list is reported and installed once,
# with that list. A package only in a repo outside Arch's (g14, a custom one) is found only once
# that repo is in pacman.conf, which on a first install happens after this check.
EOF
fi
user_pkgs=()
mapfile -t user_pkgs < <(sed 's/#.*//; s/[[:space:]]//g; /^$/d' "$user_pkg_file")
if ((${#user_pkgs[@]})) && ask "Extra packages (~/.config/hyprdori/user_pkg.txt: ${#user_pkgs[@]})?" y; then
    echo "Looking them up in the repos, the AUR and Flathub..."
    chosen=("${groups[@]}")
    $flatpak && chosen+=(flatpak)
    unknown=() found_native=() found_flatpak=()
    for pkg in "${user_pkgs[@]}"; do
        lists=()
        for group in "${chosen[@]}"; do
            grep -qxF -- "$pkg" < <(list "$group") && lists+=("packages/$group.txt")
        done
        if ((${#lists[@]})); then
            note "$pkg is already in ${lists[*]}: installed with it"
            continue
        fi
        case $(source_of "$pkg") in
            repo) found_native+=("$pkg"); echo "  $pkg: repos" ;;
            aur) found_native+=("$pkg"); echo "  $pkg: AUR" ;;
            flatpak) found_flatpak+=("$pkg"); echo "  $pkg: Flathub" ;;
            *) unknown+=("$pkg") ;;
        esac
    done
    if ((${#unknown[@]})); then
        note "Not in the repos, the AUR or Flathub (or the lookup failed): ${unknown[*]}.
~/.config/hyprdori/user_pkg.txt is left out; correct it and run install.sh again, or install them by hand."
    else
        user_native=("${found_native[@]}") user_flatpak=("${found_flatpak[@]}")
    fi
fi

echo
echo "Package lists: ${groups[*]}$($flatpak && echo ", flatpak")$(((${#user_native[@]} + ${#user_flatpak[@]})) && echo ", extra ($((${#user_native[@]} + ${#user_flatpak[@]})))")$([[ $autologin == --autologin ]] && echo "; autologin")"
ask "Continue?" y || exit 0

# --- pacman.conf ----------------------------------------------------------------------------------
step "pacman.conf"
conf=/etc/pacman.conf
sudo cp -n "$conf" "$conf.bak"
# multilib (Steam, lib32 drivers), colors, parallel downloads
sudo sed -i -e '/^#\[multilib\]$/,/^#Include/ s/^#//' \
    -e 's/^#Color$/Color/' -e 's/^#ParallelDownloads.*/ParallelDownloads = 5/' "$conf"
if [[ " ${groups[*]} " == *" laptop "* ]] && ! grep -q '^\[g14\]' "$conf"; then
    # Signing keys from asus-linux.org/guides/arch-guide
    for key in 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35 F79100EF8C802DAB81C323BB8EEA5962FE510E19; do
        sudo pacman-key --recv-keys "$key" || sudo pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys "$key"
        sudo pacman-key --lsign-key "$key"
    done
    printf '\n[g14]\nServer = https://arch.asus-linux.org\n' | sudo tee -a "$conf" >/dev/null
fi
echo "Done (the old one is $conf.bak)."

# --- Mirrors ----------------------------------------------------------------------------------------
step "Mirrors"
sudo pacman -Syu --needed --noconfirm reflector
if [[ ! -f /etc/pacman.d/mirrorlist.bak ]]; then
    sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
    sudo tee /etc/xdg/reflector/reflector.conf >/dev/null <<'EOF'
# reflector.timer runs this weekly (installed by install.sh)
--save /etc/pacman.d/mirrorlist
--protocol https
--latest 20
--sort rate
EOF
    echo "Ranking mirrors (about a minute)"
    sudo systemctl start reflector.service || note "reflector failed; keeping the old mirror list."
fi
sudo systemctl enable --now reflector.timer

# --- Links --------------------------------------------------------------------------------------------
step "Links"
sudo pacman -Syu --needed --noconfirm base-devel git stow
backup="$HOME/.hyprdori-backup/$(date +%F_%H-%M-%S)"
packages=()
for dir in "$hyprdori"/*/; do
    name=$(basename "$dir")
    [[ " ${not_stowed[*]} " == *" $name "* ]] || packages+=("$name")
done
# Files where a link should go, which aren't links into Hyprdori already, move aside
moved=0
for name in "${packages[@]}"; do
    while IFS= read -r -d '' file; do
        rel=${file#"$hyprdori/$name/"}
        target="$HOME/$rel"
        [[ -e $target || -L $target ]] || continue
        [[ $(readlink -f "$target") == "$file" ]] && continue
        mkdir -p "$backup/$(dirname "$rel")"
        mv "$target" "$backup/$rel"
        moved=$((moved + 1))
    done < <(find "$hyprdori/$name" \( -type f -o -type l \) -print0)
done
((moved)) && note "Moved $moved file(s) that were in the way to $backup"
# Folders apps write into themselves made real first, so stow links the files in them rather
# than the whole folder (systemd keeps its timers' state next to the user units)
mkdir -p "$HOME/.local/share/systemd/user"
stow -d "$hyprdori" -t "$HOME" --restow "${packages[@]}"
echo "Linked: ${packages[*]}"
# A fresh install has nothing to migrate: hyprdori-update runs only migrations added later
"$hyprdori/bin/.local/bin/hyprdori-migrate" --mark-done

# --- Packages -------------------------------------------------------------------------------------------
step "Packages"
if ! command -v paru >/dev/null; then
    echo "Building paru from the AUR"
    build=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/paru.git "$build/paru"
    (cd "$build/paru" && makepkg -si --needed --noconfirm)
    rm -rf "$build"
fi
mapfile -t wanted < <({
    for group in "${groups[@]}"; do list "$group"; done
    ((${#user_native[@]})) && printf '%s\n' "${user_native[@]}"
} | sort -u)
# paru installs repo and AUR packages alike, and asks once. When that fails (an AUR package
# that doesn't build), the rest go one at a time and the failures are listed: the install goes on
if ! paru -Syu --needed "${wanted[@]}"; then
    note "Not everything installed; trying the missing packages one at a time"
    failed=()
    for pkg in "${wanted[@]}"; do
        pacman -Q "$pkg" &>/dev/null && continue
        paru -S --needed --noconfirm "$pkg" || failed+=("$pkg")
    done
    if ((${#failed[@]})); then
        note "Not installed: ${failed[*]}. The rest of the install goes on; try them later with paru -S."
    fi
fi

# Hyprdori's Flatpak apps if chosen, and the extra ones from ~/.config/hyprdori/user_pkg.txt
if $flatpak || ((${#user_flatpak[@]})); then
    step "Flatpak"
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    apps=()
    $flatpak && mapfile -t apps < <(list flatpak)
    apps+=("${user_flatpak[@]}")
    sudo flatpak install -y --noninteractive flathub "${apps[@]}"
fi

# --- Services, shell, theme -------------------------------------------------------------------------------
step "Services"
services=(NetworkManager bluetooth power-profiles-daemon sddm fstrim.timer)
if [[ " ${groups[*]} " == *" nvidia "* ]]; then
    services+=(nvidia-suspend nvidia-hibernate nvidia-resume)
    $laptop && services+=(nvidia-powerd)
fi
[[ " ${groups[*]} " == *" desktop "* ]] && services+=(coolercontrold)
$guest && services+=(qemu-guest-agent)
vm=false
[[ " ${groups[*]} " == *" vm "* ]] && vm=true && services+=(libvirtd docker.socket)
for unit in "${services[@]}"; do
    if sudo systemctl enable "$unit" &>/dev/null; then echo "Enabled $unit"; else note "Couldn't enable $unit"; fi
done
# Per user: the weekly update check (Saturdays; a notification when updates wait), linked from bin
systemctl --user daemon-reload
if systemctl --user enable --now hyprdori-update-check.timer &>/dev/null; then
    echo "Enabled the weekly update check"
else
    note "Couldn't enable the weekly update check (systemctl --user enable --now hyprdori-update-check.timer)"
fi
# The lock screen gets up to 15 s, not logind's 5, to come up before a suspend
# (hyprdori-sleep-lock). logind reads it on reload.
sudo install -Dm644 /dev/stdin /etc/systemd/logind.conf.d/20-inhibit-delay.conf <<'EOF'
[Login]
InhibitDelayMaxSec=15
EOF
sudo systemctl reload systemd-logind || note "Couldn't reload logind; the longer lock delay applies after a reboot"
if $vm; then
    # VMs without a password prompt, and libvirt's NAT network up on every boot
    sudo usermod -aG libvirt "$USER"
    sudo systemctl start libvirtd
    sudo virsh net-autostart default >/dev/null && echo "libvirt's default network starts on boot" \
        || note "Couldn't set libvirt's default network to start on boot"
fi

step "Shell"
if [[ $(getent passwd "$USER" | cut -d: -f7) != /usr/bin/zsh ]]; then
    sudo chsh -s /usr/bin/zsh "$USER"
else
    echo "Already zsh."
fi
# zsh's plugins (vi mode, highlighting, suggestions, completions, history search)
"$HOME/.local/bin/hyprdori-zsh-plugins"
# yazi's plugins from its package list (yazi/.config/yazi/package.toml: full-border, at the
# version it names)
command -v ya >/dev/null && { ya pkg install >/dev/null || note "Couldn't install yazi's plugins (ya pkg install)"; }
# herdr's Ctrl+H/J/K/L across its panes and Neovim's splits (herdr/.config/herdr/config.toml)
if command -v herdr >/dev/null && ! herdr plugin list 2>/dev/null | grep -q vim-herdr-navigation; then
    herdr plugin install --yes paulbkim-dev/vim-herdr-navigation >/dev/null || note "Couldn't install herdr's navigation plugin"
fi

step "Theme"
# The login screen first: hyprdori-theme-set writes its colors to the folder this makes
sudo "$hyprdori/sddm/install.sh" "$autologin" >/dev/null
# tmux's theme plugin (.tmux.conf would clone it on first start), so hyprdori-theme-set can write
# the theme's colors into it now
tmux_theme="$HOME/.tmux/plugins/catppuccin/tmux"
[[ -d $tmux_theme ]] || git clone -q -b v2.3.2 https://github.com/catppuccin/tmux.git "$tmux_theme"
# The browsers' color policy helper, so the theme below colors Chromium and Brave too
sudo "$HOME/.local/bin/hyprdori-browser-theme-setup" >/dev/null
# and the browsers' font, as answered above (no sudo: a per-user setting)
"$HOME/.local/bin/hyprdori-browser-theme-setup" --follow-font "$browser_font" >/dev/null
"$HOME/.local/bin/hyprdori-theme-set"
# Backgrounds: ~/.local/share/hyprdori/backgrounds/default (wallpapers) and /live, and
# ~/.config/hyprdori/backgrounds.json for more folders. The desktop, lock screen and login
# screen get the theme's background, which hyprdori-theme-set just drew (the logo in magenta on
# the dark background), unless a wallpaper is chosen already. Both follow
# the theme from then on.
wall=$(jq -r '.background // empty' "$HOME/.config/theme/current/quickshell.json" 2>/dev/null) || wall=
"$HOME/.local/bin/hyprdori-wallpaper" default ${wall:+"$wall"}

# --- Snapshots: snapper on @snapshots, limine-snapper-sync, read-only snapshots with an overlay -------------
if $snapshots && command -v snapper >/dev/null; then
    step "Snapshots"
    # snapper's config for /, its snapshots in @snapshots (mounted at /.snapshots by fstab) rather
    # than the subvolume snapper makes itself
    if ! sudo snapper list-configs 2>/dev/null | grep -q '^root '; then
        mountpoint -q /.snapshots && sudo umount /.snapshots
        sudo rmdir /.snapshots 2>/dev/null || true
        sudo snapper -c root create-config /
        # fstab mounts @snapshots there (the install guide): snapper's own subvolume makes way
        if findmnt --fstab /.snapshots >/dev/null; then
            sudo btrfs subvolume delete /.snapshots >/dev/null
            sudo mkdir /.snapshots
            sudo mount -a
            echo "snapper's root config, snapshots in @snapshots"
        else
            echo "snapper's root config, snapshots in its own /.snapshots subvolume"
        fi
    fi
    sudo chmod 750 /.snapshots
    # Only the update snapshots: one before every hyprdori-update, the newest 5 kept, cleaned up
    # at once (no minimum age); no hourly timeline, so the boot menu's Snapshots stay short. Only
    # /: /home holds the user's work, never rolled back
    sudo snapper -c root set-config TIMELINE_CREATE=no NUMBER_LIMIT=5 NUMBER_LIMIT_IMPORTANT=5 NUMBER_MIN_AGE=0
    sudo systemctl enable --now snapper-cleanup.timer
    # The boot menu's snapshots: their entries in /efi/limine.conf (limine/install.sh adds the
    # place), booted read-only with a throwaway layer on top (systemd.volatile=overlay: the
    # initramfs gets systemd's volatile-root service, which the systemd hook leaves out, and the
    # overlay module), restored with limine-snapper-restore
    if command -v limine-snapper-sync >/dev/null; then
        sudo tee /etc/default/limine >/dev/null <<CONF
# limine-snapper-sync, written by Hyprdori's install.sh
ESP_PATH="/efi"
TARGET_OS_NAME="Arch Linux"
SNAPPER_CONFIG_NAME="root"
LIMIT_USAGE_PERCENT=85
MAX_SNAPSHOT_ENTRIES=auto
SNAPSHOT_KERNEL_PARAMETERS+=systemd.volatile=overlay
SNAPSHOT_WRITABLE=no
RESTORE_METHOD=replace
SNAPSHOT_FORMAT_CHOICE=2
TERMINAL=kitty
TERMINAL_ARG="-e"
CONF
        sudo install -d /etc/mkinitcpio.conf.d
        sudo tee /etc/mkinitcpio.conf.d/snapshots.conf >/dev/null <<'CONF'
# Booting a read-only snapshot with a throwaway layer (systemd.volatile=overlay, install.sh)
MODULES+=(overlay)
BINARIES+=(/usr/lib/systemd/systemd-volatile-root)
FILES+=(/usr/lib/systemd/system/systemd-volatile-root.service)
CONF
        sudo systemctl enable limine-snapper-sync.service
        echo "Snapshots in the boot menu (/etc/default/limine, /etc/mkinitcpio.conf.d/snapshots.conf)"
    else
        note "limine-snapper-sync isn't installed: snapshots are taken, but not in the boot menu."
    fi
    # Copy-on-write off where VM disks and Docker's data go (files made after this)
    sudo install -d /var/lib/libvirt/images /var/lib/docker
    sudo chattr +C /var/lib/libvirt/images /var/lib/docker
fi

# --- Boot: initramfs, kernel options, splash, menu -------------------------------------------------------------
step "Boot"
boot=true
if ! mountpoint -q /efi; then
    note "The ESP isn't mounted at /efi; skipping Plymouth and Limine."
    boot=false
elif ! grep -qE '^HOOKS=\(.*\bsystemd\b' /etc/mkinitcpio.conf; then
    note "The initramfs doesn't use the systemd hook (needed for the splash's password field); skipping Plymouth and Limine."
    boot=false
fi

if $boot; then
    # Kernels and images on the ESP, where Limine can read them (it reads only FAT)
    sudo install -d /efi/arch
    for preset in /etc/mkinitcpio.d/*.preset; do
        kernel=$(basename "$preset" .preset)
        grep -q '^ALL_kver="/efi/arch/' "$preset" && continue
        sudo cp -n "$preset" "$preset.bak"
        sudo tee "$preset" >/dev/null <<EOF
# mkinitcpio preset for $kernel; the kernel and image go to the ESP (install.sh)
ALL_kver="/efi/arch/vmlinuz-$kernel"
PRESETS=('default')
default_image="/efi/arch/initramfs-$kernel.img"
EOF
        echo "$kernel: kernel and image now go to /efi/arch"
    done

    # GPU drivers in the initramfs, named rather than the kms hook's (every built-in driver,
    # but not NVIDIA's DKMS modules): the boot screen's GPU for the splash, and NVIDIA's on any
    # machine with an NVIDIA card, also a hybrid laptop. Loaded later, it can appear after the
    # login screen's Hyprland has started, which doesn't survive a new GPU. NVIDIA's firmware
    # makes the images about 150 MB each.
    mkinit=/etc/mkinitcpio.conf
    sudo cp -n "$mkinit" "$mkinit.bak"
    if grep -q '^MODULES=()' "$mkinit"; then
        case $boot_gpu in
            0x8086) modules=${boot_driver:-i915}; [[ $modules == xe ]] || modules=i915 ;;
            0x1002) modules=amdgpu ;;
            *) modules= ;;
        esac
        [[ -n $modules ]] && sudo sed -i "s/^MODULES=()/MODULES=($modules)/" "$mkinit" && echo "MODULES=($modules)"
    fi
    if has_gpu 0x10de; then
        sudo install -d /etc/mkinitcpio.conf.d
        echo 'MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)' | sudo tee /etc/mkinitcpio.conf.d/nvidia.conf >/dev/null
        echo "NVIDIA in the initramfs (/etc/mkinitcpio.conf.d/nvidia.conf)"
    fi
    if grep -qE '^MODULES=\(.+\)' "$mkinit" || [[ -f /etc/mkinitcpio.conf.d/nvidia.conf ]]; then
        sudo sed -i -E '/^HOOKS=/{s/ kms\b//}' "$mkinit"
    fi
    grep -qE '^HOOKS=.*\bplymouth\b' "$mkinit" || sudo sed -i -E '/^HOOKS=/s/\bsystemd\b/systemd plymouth/' "$mkinit"

    # Kernel options: the running system's, plus a quiet boot, plus the unlock limits that
    # luks-poweroff relies on (90 seconds or three tries, then power off)
    if [[ ! -s /etc/kernel/cmdline ]]; then
        sed -E 's/(^| )(BOOT_IMAGE|initrd)=[^ ]*//g; s/^ +//' /proc/cmdline | sudo tee /etc/kernel/cmdline >/dev/null
    fi
    cmdline=$(cat /etc/kernel/cmdline)
    # quiet boot and shutdown: no kernel or systemd status text, no console cursor
    extra=(quiet loglevel=3 splash systemd.show_status=false vt.global_cursor_default=0)
    if [[ $cmdline == *rd.luks.name=* ]]; then
        extra+=(rd.luks.options=timeout=90s,tries=3 systemd.default_device_timeout_sec=infinity)
    fi
    for option in "${extra[@]}"; do
        [[ " $cmdline " == *" ${option%%=*}="* || " $cmdline " == *" $option "* ]] || cmdline+=" $option"
    done
    echo "$cmdline" | sudo tee /etc/kernel/cmdline >/dev/null
    echo "Kernel options: $cmdline"

    # Plymouth builds the initramfs, Limine then finds the kernels in /efi/arch
    sudo "$hyprdori/plymouth/install.sh" --theme
    sudo "$hyprdori/limine/install.sh" --theme
fi

step "Done"
cat <<MSG
Reboot. The login screen gets your monitor layout by itself, at every login and monitor change.
$(command -v spotify-launcher >/dev/null && printf '\n%s\n' "Spotify follows the theme once you've opened it and logged in: at the next login after that
it's styled by itself (hyprdori-spicetify; or run that with Spotify closed).")

Backups of what this changed: /etc/pacman.conf.bak, /etc/mkinitcpio.conf.bak, the presets'
.bak files and /etc/pacman.d/mirrorlist.bak.
MSG
