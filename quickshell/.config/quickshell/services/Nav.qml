pragma Singleton

import QtQuick
import Quickshell

// Keyboard navigation in the shell's windows, the same everywhere: Up / Down, Left / Right and
// Ctrl+K / J, Ctrl+H / L move to the previous or next control (Tab and Shift+Tab too, Qt's own);
// Enter or Space use the control (each control's own keys). A control that uses an arrow
// itself (a stepper, a slider, a list) takes it first; the window's root gets what's left
// (`handle` in its Keys.onPressed). The control moved to is scrolled into view.
Singleton {
    // -1 back, 1 forward, 0 not a navigation key
    function direction(event: var): int {
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (event.key === Qt.Key_Down || event.key === Qt.Key_Right || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_L)))
            return 1;
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Left || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_H)))
            return -1;
        return 0;
    }

    // Move the focus from what has it in `root`'s window; true when it was a navigation key
    function handle(event: var, root: Item): bool {
        const dir = direction(event);
        if (dir === 0)
            return false;
        const from = root.Window.activeFocusItem ?? root;
        let next = from.nextItemInFocusChain(dir > 0);
        // only within this window's content, and only to something shown
        for (let i = 0; next && i < 200 && !(next.visible && next.enabled && isInside(next, root)); i++)
            next = next.nextItemInFocusChain(dir > 0);
        if (next && next !== from) {
            next.forceActiveFocus(Qt.TabFocusReason);
            reveal(next);
        }
        return true;
    }

    function isInside(item: Item, root: Item): bool {
        for (let p = item; p; p = p.parent)
            if (p === root)
                return true;
        return false;
    }

    // The first control inside `container` (its first in the focus chain that's shown there)
    function first(container: Item): void {
        let next = container.nextItemInFocusChain(true);
        for (let i = 0; next && i < 400 && !(next.visible && next.enabled && isInside(next, container)); i++)
            next = next.nextItemInFocusChain(true);
        if (next && isInside(next, container)) {
            next.forceActiveFocus(Qt.TabFocusReason);
            reveal(next);
        }
    }

    // Scroll the nearest Flickable around `item` so it's in view, with a little room
    function reveal(item: Item): void {
        for (let p = item.parent; p; p = p.parent) {
            if (p.contentItem !== undefined && p.contentY !== undefined && p.contentHeight !== undefined) {
                const y = item.mapToItem(p.contentItem, 0, 0).y;
                const margin = 24;
                if (y - margin < p.contentY)
                    p.contentY = Math.max(0, y - margin);
                else if (y + item.height + margin > p.contentY + p.height)
                    p.contentY = Math.min(Math.max(0, p.contentHeight - p.height), y + item.height + margin - p.height);
                return;
            }
        }
    }

    // Enter, Return or Space: use the control
    function isActivate(event: var): bool {
        return event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space;
    }
}
