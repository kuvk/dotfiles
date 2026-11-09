import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// The Static and Live tabs and the search field, above the carousel (wallpaper picker)
ColumnLayout {
    // the wallpaper picker: the list, the selection and the card geometry
    required property var picker

    spacing: 12

    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        Repeater {
            model: [
                { kind: "static", label: "Wallpapers" },
                { kind: "live", label: "Live wallpapers" }
            ]

            MouseArea {
                id: tab

                required property var modelData
                readonly property bool current: picker.kind === modelData.kind

                width: tabLabel.implicitWidth + 28
                height: 32
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.wallpapers = modelData.kind

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius
                    color: tab.current ? Theme.selectedFill : Theme.alpha(Theme.background, 0.6)
                    border.color: tab.current ? Theme.accent : "transparent"
                    border.width: Theme.borderWidth
                }

                StyledText {
                    id: tabLabel

                    anchors.centerIn: parent
                    text: tab.modelData.label
                    color: tab.current ? Theme.accent : Theme.subtext
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: Math.round(320 * Theme.textScale)
        implicitHeight: 34
        radius: height / 2
        color: Theme.alpha(Theme.background, 0.75)
        border.color: picker.query !== "" ? Theme.accent : "transparent"
        border.width: Theme.borderWidth

        Row {
            anchors.centerIn: parent
            spacing: 8

            Icon {
                text: Icons.search
                color: picker.query !== "" ? Theme.accent : Theme.dimText
            }

            StyledText {
                text: picker.query !== "" ? picker.query : "Type to search"
                color: picker.query !== "" ? Theme.foreground : Theme.dimText
            }
        }
    }
}
