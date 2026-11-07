#!/bin/bash
# System Information: fastfetch in a kitty window of its own, sized to the output, with no
# cursor or prompt; any key closes it, and running this again while it's open closes it too.
# The text is kitty's, so it can be selected and copied. After Omarchy's About window
# (omarchy-launch-about, github.com/basecamp/omarchy, MIT). Floated and centered by a
# Hyprland rule (rules.lua, class kuvk-sysinfo).
#
# The window is fitted from inside, where fastfetch sees the terminal it draws in (run from
# the shell it lays out differently): its output is measured in cells, and the window is
# sized to exactly those cells plus kitty's padding (kitty puts any extra at the bottom and
# right), from the cell size kitty reports. The size that fit is remembered and set as a
# window rule before the next launch, so the window opens at it.

class=kuvk-sysinfo
fit_file=${XDG_STATE_HOME:-$HOME/.local/state}/kuvk-shell/sysinfo.fit

# The same on every side: kitty's padding around the output (pt, so 4/3 px at scale 1)
padding_pt=12

# fastfetch names the shell from its parent and the terminal from the shell's: run it from
# your shell so it reports that one (the ": " keeps the shell around)
run_fastfetch() {
    "${SHELL:-bash}" -c "fastfetch $*; :"
}

# The cells fastfetch's output takes: it draws the info beside the logo with cursor moves, so
# replay them (columns as kitty counts them: wide characters take two). The columns get as many
# blank ones on the right as the output starts with on the left (the logo's left padding).
measure() {
    python3 -I -c '
import re, sys, unicodedata
row = col = 0
width = {}
left = None
for m in re.finditer(r"\x1b\[([0-9;?]*)([A-Za-z])|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b.|(.)", sys.stdin.read(), re.S):
    ch = m.group(3)
    if ch is None:
        if m.group(2):
            args = [int(a) if a else None for a in m.group(1).replace("?", "").split(";")]
            n = args[0] or 1
            kind = m.group(2)
            if kind == "A": row = max(0, row - n)
            elif kind == "B": row += n
            elif kind == "C": col += n
            elif kind == "D": col = max(0, col - n)
            elif kind == "G": col = n - 1
            elif kind in "Hf": row, col = (args[0] or 1) - 1, ((args[1] if len(args) > 1 else None) or 1) - 1
        continue
    if ch == "\n":
        row, col = row + 1, 0
    elif ch == "\r":
        col = 0
    elif ch >= " ":
        if not ch.isspace() and ch != "\u2800":
            left = col if left is None else min(left, col)
        col += 2 if unicodedata.east_asian_width(ch) in "WF" else 1
        if not ch.isspace():
            width[row] = max(width.get(row, 0), col)
print(max(width.values(), default=60) + (left or 0), max(width, default=20) + 1)
'
}

# The window rule that opens it at the remembered size; without a size, only the old one goes
size_rule() {
    local rule=""
    (($# == 2)) && rule="kuvk_sysinfo_size = hl.window_rule({ match = { class = \"^$class\$\" }, size = { $1, $2 } })"
    hyprctl eval "if kuvk_sysinfo_size then kuvk_sysinfo_size:set_enabled(false) end; kuvk_sysinfo_size = nil; $rule" >/dev/null 2>&1
}

# Hyprland animates a resize and kitty reflows at every step: wait for the grid to hold still
settle() {
    local current previous="" held=0
    for _ in {1..30}; do
        current=$(stty size)
        if [[ $current == "$previous" ]]; then
            ((++held == 3)) && return
        else
            held=0
            previous=$current
        fi
        sleep 0.05
    done
}

# kitty's cell in pixels, height and width (asked with CSI 16 t, on the terminal itself: this
# runs with its output captured)
cell_size() {
    local old reply="" c
    old=$(stty -g </dev/tty)
    stty -echo -icanon </dev/tty
    printf '\e[16t' >/dev/tty
    while IFS= read -rsn1 -t 1 c </dev/tty; do
        reply+=$c
        [[ $c == t ]] && break
    done
    stty "$old" </dev/tty
    [[ $reply =~ \[6\;([0-9]+)\;([0-9]+)t ]] && echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
}

# Size the window (kitty, this script's parent) to the cells plus the padding, centered
fit() {
    local want_c=$1 want_r=$2 ch cw address monitor scale w h rows cols
    # opened at the size that fit last time: nothing to do
    read -r rows cols < <(stty size)
    ((rows == want_r && cols == want_c)) && return 0
    settle
    read -r ch cw < <(cell_size) || return 1
    read -r address monitor < <(hyprctl clients -j | jq -r --argjson pid "$PPID" \
        'first(.[] | select(.pid == $pid) | "\(.address) \(.monitor)") // empty')
    [[ -n $address ]] || return 1
    scale=$(hyprctl monitors -j | jq -r --argjson id "$monitor" 'first(.[] | select(.id == $id) | .scale) // 1')
    # cells in physical pixels, the window in logical ones
    read -r w h < <(awk -v c="$want_c" -v r="$want_r" -v cw="$cw" -v ch="$ch" -v s="$scale" -v p="$padding_pt" \
        'BEGIN { pad = 2 * p * 4 / 3; printf "%d %d\n", int(pad + c * cw / s + 0.999), int(pad + r * ch / s + 0.999) }')
    for _ in 1 2 3; do
        hyprctl dispatch "hl.dsp.window.resize({ window = \"address:$address\", x = $w, y = $h })" >/dev/null
        hyprctl dispatch "hl.dsp.window.center({ window = \"address:$address\" })" >/dev/null
        settle
        read -r rows cols < <(stty size)
        if ((rows >= want_r && cols >= want_c)); then
            mkdir -p "${fit_file%/*}"
            echo "$want_c $want_r $w $h" >"$fit_file"
            return 0
        fi
        # rounding left it a cell short: a pixel more where it's short
        ((cols < want_c)) && ((w++))
        ((rows < want_r)) && ((h++))
    done
    return 1
}

# fastfetch's output without its last line break (and the reset after it), so the last row is
# the output's own and nothing scrolls
output() {
    local out
    out=$(run_fastfetch --pipe false 2>/dev/null)
    out=${out%$'\e[m'}
    printf '%s\e[m' "${out%$'\n'}"
}

if [[ ${1:-} == --render ]]; then
    printf '\e[?25l'
    # shown at once, measured from the same run, then the window fitted if it isn't already
    out=$(output)
    clear
    printf '%s' "$out"
    grid=$(stty size)
    read -r cols rows < <(printf '%s' "$out" | measure)
    fit "$cols" "$rows"
    # any key closes it; a resize (the fit's too) draws it again
    while :; do
        while [[ $(stty size) == "$grid" ]]; do
            read -rsn1 -t 0.5 && exit 0
            (($? > 128)) || exit 0
        done
        grid=$(stty size)
        clear
        output
    done
fi

# Open already: close it
pid=$(hyprctl clients -j | jq -r --arg c "$class" 'first(.[] | select(.class == $c) | .pid) // empty')
if [[ -n $pid ]]; then
    kill "$pid"
    exit 0
fi

command -v fastfetch >/dev/null || {
    notify-send -a "System Information" "fastfetch is not installed"
    exit 1
}

# The size that fit last time (fitted again inside if the output has changed)
size_rule
if read -r _ _ fit_w fit_h 2>/dev/null <"$fit_file" && [[ $fit_w =~ ^[0-9]+$ && $fit_h =~ ^[0-9]+$ ]]; then
    size_rule "$fit_w" "$fit_h"
fi

exec kitty --class "$class" --title "System Information" \
    -o initial_window_width=108c -o initial_window_height=26c \
    -o remember_window_size=no -o window_padding_width=12 \
    "$0" --render
