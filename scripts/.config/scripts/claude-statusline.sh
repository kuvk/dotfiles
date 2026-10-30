#!/bin/bash
# Claude Code status line: the vim mode in color, like lualine in nvim, then the
# folder and how full the context is. settings.json: statusLine.command
. "$HOME/.config/theme/current/colors.sh" 2>/dev/null

rgb() { printf '%d;%d;%d' "0x${1:1:2}" "0x${1:3:2}" "0x${1:5:2}"; }

# a separator that isn't whitespace, so empty fields stay in place
IFS=$'\x1f' read -r mode dir used < <(jq -r '[.vim.mode // "", .workspace.current_dir // "", (.context_window.used_percentage // "" | tostring)] | join("\u001f")')

case $mode in
    NORMAL) color=$blue ;;
    INSERT) color=$green ;;
    VISUAL*) color=$mauve ;;
    *) color= ;;
esac

line=
[[ -n $color ]] && line=$(printf '\033[1;38;2;%s;48;2;%sm %s \033[0m ' "$(rgb "$base")" "$(rgb "$color")" "$mode")
line+=$(printf '\033[38;2;%sm%s\033[0m' "$(rgb "$subtext0")" "${dir/#$HOME/\~}")
[[ -n $used ]] && line+=$(printf '  \033[38;2;%sm%.0f%%\033[0m' "$(rgb "$overlay1")" "$used")
printf '%s\n' "$line"
