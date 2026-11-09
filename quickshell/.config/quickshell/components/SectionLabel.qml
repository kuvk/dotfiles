import QtQuick
import QtQuick.Layouts
import qs.config

// A section's label on the left of a dropdown and its value on the right ("Output" ... "62%")
RowLayout {
    property string text
    property string value

    Layout.fillWidth: true

    Caption {
        Layout.fillWidth: true
        text: parent.text
    }

    Caption {
        Layout.rightMargin: 6
        visible: text !== ""
        text: parent.value
    }
}
