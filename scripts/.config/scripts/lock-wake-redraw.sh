#!/bin/bash
# After a wake the lock screen can stop drawing: it waits for a frame signal that got
# lost during suspend. Moving the (hidden) pointer a pixel and back restarts it.
# Run by hypridle's after_sleep_cmd; a few tries, as the screens take a moment to return.
for delay in 1 1.5 2; do
    sleep "$delay"
    [[ $(hyprctl locked) == *true* ]] || exit 0
    IFS=', ' read -r x y < <(hyprctl cursorpos)
    hyprctl dispatch "hl.dsp.cursor.move({ x = $((x + 1)), y = $y })" >/dev/null
    hyprctl dispatch "hl.dsp.cursor.move({ x = $x, y = $y })" >/dev/null
done
