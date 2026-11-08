import QtQuick
import QtQuick.Layouts
import qs.config

// A theme color by name: the label on the left, the current color (swatch and name) on the
// right; a click unfolds the list below, a pick folds it. `value` is the color's name in
// Theme. With `defaultLabel`, the list starts with that choice, picked as "".
ColumnLayout {
    id: root

    property string label
    property string hint: ""
    property string value
    property string defaultLabel: ""
    // the default's swatch, when known
    property color defaultColor: "transparent"
    // the theme's accent, then every color the themes name
    property var names: ["accent", ...palette]
    readonly property var palette: ["red", "orange", "yellow", "green", "cyan", "blue", "magenta", "brown", "bright_red", "bright_yellow", "bright_green", "bright_cyan", "bright_blue", "bright_magenta", "foreground", "light_foreground", "bright_foreground", "dark_foreground", "muted", "selection", "lighter_background", "background", "dark_background", "darker_background"]
    property bool open: false
    signal picked(string name)

    readonly property var entries: defaultLabel ? ["", ...names] : names

    // "bright_magenta" -> "Bright magenta"
    function title(name: string): string {
        if (name === "")
            return root.defaultLabel;
        const spaced = name.replace(/_/g, " ");
        return spaced[0].toUpperCase() + spaced.slice(1);
    }

    Layout.fillWidth: true
    spacing: 4

    SettingRow {
        label: root.label
        hint: root.hint

        MouseArea {
            id: button

            implicitWidth: 180
            implicitHeight: 30
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open

            Rectangle {
                anchors.fill: parent
                radius: Theme.smallRadius
                color: button.containsMouse ? Theme.hoverBg : Theme.cardBg
                border.color: root.open ? Theme.accent : "transparent"
                border.width: Theme.borderWidth
            }

            Swatch {
                id: current

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                name: root.value
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: current.right
                anchors.leftMargin: 8
                anchors.right: chevron.left
                anchors.rightMargin: 6
                text: root.title(root.value)
                elide: Text.ElideRight
            }

            Icon {
                id: chevron

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 10
                text: root.open ? Icons.chevronUp : Icons.chevronDown
                color: Theme.subtext
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        visible: root.open
        implicitHeight: Math.min(220, list.contentHeight + 8)
        radius: Theme.smallRadius
        color: Theme.cardBg

        ListView {
            id: list

            anchors.fill: parent
            anchors.margins: 4
            clip: true
            model: root.entries
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: root.entries.indexOf(root.value)
            onVisibleChanged: if (visible) positionViewAtIndex(Math.max(0, currentIndex), ListView.Center)

            delegate: MouseArea {
                id: entry

                required property string modelData

                width: list.width - 10
                height: 28
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.picked(modelData);
                    root.open = false;
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.smallRadius
                    color: entry.modelData === root.value ? Theme.selectedFill : entry.containsMouse ? Theme.hoverBg : "transparent"
                }

                Swatch {
                    id: swatch

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    name: entry.modelData
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: swatch.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    text: root.title(entry.modelData)
                    color: entry.modelData === root.value ? Theme.accent : Theme.foreground
                    elide: Text.ElideRight
                }
            }
        }

        ScrollBar {
            flick: list
        }
    }

    // A round swatch of Theme.named(name), outlined so background colors show on the window; the
    // default choice ("") in defaultColor, else an empty ring
    component Swatch: Rectangle {
        property string name

        width: 14
        height: 14
        radius: 7
        color: name === "" ? root.defaultColor : (Theme.named(name) ?? "transparent")
        border.color: Theme.faintText
        border.width: 1
    }
}
