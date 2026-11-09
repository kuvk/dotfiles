import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// A section of a Settings page: its heading in capitals in the text color (as a dropdown's
// section, a step above its options' labels), its hint below if any, then its options.
// While the page doesn't fit the window (the window's foldSections), the sections become
// dropdowns: a divider between them, an arrow at the heading's right (down while folded, up
// while open, lined up with the steppers' arrows and the switches' knobs), a click on the
// heading opens or folds it with the dropdowns' slide; the page's first starts open, the rest
// folded.
ColumnLayout {
    id: section

    property string title
    property string hint: ""
    default property alias content: body.data

    // the page it's on, whose `settings` is the Settings window
    readonly property var page: {
        let item = parent;
        while (item && item.settings === undefined)
            item = item.parent;
        return item;
    }
    readonly property bool folds: title !== "" && (page?.settings?.foldSections ?? false)
    readonly property bool first: parent ? Array.from(parent.children).find(c => c.fullHeight !== undefined) === section : true
    property bool open: first
    readonly property bool showsBody: !folds || open
    // its height with its options shown, folded or not: the window adds these up to see whether
    // the page fits
    readonly property real fullHeight: Layout.topMargin
        + (divider.visible ? divider.implicitHeight + divider.Layout.topMargin + divider.Layout.bottomMargin : 0)
        + (header.visible ? header.implicitHeight + 16 : 0)
        + body.implicitHeight

    Layout.fillWidth: true
    // as dropdowns the divider spaces them, evenly above and below each heading
    Layout.topMargin: folds ? 0 : 8
    // the gaps are the parts' own margins: a folded section leaves none under its heading
    spacing: 0

    Separator {
        id: divider

        Layout.bottomMargin: 14
        visible: section.folds && !section.first
    }

    // no title: no heading, the options show as they are
    Item {
        id: header

        Layout.fillWidth: true
        Layout.bottomMargin: section.showsBody ? 16 : 0
        visible: section.title !== ""
        implicitHeight: headerRow.implicitHeight

        RowLayout {
            id: headerRow

            anchors.fill: parent
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

            // as wide as a stepper's arrow button, so the arrows line up
            Item {
                visible: section.folds
                implicitWidth: 26
                implicitHeight: 26

                Icon {
                    anchors.centerIn: parent
                    text: section.open ? Icons.chevronUp : Icons.chevronDown
                    color: Theme.subtext
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: section.folds
            cursorShape: Qt.PointingHandCursor
            onClicked: section.open = !section.open
        }
    }

    // Folded by its height, not hidden: hidden options would measure nothing, and the page
    // would seem to fit again
    Item {
        Layout.fillWidth: true
        implicitHeight: section.showsBody ? body.implicitHeight : 0
        clip: true

        Behavior on implicitHeight {
            NumberAnimation {
                duration: Theme.animDuration * 1.6
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: body

            width: parent.width
            spacing: 12
        }
    }
}
