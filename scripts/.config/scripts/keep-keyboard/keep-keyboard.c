// Keeps a virtual keyboard on the seat. It sends no keys.
//
// Suspending takes every real keyboard away, and on wake Qt does not reactivate a lock
// surface that gets the keyboard back, so the password goes nowhere. With this always
// present the seat never loses its keyboard, and the lock surface keeps its focus.
#define _GNU_SOURCE
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <wayland-client.h>
#include "virtual-keyboard-client.h"

static const char KEYMAP[] =
    "xkb_keymap {\n"
    "xkb_keycodes \"(unnamed)\" { include \"evdev+aliases(qwerty)\" };\n"
    "xkb_types \"(unnamed)\" { include \"complete\" };\n"
    "xkb_compat \"(unnamed)\" { include \"complete\" };\n"
    "xkb_symbols \"(unnamed)\" { include \"pc+us+inet(evdev)\" };\n"
    "xkb_geometry \"(unnamed)\" { include \"pc(pc105)\" };\n"
    "};\n";

static struct wl_seat *seat;
static struct zwp_virtual_keyboard_manager_v1 *manager;

static void global(void *data, struct wl_registry *reg, uint32_t name, const char *iface, uint32_t ver) {
    if (!strcmp(iface, wl_seat_interface.name) && !seat)
        seat = wl_registry_bind(reg, name, &wl_seat_interface, 1);
    else if (!strcmp(iface, zwp_virtual_keyboard_manager_v1_interface.name))
        manager = wl_registry_bind(reg, name, &zwp_virtual_keyboard_manager_v1_interface, 1);
}
static void global_remove(void *data, struct wl_registry *reg, uint32_t name) {}
static const struct wl_registry_listener listener = {global, global_remove};

int main(void) {
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) return 1;
    wl_registry_add_listener(wl_display_get_registry(display), &listener, NULL);
    wl_display_roundtrip(display);
    if (!seat || !manager) return 1;
    struct zwp_virtual_keyboard_v1 *kb = zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(manager, seat);
    int fd = memfd_create("keymap", MFD_CLOEXEC);
    if (fd < 0 || write(fd, KEYMAP, sizeof KEYMAP) != sizeof KEYMAP) return 1;
    zwp_virtual_keyboard_v1_keymap(kb, WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1, fd, sizeof KEYMAP);
    close(fd);
    while (wl_display_dispatch(display) != -1) {}
    return 0;
}
