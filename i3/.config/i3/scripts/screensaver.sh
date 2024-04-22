#!/usr/bin/sh


if ! pidof -x xfce4-terminal; then
  xfce4-terminal --command "unimatrix -b -s 96 -f -l m" &
  sleep 0.4

  i3-msg fullscreen toggle global

  i3lock -n; i3-msg kill
fi
