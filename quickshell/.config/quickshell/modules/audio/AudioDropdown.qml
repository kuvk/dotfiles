import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services

// Sound: the output's switch in the header, then for
// output and input a label with the volume beside it, the slider, and the devices to choose
// from; then each app's volume
Dropdown {
    id: root

    name: "audio"
    contentWidth: 360

    Hero {
        icon: Audio.icon
        iconColor: Hues.audio
        title: "Audio"
        status: Audio.muted ? "Muted" : (Audio.sink ? Audio.nodeName(Audio.sink) : "No output")

        Switch {
            checked: !Audio.muted
            onToggled: Audio.toggleMute(Audio.sink)
        }
    }

    Separator {}

    SectionLabel {
        text: "Output"
        value: `${Math.round(Audio.volume * 100)}%`
    }

    SliderRow {
        value: Audio.volume
        to: 1.2
        muted: Audio.muted
        onMoved: v => Audio.setVolume(Audio.sink, v)
    }

    Repeater {
        model: Audio.sinks

        ListItem {
            required property PwNode modelData

            icon: Icons.volumeHigh
            label: Audio.nodeName(modelData)
            highlighted: modelData === Audio.sink
            implicitHeight: 34
            onClicked: Audio.setDefaultSink(modelData)
        }
    }

    Separator {
        visible: Audio.source !== null
    }

    RowLayout {
        Layout.fillWidth: true
        visible: Audio.source !== null

        Caption {
            Layout.fillWidth: true
            text: "Input"
        }

        IconButton {
            icon: Audio.micMuted ? Icons.micMuted : Icons.mic
            color: Theme.labelText
            size: 18
            tooltip: Audio.micMuted ? "Unmute" : "Mute"
            onClicked: Audio.toggleMute(Audio.source)
        }

        Caption {
            Layout.rightMargin: 6
            text: Audio.micMuted ? "Muted" : `${Math.round((Audio.source?.audio?.volume ?? 0) * 100)}%`
        }
    }

    SliderRow {
        visible: Audio.source !== null
        value: Audio.source?.audio?.volume ?? 0
        to: 1.2
        muted: Audio.micMuted
        onMoved: v => Audio.setVolume(Audio.source, v)
    }

    Repeater {
        model: Audio.sources

        ListItem {
            required property PwNode modelData

            icon: Icons.mic
            label: Audio.nodeName(modelData)
            highlighted: modelData === Audio.source
            implicitHeight: 34
            onClicked: Audio.setDefaultSource(modelData)
        }
    }

    Separator {
        visible: Audio.streams.length > 0
    }

    Caption {
        visible: Audio.streams.length > 0
        text: "Applications"
    }

    // Each app: its mute button, name and volume, the slider under them
    Repeater {
        model: Audio.streams

        ColumnLayout {
            id: stream

            required property PwNode modelData
            readonly property bool muted: modelData.audio?.muted ?? false

            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                spacing: 8

                IconButton {
                    icon: stream.muted ? Icons.volumeMuted : Icons.volumeHigh
                    color: Theme.foreground
                    size: 22
                    tooltip: stream.muted ? "Unmute" : "Mute"
                    onClicked: Audio.toggleMute(stream.modelData)
                }

                StyledText {
                    Layout.fillWidth: true
                    text: stream.modelData.properties["application.name"] ?? Audio.nodeName(stream.modelData)
                    elide: Text.ElideRight
                }

                Caption {
                    Layout.rightMargin: 6
                    text: `${Math.round((stream.modelData.audio?.volume ?? 0) * 100)}%`
                }
            }

            SliderRow {
                value: stream.modelData.audio?.volume ?? 0
                to: 1.2
                muted: stream.muted
                onMoved: v => Audio.setVolume(stream.modelData, v)
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
