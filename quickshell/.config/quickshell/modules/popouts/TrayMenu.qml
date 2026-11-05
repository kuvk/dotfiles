import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Right-click menu of a tray app, drawn in the theme instead of the app's own
// toolkit style. Submenus open in place with a back row at the top.
Popout {
    id: root

    name: "traymenu"
    contentWidth: 280

    // Menus from the root to the one shown
    property var stack: []
    readonly property var current: stack.length > 0 ? stack[stack.length - 1] : (Panels.trayItem?.menu ?? null)

    onShownChanged: stack = []

    QsMenuOpener {
        id: opener

        menu: root.current
    }

    ListItem {
        visible: root.stack.length > 0
        icon: Icons.chevronLeft
        label: "Back"
        implicitHeight: 32
        onClicked: root.stack = root.stack.slice(0, -1)
    }

    Repeater {
        model: opener.children

        Loader {
            id: entry

            required property QsMenuEntry modelData

            Layout.fillWidth: true
            sourceComponent: modelData.isSeparator ? separator : item

            Component {
                id: separator

                Rectangle {
                    implicitHeight: 9
                    color: "transparent"

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: 1
                        color: Theme.surface1
                    }
                }
            }

            Component {
                id: item

                MouseArea {
                    id: row

                    implicitHeight: 32
                    enabled: entry.modelData.enabled
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    opacity: enabled ? 1 : 0.4
                    onClicked: {
                        if (entry.modelData.hasChildren) {
                            root.stack = [...root.stack, entry.modelData];
                        } else {
                            entry.modelData.triggered();
                            Panels.closePopout("traymenu");
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.smallRadius
                        color: row.containsMouse ? Theme.hoverBg : "transparent"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        // checkbox / radio state
                        Icon {
                            Layout.preferredWidth: 14
                            visible: entry.modelData.buttonType !== QsMenuButtonType.None
                            text: entry.modelData.checkState === Qt.Checked ? Icons.check : ""
                            color: Theme.highlight
                            font.pixelSize: 11
                        }

                        IconImage {
                            implicitSize: 16
                            visible: entry.modelData.icon !== ""
                            source: entry.modelData.icon
                        }

                        StyledText {
                            Layout.fillWidth: true
                            // GTK/Qt mnemonics: "_File" / "&File"
                            text: entry.modelData.text.replace(/_(.)/g, "$1").replace(/&(.)/g, "$1")
                        }

                        Icon {
                            visible: entry.modelData.hasChildren
                            text: Icons.chevronRight
                            color: Theme.overlay1
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }
}
