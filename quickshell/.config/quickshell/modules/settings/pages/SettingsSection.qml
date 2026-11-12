import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// A section of a Settings page: its heading in capitals in the text color (as a dropdown's
// section, a step above its options' labels), its hint below if any, then its options.
// While the page doesn't fit the window (the window's foldSections), the sections become
// dropdowns: an arrow at the heading's right (down while folded, up while open, lined up with
// the steppers' arrows and the switches' knobs), a click on the heading slides its options open
// or shut like the shell's dropdowns, with a divider under them while open; the page's first
// starts open, the rest folded.
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
    readonly property var sections: parent ? Array.from(parent.children).filter(c => c.fullHeight !== undefined) : []
    readonly property bool first: sections[0] === section
    readonly property bool last: sections[sections.length - 1] === section
    property bool open: first
    readonly property bool showsBody: !folds || open
    // its height with its options shown, folded or not: the window adds these up to see whether
    // the page fits
    // (as laid out open, without dividers: it mustn't depend on the folding it decides)
    readonly property real fullHeight: 8 + (header.visible ? header.implicitHeight + 16 : 0) + body.implicitHeight

    Layout.fillWidth: true
    Layout.topMargin: folds ? 12 : 8
    // the gap under the heading is inside the part that slides, so a section folds in one move
    spacing: 0

    // no title: no heading, the options show as they are
    Item {
        id: header

        Layout.fillWidth: true
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
            id: foldButton

            anchors.fill: parent
            enabled: section.folds
            cursorShape: Qt.PointingHandCursor
            onClicked: section.open = !section.open
            // the keyboard: Enter or Space folds or unfolds it
            activeFocusOnTab: section.folds
            Keys.onPressed: event => {
                if (Nav.isActivate(event)) {
                    section.open = !section.open;
                    event.accepted = true;
                }
            }

            // around the title, which starts at the edge
            FocusRing {
                leftOutset: 8
                topOutset: 4
                bottomOutset: 4
            }
        }
    }

    // Folded by its height, not hidden: hidden options would measure nothing, and the page
    // would seem to fit again. Shut, it's also transparent, so nothing shows at its edge.
    Item {
        Layout.fillWidth: true
        implicitHeight: section.showsBody ? reveal.implicitHeight : 0
        // shut, its controls are out of the keyboard's reach too (Nav)
        enabled: section.showsBody
        opacity: implicitHeight > 0.5 ? 1 : 0
        clip: true

        Behavior on implicitHeight {
            NumberAnimation {
                duration: Theme.animDuration * 1.6
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: reveal

            width: parent.width
            spacing: 0

            ColumnLayout {
                id: body

                Layout.fillWidth: true
                Layout.topMargin: header.visible ? 16 : 0
                spacing: 12
            }

            // under an open section's options while the sections are dropdowns
            Separator {
                Layout.topMargin: 14
                visible: section.folds && !section.last
            }
        }
    }
}
