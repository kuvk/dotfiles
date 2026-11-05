import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services

// Now playing: cover, title, progress and controls for Media.active
Card {
    id: root

    readonly property var player: Media.active

    visible: player !== null
    implicitHeight: content.implicitHeight + 24

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ClippingRectangle {
                implicitWidth: 64
                implicitHeight: 64
                radius: Theme.smallRadius
                color: Theme.surface1

                Image {
                    id: art

                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 128
                    sourceSize.height: 128
                }

                Icon {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: Media.iconFor(root.player)
                    color: Theme.overlay1
                    font.pixelSize: 24
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: Media.title || "Nothing playing"
                    font.weight: Font.DemiBold
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.player?.trackArtist ?? ""
                    color: Theme.subtext0
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.player?.identity ?? ""
                    color: Theme.overlay1
                    font.pixelSize: Theme.fontSize - 2
                }
            }
        }

        CavaBars {
            Layout.alignment: Qt.AlignHCenter
            visible: Cava.values.length > 0
            barWidth: 8
            maxHeight: 36
            spacing: 4
            color: Theme.highlight
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: (root.player?.lengthSupported ?? false) && root.player.length > 0
            spacing: 2

            StyledSlider {
                Layout.fillWidth: true
                value: root.player?.position ?? 0
                to: Math.max(1, root.player?.length ?? 1)
                color: Theme.highlight
                onMoved: v => {
                    if (root.player?.canSeek)
                        root.player.position = v;
                }
            }

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: Media.formatTime(root.player?.position ?? 0)
                    color: Theme.subtext0
                    font.pixelSize: Theme.fontSize - 2
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: Media.formatTime(root.player?.length ?? 0)
                    color: Theme.subtext0
                    font.pixelSize: Theme.fontSize - 2
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            IconButton {
                icon: Icons.previous
                enabled: root.player?.canGoPrevious ?? false
                onClicked: root.player.previous()
            }

            IconButton {
                size: 40
                icon: root.player?.isPlaying ? Icons.pause : Icons.play
                color: Theme.highlight
                onClicked: root.player.togglePlaying()
            }

            IconButton {
                icon: Icons.next
                enabled: root.player?.canGoNext ?? false
                onClicked: root.player.next()
            }
        }
    }
}
