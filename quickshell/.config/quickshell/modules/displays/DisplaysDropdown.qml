import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Displays, from the bar's monitor icon (SUPER+CTRL+M): the header as the other dropdowns',
// then the display settings (DisplaysEditor, also Settings' Displays page)
Dropdown {
    id: root

    name: "displays"
    contentWidth: 540

    Hero {
        icon: Icons.display
        iconColor: Hues.system
        title: "Displays"
        status: Displays.busy ? "Applying…" : `${Quickshell.screens.length} connected`
    }

    Separator {}

    DisplaysEditor {
        visible: root.shown
    }
}
