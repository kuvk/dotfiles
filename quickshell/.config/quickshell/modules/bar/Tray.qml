import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.config
import qs.components
import qs.services

// System tray behind a left arrow. Hovering slides the icons out to the
// right of the arrow; they stay while the pointer is over them or a menu is open.
Item {
    id: root

    readonly property bool menuOpen: Panels.popout === "traymenu" && Panels.popoutScreen === QsWindow.window?.screen
    readonly property bool expanded: hover.hovered || menuOpen || collapseDelay.running

    property bool shown: true

    visible: shown && SystemTray.items.values.length > 0
    implicitWidth: arrow.implicitWidth + drawer.width
    implicitHeight: Theme.barHeight

    HoverHandler {
        id: hover

        onHoveredChanged: if (!hovered) collapseDelay.restart()
    }

    Timer {
        id: collapseDelay

        interval: 500
    }

    BarButton {
        id: arrow

        implicitWidth: 26
        indicator: false
        tooltip: root.expanded ? "" : "System tray"

        Icon {
            text: Icons.chevronLeft
            color: root.expanded ? Theme.accent : Theme.overlay2
            font.pixelSize: 11
        }
    }

    Item {
        id: drawer

        anchors.left: arrow.right
        height: parent.height
        width: root.expanded ? icons.implicitWidth : 0
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Theme.animDuration * 2
                easing.type: Easing.OutCubic
            }
        }

        Row {
            id: icons

            Repeater {
                model: SystemTray.items

                BarButton {
                    id: item

                    required property SystemTrayItem modelData

                    implicitWidth: 30
                    tooltip: modelData.tooltipTitle || modelData.title || modelData.id
                    active: root.menuOpen && Panels.trayItem === modelData
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton && !modelData.onlyMenu) {
                            modelData.activate();
                        } else if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate();
                        } else if (modelData.hasMenu) {
                            // themed menu (modules/popouts/TrayMenu.qml); the
                            // reopen guard only applies to the same app's menu
                            if (Panels.trayItem !== modelData)
                                Panels.lastClosed = "";
                            Panels.trayItem = modelData;
                            const pos = item.mapToItem(null, item.width / 2, 0);
                            Panels.togglePopout("traymenu", QsWindow.window.screen, pos.x);
                        }
                    }

                    TrayIcon {
                        item: item.modelData
                    }
                }
            }
        }
    }
}
