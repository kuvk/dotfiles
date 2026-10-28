#!/usr/bin/env bash
# yazi that follows theme changes. yazi can't reload its theme while running,
# so theme-set.py asks every yazi started through here to quit (it remembers
# its folder) and this starts it again in the same folder, in the same window.
#
#   yazi-live.sh [yazi args]     use instead of `yazi` (ALT+E, the `y` shell function)
#   YAZI_LIVE_CWD_OUT=FILE       write the last folder there on exit (for `y`)
set -u

dir="${XDG_RUNTIME_DIR:-/tmp}/yazi-live"
mkdir -p "$dir"
id=$$
cwd_file="$dir/$id.cwd"
restart="$dir/$id.restart"
# theme-set.py finds running instances by these files
: >"$dir/$id.client"
trap 'rm -f "$dir/$id".*' EXIT

while true; do
    rm -f "$restart"
    yazi --client-id "$id" --cwd-file "$cwd_file" "$@"
    [[ -f $restart ]] || break
    next=$(cat "$cwd_file" 2>/dev/null)
    set -- "${next:-$PWD}"
done

if [[ -n ${YAZI_LIVE_CWD_OUT:-} && -s $cwd_file ]]; then
    cp "$cwd_file" "$YAZI_LIVE_CWD_OUT"
fi
