import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// "‹ value ›" selector, the value a step smaller than option labels' text; emits step(-1 | 1).
// The keyboard: Left / Right or Ctrl+H / L step it; Up / Down move on (Nav).
Item {
    id: root

    property alias text: label.text
    signal step(int delta)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    opacity: enabled ? 1 : 0.4
    activeFocusOnTab: enabled
    Keys.onPressed: event => {
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (event.key === Qt.Key_Left || (ctrl && event.key === Qt.Key_H)) {
            root.step(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || (ctrl && event.key === Qt.Key_L)) {
            root.step(1);
            event.accepted = true;
        }
    }

    RowLayout {
        id: row

        anchors.fill: parent
        spacing: 4

        IconButton {
            size: 26
            icon: Icons.chevronLeft
            enabled: root.enabled
            activeFocusOnTab: false
            onClicked: root.step(-1)
        }

        StyledText {
            id: label

            Layout.preferredWidth: 170
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.smallSize
        }

        IconButton {
            size: 26
            icon: Icons.chevronRight
            enabled: root.enabled
            activeFocusOnTab: false
            onClicked: root.step(1)
        }
    }

    FocusRing {}
}
