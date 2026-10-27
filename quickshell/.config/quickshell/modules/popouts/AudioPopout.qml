import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    name: "audio"
    contentWidth: 360

    SectionHeader {
        title: "Sound"

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: `${Math.round(Audio.volume * 100)}%`
            color: Theme.subtext0
        }
    }

    VolumeRow {
        node: Audio.sink
        icon: Audio.icon
    }

    VolumeRow {
        node: Audio.source
        icon: Audio.micMuted ? Icons.micMuted : Icons.mic
    }

    StyledText {
        text: "Output"
        color: Theme.subtext0
        font.pixelSize: Theme.fontSize - 1
    }

    Repeater {
        model: Audio.sinks

        ListItem {
            required property PwNode modelData

            icon: modelData === Audio.sink ? Icons.check : Icons.volumeHigh
            label: Audio.nodeName(modelData)
            highlighted: modelData === Audio.sink
            implicitHeight: 36
            onClicked: Audio.setDefaultSink(modelData)
        }
    }

    StyledText {
        visible: Audio.streams.length > 0
        text: "Applications"
        color: Theme.subtext0
        font.pixelSize: Theme.fontSize - 1
    }

    Repeater {
        model: Audio.streams

        ColumnLayout {
            id: stream

            required property PwNode modelData

            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: stream.modelData.properties["application.name"] ?? Audio.nodeName(stream.modelData)
                font.pixelSize: Theme.fontSize - 1
            }

            VolumeRow {
                node: stream.modelData
                icon: stream.modelData.audio?.muted ? Icons.volumeMuted : Icons.volumeHigh
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: "Volume control"
        color: Theme.accent2
        horizontalAlignment: Text.AlignRight

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Panels.popout = "";
                System.run(["pavucontrol"]);
            }
        }
    }
}
