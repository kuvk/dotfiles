#!/bin/bash
# Claude Code status line: the vim mode as a colored bubble, like lualine in nvim
# (square in Work-Game or at radius 0), then the folder and how full the context is.
# Also sets the cursor by mode, as Claude Code itself doesn't: block, beam in insert.
# settings.json: statusLine.command
. "$HOME/.config/theme/current/colors.sh" 2>/dev/null

rgb() { printf '%d;%d;%d' "0x${1:1:2}" "0x${1:3:2}" "0x${1:5:2}"; }

# a separator that isn't whitespace, so empty fields stay in place
IFS=$'\x1f' read -r mode dir used < <(jq -r '[.vim.mode // "", .workspace.current_dir // "", (.context_window.used_percentage // "" | tostring)] | join("\u001f")')

case $mode in
    NORMAL) color=$blue cursor=1 ;;
    INSERT) color=$green cursor=5 ;;
    VISUAL*) color=$mauve cursor=1 ;;
    *) color= cursor= ;;
esac
# Claude Code runs this without a controlling terminal, so find its own (stdin)
if [[ -n $cursor ]]; then
    pid=$PPID
    while (( pid > 1 )); do
        tty=$(readlink "/proc/$pid/fd/0")
        if [[ $tty == /dev/pts/* ]]; then
            printf '\033[%s q' "$cursor" 2>/dev/null >"$tty"
            break
        fi
        read -r _ _ _ pid _ <"/proc/$pid/stat" || break
    done
fi

left=$'' right=$''
[[ $(<"$HOME/.config/theme/current/shape") == square ]] 2>/dev/null && left= right=

line=
if [[ -n $color ]]; then
    c=$(rgb "$color")
    line=$(printf '\033[38;2;%sm%s\033[1;38;2;%s;48;2;%sm %s \033[0;38;2;%sm%s\033[0m ' "$c" "$left" "$(rgb "$base")" "$c" "$mode" "$c" "$right")
fi
line+=$(printf '\033[38;2;%sm%s\033[0m' "$(rgb "$subtext0")" "${dir/#$HOME/\~}")
[[ -n $used ]] && line+=$(printf '  \033[38;2;%sm%.0f%%\033[0m' "$(rgb "$overlay1")" "$used")
printf '%s\n' "$line"
