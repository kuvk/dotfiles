import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services

// Now playing: cover, title, progress and controls for Media.active. With
// several players each is a card of its own: the arrows (or Left/Right in
// the dropdown and Control Center) switch between them, with a slide.
Card {
    id: root

    readonly property var player: Media.active

    visible: player !== null
    implicitHeight: content.implicitHeight + 24
    clip: true

    // slide in from the side we switched to; automatic switches only fade
    onPlayerChanged: {
        if (Theme.animDuration > 0) {
            shift.x = player !== null && player === Media.stepTarget ? Media.lastStep * 48 : 0;
            slide.restart();
        }
    }

    ParallelAnimation {
        id: slide

        NumberAnimation {
            target: shift
            property: "x"
            to: 0
            duration: Theme.animDuration * 1.6
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: content
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.animDuration * 1.6
        }
    }

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 10
        transform: Translate {
            id: shift
        }

        // Player switcher: arrows and a dot per player
        RowLayout {
            Layout.fillWidth: true
            visible: Media.players.length > 1
            spacing: 4

            IconButton {
                size: 24
                icon: Icons.chevronLeft
                color: Theme.overlay1
                onClicked: Media.step(-1)
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: dots.implicitHeight

                Row {
                    id: dots

                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: Media.players

                        Rectangle {
                            required property var modelData

                            anchors.verticalCenter: parent.verticalCenter
                            width: modelData === root.player ? 16 : 6
                            height: 6
                            radius: 3
                            color: modelData === root.player ? Theme.highlight : Theme.overlay0

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.animDuration
                                }
                            }
                        }
                    }
                }
            }

            IconButton {
                size: 24
                icon: Icons.chevronRight
                color: Theme.overlay1
                onClicked: Media.step(1)
            }
        }

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

        // fixed height and full width, so the card never changes size
        CavaBars {
            Layout.fillWidth: true
            visible: Config.cava
            implicitHeight: 36
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
