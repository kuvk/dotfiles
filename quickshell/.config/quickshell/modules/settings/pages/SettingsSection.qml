import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// A section in a Settings page: a divider above it (none for a page's first), its heading in
// capitals in the text color (as a dropdown's section, a step above its options' labels), its
// hint below if any and, centered beside both on the right, one of:
// - a switch, with `key` (a Config bool): it shows and hides the options under it;
// - `controls` (buttons and the like), when there is nothing under it to fold;
// - an arrow that folds and unfolds the options under it, folded at first;
// - nothing, with `foldable: false`: a heading over options that always show.
// `edited` after the switch changes.
ColumnLayout {
    id: section

    property string title
    property string hint: ""
    property string key: ""
    property bool open: false
    property bool foldable: true
    default property alias content: body.data
    property alias controls: controlsRow.data
    signal edited

    readonly property bool folds: foldable && key === "" && title !== "" && body.children.length > 0

    Layout.fillWidth: true
    Layout.topMargin: 8
    spacing: 12

    // between sections, as in dropdowns
    Separator {
        visible: section.title !== "" && section.parent && section.parent.children[0] !== section
    }

    // no title: no header, the options show as they are
    RowLayout {
        Layout.fillWidth: true
        visible: section.title !== ""
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Caption {
                Layout.fillWidth: true
                text: section.title
                color: Theme.foreground
                font.pixelSize: Theme.fontSize
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: section.hint
                color: Theme.dimText
                font.pixelSize: Theme.captionSize
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
                color: Theme.subtext
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
