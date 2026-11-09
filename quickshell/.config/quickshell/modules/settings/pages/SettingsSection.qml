import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// A section of a Settings page: a divider above it (none for the page's first), its heading in
// capitals in the text color (as a dropdown's section, a step above its options' labels), its
// hint below if any, then its options.
// While the page doesn't fit the window (the window's foldSections), every section folds: an
// arrow beside the heading (down while folded, up while open), a click on the heading opens or
// folds it; the page's first section starts open, the rest folded.
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
        + (divider.visible ? divider.implicitHeight + 4 + spacing : 0)
        + (header.visible ? header.implicitHeight + spacing : 0)
        + body.implicitHeight

    Layout.fillWidth: true
    Layout.topMargin: 8
    spacing: 12

    // between sections, as in dropdowns
    Separator {
        id: divider

        visible: section.title !== "" && !section.first
    }

    // no title: no heading, the options show as they are
    RowLayout {
        id: header

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

        Icon {
            visible: section.folds
            text: section.open ? Icons.chevronUp : Icons.chevronDown
            color: Theme.subtext
        }

        TapHandler {
            enabled: section.folds
            cursorShape: Qt.PointingHandCursor
            onTapped: section.open = !section.open
        }
    }

    // Folded by its height, not hidden: hidden options would measure nothing, and the page
    // would seem to fit again
    Item {
        Layout.fillWidth: true
        Layout.topMargin: section.showsBody ? 0 : -section.spacing
        implicitHeight: section.showsBody ? body.implicitHeight : 0
        clip: true

        ColumnLayout {
            id: body

            width: parent.width
            spacing: 12
        }
    }
}
