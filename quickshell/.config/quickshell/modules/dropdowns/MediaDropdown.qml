import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

Dropdown {
    id: root

    name: "media"
    contentWidth: 380

    // Left/Right switch between players
    onKeyPressed: event => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            Media.step(event.key === Qt.Key_Left ? -1 : 1);
            event.accepted = true;
        }
    }

    MediaCard {
        Layout.fillWidth: true
    }
}
