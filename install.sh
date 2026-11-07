#!/usr/bin/env bash
# Sets up these dotfiles on a fresh Arch install. Run it as yourself (it asks for sudo) after
# the first boot, from a console or any session, with the network up:
#
#   git clone https://github.com/kuvk/dotfiles ~/dotfiles && ~/dotfiles/install.sh
#
# Expects what the Arch install leaves: base, linux-firmware, microcode, your user with sudo,
# the ESP mounted at /efi, and for encrypted drives the systemd initramfs (the systemd and
# sd-encrypt hooks, rd.luks.name= in the kernel options). Safe to run again: each step skips
# what's already done.
#
# Steps: pacman.conf (multilib, the g14 repo on ASUS laptops), mirrors (reflector), dotfiles
# (stow; files in the way go to ~/.dotfiles-backup), packages (packages/*.txt by detected
# hardware), Flatpak, services, zsh and its plugins, the theme, then boot: initramfs and kernel options,
# Plymouth, Limine. The login screen (SDDM) comes with the theme.
set -euo pipefail

dotfiles=$(dirname "$(readlink -f "$0")")
not_stowed=(limine packages plymouth sddm)

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
list() { sed 's/#.*//; s/[[:space:]]//g; /^$/d' "$dotfiles/packages/$1.txt"; }

# --- Checks -------------------------------------------------------------------------------------
((EUID != 0)) || { echo "Run this as yourself, not root: it asks for sudo when needed." >&2; exit 1; }
[[ -f /etc/arch-release ]] || { echo "This is for Arch Linux." >&2; exit 1; }
curl -fsI --max-time 10 https://archlinux.org >/dev/null || { echo "No internet connection." >&2; exit 1; }
sudo -v

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

groups=(core)
has_gpu 0x10de && groups+=(nvidia)
has_gpu 0x8086 && groups+=(intel)
if $asus_laptop && ask "ASUS laptop: add the g14 repo, its kernel and asusctl (packages/laptop.txt)?" y; then
    groups+=(laptop)
fi
if ! $laptop && ask "Desktop PC: fan and RGB control (packages/desktop.txt)?" y; then
    groups+=(desktop)
fi
ask "Apps with window rules (packages/apps.txt)?" y && groups+=(apps)
ask "Virtual machines and Docker (packages/vm.txt)?" y && groups+=(vm)
flatpak=false
ask "Flatpak apps (packages/flatpak.txt)?" y && flatpak=true

echo
echo "Package lists: ${groups[*]}$($flatpak && echo ", flatpak")"
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

# --- Dotfiles -----------------------------------------------------------------------------------------
step "Dotfiles"
sudo pacman -Syu --needed --noconfirm base-devel git stow
backup="$HOME/.dotfiles-backup/$(date +%F_%H-%M-%S)"
packages=()
for dir in "$dotfiles"/*/; do
    name=$(basename "$dir")
    [[ " ${not_stowed[*]} " == *" $name "* ]] || packages+=("$name")
done
# Files where a link should go, which aren't links into the dotfiles already, move aside
moved=0
for name in "${packages[@]}"; do
    while IFS= read -r -d '' file; do
        rel=${file#"$dotfiles/$name/"}
        target="$HOME/$rel"
        [[ -e $target || -L $target ]] || continue
        [[ $(readlink -f "$target") == "$file" ]] && continue
        mkdir -p "$backup/$(dirname "$rel")"
        mv "$target" "$backup/$rel"
        moved=$((moved + 1))
    done < <(find "$dotfiles/$name" \( -type f -o -type l \) -print0)
done
((moved)) && note "Moved $moved file(s) that were in the way to $backup"
stow -d "$dotfiles" -t "$HOME" --restow "${packages[@]}"
echo "Linked: ${packages[*]}"

# --- Packages -------------------------------------------------------------------------------------------
step "Packages"
if ! command -v paru >/dev/null; then
    echo "Building paru from the AUR"
    build=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/paru.git "$build/paru"
    (cd "$build/paru" && makepkg -si --needed --noconfirm)
    rm -rf "$build"
fi
mapfile -t wanted < <(for group in "${groups[@]}"; do list "$group"; done | sort -u)
# paru installs repo and AUR packages alike, and asks once
paru -Syu --needed "${wanted[@]}"

if $flatpak; then
    step "Flatpak"
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    mapfile -t apps < <(list flatpak)
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
vm=false
[[ " ${groups[*]} " == *" vm "* ]] && vm=true && services+=(libvirtd docker.socket)
for unit in "${services[@]}"; do
    if sudo systemctl enable "$unit" &>/dev/null; then echo "Enabled $unit"; else note "Couldn't enable $unit"; fi
done
# The lock screen gets up to 15 s, not logind's 5, to come up before a suspend
# (scripts/sleep-lock.sh). logind reads it on reload.
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
"$HOME/.config/scripts/install-zsh-plugins.py"

step "Theme"
# The login screen first: theme-set.py writes its colors to the folder this makes
sudo "$dotfiles/sddm/install.sh" >/dev/null
# tmux's theme plugin (.tmux.conf would clone it on first start), so theme-set.py can write
# the theme's colors into it now
tmux_theme="$HOME/.tmux/plugins/catppuccin/tmux"
[[ -d $tmux_theme ]] || git clone -q -b v2.3.2 https://github.com/catppuccin/tmux.git "$tmux_theme"
"$HOME/.config/scripts/theme-set.py"
# Backgrounds: ~/.local/share/dotfiles/backgrounds/default (wallpapers, with the bundled one)
# and /live, and ~/.config/dotfiles/backgrounds.json for more folders. The desktop, lock
# screen and login screen get the theme's background, which theme-set.py just drew (the logo
# in accent2 on base, like the boot splash and menu), unless a wallpaper is chosen already;
# the bundled one if drawing it failed. Both follow the theme from then on.
wall=$(jq -r '.background // empty' "$HOME/.config/theme/current/quickshell.json" 2>/dev/null) || wall=
"$HOME/.config/scripts/wallpaper.py" default ${wall:+"$wall"}
sudo "$HOME/.config/scripts/browser-theme-setup.sh"

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

    # Only the boot screen's GPU driver in the initramfs, for the splash. The kms hook would
    # add every GPU's (NVIDIA's makes the image five times bigger).
    mkinit=/etc/mkinitcpio.conf
    sudo cp -n "$mkinit" "$mkinit.bak"
    if grep -q '^MODULES=()' "$mkinit"; then
        case $boot_gpu in
            0x8086) modules=${boot_driver:-i915}; [[ $modules == xe ]] || modules=i915 ;;
            0x10de) modules="nvidia nvidia_modeset nvidia_uvm nvidia_drm" ;;
            0x1002) modules=amdgpu ;;
            *) modules= ;;
        esac
        [[ -n $modules ]] && sudo sed -i "s/^MODULES=()/MODULES=($modules)/" "$mkinit" && echo "MODULES=($modules)"
    fi
    if grep -qE '^MODULES=\(.+\)' "$mkinit"; then
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
    sudo "$dotfiles/plymouth/install.sh" --theme
    sudo "$dotfiles/limine/install.sh" --theme
fi

step "Done"
cat <<MSG
Reboot. After the first login, from the desktop:

  ~/.config/scripts/hypr-monitors.py export-greeter   the login screen's monitor layout

Backups of what this changed: /etc/pacman.conf.bak, /etc/mkinitcpio.conf.bak, the presets'
.bak files and /etc/pacman.d/mirrorlist.bak.
MSG
