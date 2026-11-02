#!/usr/bin/env bash
# Updates everything: pacman and AUR packages (paru shows Arch news first), Flatpak apps, the
# Limine menu when Limine or the kernels changed, Neovim plugins and Mason tools, spicetify.
# Then lists new .pacnew files and says when a reboot is needed.
#
#   update.sh           all of it, asking before each package transaction
#   update.sh --yes     no questions from paru, pacman or flatpak
set -uo pipefail

dotfiles=$(cd "$(dirname "$(readlink -f "$0")")/../../.." && pwd)
yes=false
[[ ${1:-} == --yes || ${1:-} == -y ]] && yes=true

step() { printf '\n\e[1;34m==> %s\e[0m\n' "$1"; }
note() { printf '\e[33m%s\e[0m\n' "$1"; }

# --- System packages (repos, the g14 repo, AUR) ---------------------------------------------
step "Packages"
if $yes; then
    paru -Syu --noconfirm
else
    paru -Syu
fi || note "The package upgrade didn't finish; the steps below still run."

# --- Flatpak --------------------------------------------------------------------------------
if command -v flatpak >/dev/null; then
    step "Flatpak"
    if $yes; then flatpak update -y; else flatpak update; fi
fi

# --- Limine: its EFI file and menu entries follow the package and the kernels in /efi/arch ---
conf=/efi/EFI/limine/limine.conf
if [[ -r $conf ]]; then
    step "Limine"
    reasons=()
    cmp -s /usr/share/limine/BOOTX64.EFI /efi/EFI/limine/BOOTX64.EFI || reasons+=("a new Limine")
    in_menu=$(sed -n 's|^//||p' "$conf" | sort | tr '\n' ' ')
    on_esp=$(for k in /efi/arch/vmlinuz-*; do [[ -e /efi/arch/initramfs-${k#*/vmlinuz-}.img ]] && echo "${k#*/vmlinuz-}"; done | sort | tr '\n' ' ')
    [[ $in_menu == "$on_esp" ]] || reasons+=("kernels changed: ${on_esp:-none}")
    if ((${#reasons[@]})); then
        echo "Rewriting the menu (${reasons[*]})"
        read -ra options <<<"$(sed -n 's/^# Options: //p' "$conf")"
        sudo "$dotfiles/limine/install.sh" "${options[@]}"
    else
        echo "Up to date."
    fi
fi

# --- Neovim: plugins, then Mason's tools -----------------------------------------------------
if command -v nvim >/dev/null; then
    step "Neovim plugins"
    nvim --headless "+Lazy! sync" +qa 2>&1 | tail -n 3
    step "Mason tools"
    mason=$(mktemp --suffix=.lua)
    cat >"$mason" <<'EOF'
pcall(function() require("lazy").load({ plugins = { "mason.nvim" } }) end)
local ok, registry = pcall(require, "mason-registry")
if not ok then io.write("Mason isn't set up.\n") vim.cmd("qa!") return end
local refreshed = false
registry.refresh(function() refreshed = true end)
vim.wait(120000, function() return refreshed end, 200)
local pending, failed = 0, {}
for _, pkg in ipairs(registry.get_installed_packages()) do
  local okc, current = pcall(pkg.get_installed_version, pkg)
  local okl, latest = pcall(pkg.get_latest_version, pkg)
  if okc and okl and current and latest and current ~= latest then
    pending = pending + 1
    io.write(("%s %s -> %s\n"):format(pkg.name, current, latest))
    pkg:install({ version = latest }, function(success)
      if not success then table.insert(failed, pkg.name) end
      pending = pending - 1
    end)
  end
end
vim.wait(900000, function() return pending == 0 end, 500)
if #failed > 0 then io.write("Failed: " .. table.concat(failed, ", ") .. "\n")
elseif pending == 0 then io.write("Up to date.\n") end
vim.cmd("qa!")
EOF
    nvim --headless -c "luafile $mason"
    rm -f "$mason"
fi

# --- spicetify: Spotify updates itself on launch, which undoes the theme -------------------
if command -v spicetify >/dev/null && ! pgrep -x spotify >/dev/null; then
    step "spicetify"
    if ! spicetify -q apply 2>/dev/null; then
        echo "Spotify was updated; applying the theme again"
        spicetify -q restore backup apply
    else
        echo "Applied."
    fi
fi

# --- What's left to do by hand ----------------------------------------------------------------
step "Done"
mapfile -t pacnew < <(pacdiff -o 2>/dev/null)
if ((${#pacnew[@]})); then
    note "${#pacnew[@]} config file(s) have a new version to merge (.pacnew/.pacsave):"
    printf '  %s\n' "${pacnew[@]}"
    note "Merge them with: sudo DIFFPROG='nvim -d' pacdiff"
fi
if [[ ! -d /usr/lib/modules/$(uname -r) ]]; then
    note "The running kernel ($(uname -r)) was updated: reboot to use the new one."
fi
