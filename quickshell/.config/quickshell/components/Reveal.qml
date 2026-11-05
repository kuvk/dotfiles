import QtQuick
import qs.config

// Animated 0..1 value that follows `shown`. Lives in an Item so the
// animation works inside non-visual objects (windows, scopes).
Item {
    id: root

    property bool shown: false
    property real duration: Theme.animDuration
    property int easing: Easing.OutCubic
    property real value: shown ? 1 : 0

    visible: false

    Behavior on value {
        NumberAnimation {
            duration: root.duration
            easing.type: root.easing
        }
    }
}
