import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Text size for this combination of monitors: the shell, GTK apps and kitty. A slider on
// fixed steps with its size in px beside the title. Applied with the panel's other changes.
ColumnLayout {
    id: root

    // the Displays panel: its monitors, selection and actions
    required property var panel
    // the steps, in px; 12 is the default
    readonly property var stops: [9, 10, 11, 12, 14, 16, 20]
    // the step at the panel's size, or the nearest
    readonly property int index: {
        let best = 0;
        for (let i = 1; i < stops.length; i++)
            if (Math.abs(stops[i] - panel.textSize) < Math.abs(stops[best] - panel.textSize))
                best = i;
        return best;
    }

    Layout.fillWidth: true
    spacing: 6

    RowLayout {
        Layout.fillWidth: true

        StyledText {
            Layout.fillWidth: true
            text: "Text size"
            font.weight: Font.DemiBold
        }

        StyledText {
            text: `${root.panel.textSize}px`
            color: Theme.dimText
            font.pixelSize: Theme.captionSize
            font.bold: true
        }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: slider.implicitHeight

        // a notch under each step
        Repeater {
            model: root.stops.length

            Rectangle {
                required property int index

                x: slider.x + 7 + index * (slider.width - 14) / (root.stops.length - 1) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 10
                radius: 1
                color: Theme.dimText
            }
        }

        StyledSlider {
            id: slider

            anchors.left: parent.left
            anchors.right: parent.right
            to: root.stops.length - 1
            value: root.index
            onMoved: v => {
                const step = Math.round(v);
                if (root.stops[step] !== root.panel.textSize) {
                    root.panel.textSize = root.stops[step];
                    root.panel.dirty = true;
                }
            }
        }
    }
}
