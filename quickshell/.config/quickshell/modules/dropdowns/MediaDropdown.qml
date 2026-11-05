import QtQuick
import QtQuick.Layouts
import qs.components

Dropdown {
    id: root

    name: "media"
    contentWidth: 380

    MediaCard {
        Layout.fillWidth: true
    }
}
