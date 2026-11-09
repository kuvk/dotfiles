import QtQuick
import qs.config

// On/off: on is the selected fill without a border, off the idle fill with a hairline border;
// the knob in the text color (darkened while off). Round, square with the square shape.
MouseArea {
    id: root

    property bool checked: false
    signal toggled

    implicitWidth: Math.round(implicitHeight * 1.9)
    implicitHeight: Math.max(18, Math.round(22 * Theme.textScale))
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: toggled()

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius > 0 ? height / 2 : 0
        color: root.checked ? Theme.selectedFill : Theme.idleFill
        border.width: root.checked ? 0 : Theme.controlBorder
        border.color: Theme.idleBorder

        Behavior on color {
            ColorAnimation {
                duration: Theme.animDuration
            }
        }

        Rectangle {
            readonly property int inset: Math.max(1, Math.round((parent.height - height) / 2))

            x: root.checked ? parent.width - width - inset : inset
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(parent.height * 0.72)
            height: width
            radius: Theme.radius > 0 ? width / 2 : 0
            color: root.checked ? Theme.foreground : Qt.darker(Theme.foreground, 1.25)

            Behavior on x {
                NumberAnimation {
                    duration: Theme.animDuration
                }
            }
        }
    }
}
