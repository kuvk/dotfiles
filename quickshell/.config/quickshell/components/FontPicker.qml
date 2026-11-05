import QtQuick
import QtQuick.Layouts
import qs.config

// Searchable list of installed font families (Settings > Fonts). Each entry
// is drawn in its own font. `nerdOnly` limits the list to Nerd Fonts;
// `allowAll` shows a switch to lift that limit.
ColumnLayout {
    id: root

    property string value
    property bool nerdOnly: false
    property bool allowAll: true
    property string sample: "The quick brown fox 0123"
    property string query: ""
    signal picked(string family)

    readonly property var families: Qt.fontFamilies()
    readonly property bool installed: families.includes(value)
    readonly property var shown: {
        const q = query.toLowerCase();
        const nerd = f => /Nerd Font/.test(f);
        // Nerd Fonts first (Symbols Nerd Font leading), then the rest
        const list = families.filter(f => (!nerdOnly || nerd(f)) && (!q || f.toLowerCase().includes(q)));
        return list.sort((a, b) => {
            const rank = f => f.startsWith("Symbols Nerd Font") ? 0 : nerd(f) ? 1 : 2;
            return rank(a) - rank(b) || a.localeCompare(b);
        });
    }

    Layout.fillWidth: true
    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        StyledText {
            Layout.fillWidth: true
            text: root.installed ? root.value : `${root.value} (not installed, using a fallback)`
            color: root.installed ? Theme.text : Theme.peach
            font.family: root.value
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        StyledText {
            visible: root.allowAll
            text: "Nerd Fonts only"
            color: Theme.subtext0
            font.pixelSize: Theme.fontSize - 1
        }

        Switch {
            visible: root.allowAll
            checked: root.nerdOnly
            onToggled: root.nerdOnly = !root.nerdOnly
        }
    }

    // Filter
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 32
        radius: Theme.smallRadius
        color: Theme.cardBg
        border.color: input.activeFocus ? Theme.highlight : "transparent"
        border.width: Theme.borderWidth

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            clip: true
            onTextChanged: root.query = text

            StyledText {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: input.text === "" && !input.activeFocus
                text: `Search ${root.shown.length} fonts`
                color: Theme.overlay1
            }
        }
    }

    ListView {
        id: list

        Layout.fillWidth: true
        implicitHeight: 168
        clip: true
        model: root.shown
        boundsBehavior: Flickable.StopAtBounds

        delegate: MouseArea {
            id: entry

            required property string modelData

            width: list.width
            height: 28
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.picked(modelData)

            Rectangle {
                anchors.fill: parent
                radius: Theme.smallRadius
                color: entry.modelData === root.value ? Theme.alpha(Theme.highlight, 0.2) : entry.containsMouse ? Theme.hoverBg : "transparent"
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 8
                width: parent.width * 0.45
                text: entry.modelData
                color: entry.modelData === root.value ? Theme.highlight : Theme.text
                elide: Text.ElideRight
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 8
                width: parent.width * 0.5
                horizontalAlignment: Text.AlignRight
                text: root.sample
                color: Theme.subtext0
                font.family: entry.modelData
                elide: Text.ElideRight
            }
        }
    }
}
