import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services

// Sound: the output and input volume, the devices to choose from, and each app's volume
Dropdown {
    id: root

    name: "audio"
    contentWidth: 360

    Hero {
        icon: Audio.icon
        iconColor: Hues.audio
        title: Audio.sink ? Audio.nodeName(Audio.sink) : "No output"
        status: Audio.muted ? "MUTED" : `VOLUME ${Math.round(Audio.volume * 100)}%`
    }

    VolumeRow {
        node: Audio.sink
        icon: Audio.icon
    }

    VolumeRow {
        node: Audio.source
        icon: Audio.micMuted ? Icons.micMuted : Icons.mic
    }

    Separator {}

    Caption {
        text: "OUTPUT"
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

    Separator {
        visible: Audio.sources.length > 0
    }

    Caption {
        visible: Audio.sources.length > 0
        text: "INPUT"
    }

    Repeater {
        model: Audio.sources

        ListItem {
            required property PwNode modelData

            icon: modelData === Audio.source ? Icons.check : Icons.mic
            label: Audio.nodeName(modelData)
            highlighted: modelData === Audio.source
            implicitHeight: 36
            onClicked: Audio.setDefaultSource(modelData)
        }
    }

    Separator {
        visible: Audio.streams.length > 0
    }

    Caption {
        visible: Audio.streams.length > 0
        text: "APPLICATIONS"
    }

    Repeater {
        model: Audio.streams

        ColumnLayout {
            id: stream

            required property PwNode modelData

            Layout.fillWidth: true
            spacing: 2

            Label {
                Layout.fillWidth: true
                text: stream.modelData.properties["application.name"] ?? Audio.nodeName(stream.modelData)
                elide: Text.ElideRight
            }

            VolumeRow {
                node: stream.modelData
                icon: stream.modelData.audio?.muted ? Icons.volumeMuted : Icons.volumeHigh
            }
        }
    }

    FooterLink {
        text: "Volume control"
        onClicked: {
            Panels.dropdown = "";
            System.run(["pavucontrol"]);
        }
    }
}
