import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// The monitors as tiles to drag into place; they snap to each other's edges (Displays)
// Arrangement
Rectangle {
    // the Displays panel: its monitors, selection and actions
    required property var panel

    id: area

    readonly property var bounds: {
        const on = panel.enabledMons;
        if (on.length === 0)
            return { x: 0, y: 0, w: 1, h: 1 };
        const x = Math.min(...on.map(m => m.x)), y = Math.min(...on.map(m => m.y));
        return {
            x: x,
            y: y,
            w: Math.max(...on.map(m => m.x + m.width)) - x,
            h: Math.max(...on.map(m => m.y + m.height)) - y
        };
    }
    readonly property real factor: Math.min((width - 60) / bounds.w, (height - 40) / bounds.h)
    readonly property real offsetX: (width - bounds.w * factor) / 2
    readonly property real offsetY: (height - bounds.h * factor) / 2

    Layout.fillWidth: true
    implicitHeight: 230
    radius: Theme.smallRadius
    color: Theme.alpha(Theme.darkerBackground, 0.6)

    Repeater {
        model: panel.mons

        Item {
            id: tile

            required property var modelData
            required property int index
            property real dragX: 0
            property real dragY: 0

            visible: modelData.enabled
            x: area.offsetX + (modelData.x - area.bounds.x) * area.factor + dragX
            y: area.offsetY + (modelData.y - area.bounds.y) * area.factor + dragY
            width: modelData.width * area.factor
            height: modelData.height * area.factor
            z: dragArea.pressed ? 2 : 1

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 6
                color: tile.index === panel.selected ? Theme.selectedFill : Theme.lighterBackground
                border.color: tile.index === panel.selected ? Theme.accent : Theme.muted
                border.width: 2

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: tile.modelData.name
                        font.weight: Font.Bold
                        color: tile.index === panel.selected ? Theme.accent : Theme.foreground
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: `${Math.round(tile.modelData.width)}×${Math.round(tile.modelData.height)}`
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }

            MouseArea {
                id: dragArea

                property point start

                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                onPressed: mouse => {
                    panel.selected = tile.index;
                    start = mapToItem(area, mouse.x, mouse.y);
                }
                onPositionChanged: mouse => {
                    const p = mapToItem(area, mouse.x, mouse.y);
                    tile.dragX += p.x - start.x;
                    tile.dragY += p.y - start.y;
                    start = p;
                }
                onReleased: {
                    const m = tile.modelData;
                    const x = m.x + tile.dragX / area.factor;
                    const y = m.y + tile.dragY / area.factor;
                    tile.dragX = 0;
                    tile.dragY = 0;
                    if (Math.abs(x - m.x) > 1 || Math.abs(y - m.y) > 1)
                        panel.move(tile.index, x, y);
                }
            }
        }
    }

    StyledText {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 6
        text: "Drag to arrange"
        color: Theme.faintText
        font.pixelSize: Theme.fontSize - 2
    }
}
