# Built by autostart.sh into ~/.cache, so nothing compiled lands in the repo
OUT := $(or $(XDG_CACHE_HOME),$(HOME)/.cache)/keep-keyboard
XML := virtual-keyboard-unstable-v1.xml

$(OUT)/keep-keyboard: keep-keyboard.c $(XML)
	mkdir -p $(OUT)
	wayland-scanner client-header $(XML) $(OUT)/virtual-keyboard-client.h
	wayland-scanner private-code $(XML) $(OUT)/virtual-keyboard-protocol.c
	$(CC) -O2 -Wall -I$(OUT) -o $@ keep-keyboard.c $(OUT)/virtual-keyboard-protocol.c $$(pkg-config --cflags --libs wayland-client)
