import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// A subheader in a Settings page, in the accent, with its hint below and, centered beside
// both on the right, one of:
// - a switch, with `key` (a Config bool): it shows and hides the options under it;
// - `controls` (buttons and the like), when there is nothing under it to fold;
// - an arrow that folds and unfolds the options under it, folded at first.
// `edited` after the switch changes.
ColumnLayout {
    id: section

    property string title
    property string hint: ""
    property string key: ""
    property bool open: false
    default property alias content: body.data
    property alias controls: controlsRow.data
    signal edited

    readonly property bool folds: key === "" && title !== "" && body.children.length > 0

    Layout.fillWidth: true
    Layout.topMargin: 8
    spacing: 12

    // no title: no header, the options show as they are
    RowLayout {
        Layout.fillWidth: true
        visible: section.title !== ""
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: section.title
                color: Theme.accent
                font.weight: Font.Bold
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: section.hint
                color: Theme.overlay1
                font.pixelSize: Theme.fontSize - 2
                elide: Text.ElideMiddle
            }
        }

        RowLayout {
            id: controlsRow

            spacing: 8
        }

        Switch {
            visible: section.key !== ""
            checked: section.key ? Config[section.key] : false
            onToggled: {
                Config[section.key] = !Config[section.key];
                section.edited();
            }
        }

        MouseArea {
            visible: section.folds
            implicitWidth: 28
            implicitHeight: 28
            cursorShape: Qt.PointingHandCursor
            onClicked: section.open = !section.open

            Icon {
                anchors.centerIn: parent
                text: section.open ? Icons.chevronUp : Icons.chevronDown
                color: Theme.subtext0
            }
        }
    }

    ColumnLayout {
        id: body

        Layout.fillWidth: true
        visible: section.key ? Config[section.key] : (section.folds ? section.open : true)
        spacing: 12
    }
}
