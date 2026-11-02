#!/usr/bin/env bash
# Periodic housekeeping (monthly-ish). Shows what each step would free and asks first.
#
#   sysmaintenance.sh             clean up
#   sysmaintenance.sh --upgrade   run update.sh first
#
# Leaves alone what is rebuilt anyway at a cost: browser and shader caches (games stutter while
# shaders rebuild), Spotify's cache, Python versions in ~/.pyenv.
set -uo pipefail

PACCACHE_KEEP=2         # package versions kept in pacman's cache
JOURNAL_KEEP="2weeks"   # journald: time (2weeks) or size (500M)
LOGS_KEEP=10            # this script's own logs
AUR_KEEP=(davinci-resolve)  # AUR folders never cleaned: hand-downloaded sources live there

scripts=$(dirname "$(readlink -f "$0")")
log_dir="$HOME/.local/var/log"
mkdir -p "$log_dir"
log_file="$log_dir/sysmaintenance-$(date +%F_%H-%M-%S).log"
exec > >(tee -a "$log_file") 2>&1

case ${1:-} in
    -u | --upgrade) upgrade=true ;;
    "") upgrade=false ;;
    -h | --help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

step() { printf '\n\e[1;34m==> %s\e[0m\n' "$1"; }
confirm() { read -r -p "$1 [y/N] " answer </dev/tty; [[ $answer =~ ^[yY]([eE][sS])?$ ]]; }
size() { du -sh "$@" 2>/dev/null | tail -1 | cut -f1; }

echo "Maintenance started $(date)"

if $upgrade; then
    "$scripts/update.sh"
fi

# --- pacman's package cache -------------------------------------------------------------------
step "pacman cache ($(size /var/cache/pacman/pkg))"
old=$(paccache -dk"$PACCACHE_KEEP" 2>/dev/null | tail -1)
gone=$(paccache -duk0 2>/dev/null | tail -1)
echo "Older than the last $PACCACHE_KEEP versions: ${old#==> }"
echo "Packages no longer installed: ${gone#==> }"
if confirm "Remove them?"; then
    sudo paccache -qrk"$PACCACHE_KEEP"
    sudo paccache -qruk0
fi

# --- AUR build folders (paru) -----------------------------------------------------------------
clones="$HOME/.cache/paru/clone"
if [[ -d $clones ]]; then
    step "AUR build folders ($(size "$clones"))"
    # Clones of packages no longer installed (by package base), and old downloads and builds
    # in the rest; paru fetches what it needs at the next update
    mapfile -t installed < <(pacman -Qqm)
    stale=()
    for dir in "$clones"/*/; do
        dir=${dir%/}
        base=$(sed -n 's/^\s*pkgbase = //p' "$dir/.SRCINFO" 2>/dev/null | head -1)
        names=$(sed -n 's/^pkgname = //p' "$dir/.SRCINFO" 2>/dev/null)
        keep=false
        for name in ${names:-${dir##*/}} ${base:-}; do
            [[ " ${installed[*]} " == *" $name "* ]] && keep=true
        done
        [[ " ${AUR_KEEP[*]} " == *" ${dir##*/} "* ]] && keep=true
        $keep || stale+=("$dir")
    done
    if ((${#stale[@]})); then
        echo "For packages no longer installed ($(size "${stale[@]}" -c)):"
        printf '  %s\n' "${stale[@]##*/}"
    fi
    echo "Kept as they are: ${AUR_KEEP[*]}"
    if confirm "Remove those, and old downloads and builds in the others?"; then
        rm -rf "${stale[@]}"
        for dir in "$clones"/*/; do
            [[ " ${AUR_KEEP[*]} " == *" $(basename "$dir") "* ]] && continue
            git -C "$dir" clean -fdxq 2>/dev/null
        done
        echo "Now $(size "$clones")"
    fi
fi

# --- Orphans: removing some can leave new ones, so repeat until none are left -------------------
step "Orphaned packages"
mapfile -t orphans < <(pacman -Qqdt)
if ((${#orphans[@]})); then
    echo "${#orphans[@]} installed only as dependencies, now needed by nothing:"
    printf '%s ' "${orphans[@]}"; echo
    if confirm "Remove them (and any this leaves orphaned)?"; then
        while mapfile -t orphans < <(pacman -Qqdt) && ((${#orphans[@]})); do
            sudo pacman -Rns --noconfirm "${orphans[@]}" || break
        done
    fi
else
    echo "None."
fi

# --- Flatpak runtimes no app uses -------------------------------------------------------------
if command -v flatpak >/dev/null; then
    step "Unused Flatpak runtimes"
    flatpak uninstall --unused
fi

# --- Download and build caches in your home -----------------------------------------------------
step "Download and build caches"
caches=()
for dir in ~/.cache/pip ~/.cache/go-build ~/go/pkg/mod ~/.cache/winetricks ~/.npm/_cacache ~/.cache/thumbnails; do
    [[ -d $dir ]] && caches+=("$dir")
done
if ((${#caches[@]})); then
    for dir in "${caches[@]}"; do printf '  %-6s %s\n' "$(size "$dir")" "${dir/#$HOME/\~}"; done
    if confirm "Clear them? (refilled when needed)"; then
        chmod -R u+w ~/go/pkg/mod 2>/dev/null  # Go makes its module cache read-only
        rm -rf "${caches[@]}"
    fi
fi

# --- Crash dumps ------------------------------------------------------------------------------
dumps=/var/lib/systemd/coredump
count=$(find "$dumps" -type f 2>/dev/null | wc -l)
if ((count)); then
    step "Crash dumps ($count, $(size "$dumps"))"
    find "$dumps" -type f -printf '%f\n' | sed -E 's/^core\.([^.]+)\..*/\1/' | sort | uniq -c | sort -rn | head -5
    if confirm "Delete them?"; then
        sudo find "$dumps" -type f -delete
    fi
fi

# --- Journal ----------------------------------------------------------------------------------
step "Journal ($(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMGT]?B?' | head -1))"
if confirm "Keep only the last $JOURNAL_KEEP?"; then
    sudo journalctl --rotate
    if [[ $JOURNAL_KEEP =~ [0-9]+[KMGT]$ ]]; then
        sudo journalctl --vacuum-size="$JOURNAL_KEEP"
    else
        sudo journalctl --vacuum-time="$JOURNAL_KEEP"
    fi
fi

# --- Checks ----------------------------------------------------------------------------------
step "Failed services"
failed=$(systemctl --failed --no-legend --plain 2>/dev/null)
failed_user=$(systemctl --user --failed --no-legend --plain 2>/dev/null)
[[ -n $failed ]] && printf 'System:\n%s\n' "$failed"
[[ -n $failed_user ]] && printf 'User:\n%s\n' "$failed_user"
[[ -z $failed && -z $failed_user ]] && echo "None."

step "Config files to merge"
mapfile -t pacnew < <(pacdiff -o 2>/dev/null)
if ((${#pacnew[@]})); then
    printf '  %s\n' "${pacnew[@]}"
    if confirm "Merge them now (pacdiff with nvim -d)?"; then
        sudo DIFFPROG="nvim -d" pacdiff
    fi
else
    echo "None."
fi

# This script's own logs: keep the newest few
find "$log_dir" -name 'sysmaintenance-*.log' -o -name 'spring-clean-*.log' | sort -r | tail -n +$((LOGS_KEEP + 1)) | xargs -r rm -f

step "Finished in ${SECONDS}s; log: $log_file"
