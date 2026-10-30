import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.config
import qs.services

// Now playing: cover, title, progress and controls for Media.active, and
// with several players, a row per player to switch to it or play/pause it
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

        ColumnLayout {
            Layout.fillWidth: true
            visible: Media.players.length > 1
            spacing: 2

            Repeater {
                model: Media.players.length > 1 ? Media.players : []

                MouseArea {
                    id: playerRow

                    required property MprisPlayer modelData
                    readonly property bool current: modelData === root.player

                    Layout.fillWidth: true
                    implicitHeight: 36
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Media.pinned = modelData

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.smallRadius
                        color: playerRow.containsMouse ? Theme.hoverBg : "transparent"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 2
                        spacing: 10

                        Icon {
                            Layout.preferredWidth: 18
                            text: Media.iconFor(playerRow.modelData)
                            color: playerRow.current ? Theme.highlight : Theme.subtext0
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                const p = playerRow.modelData;
                                const track = p.trackTitle || Media.fileName(p.metadata?.["xesam:url"]);
                                return track ? `${p.identity} · ${track}` : p.identity;
                            }
                            color: playerRow.current ? Theme.highlight : Theme.text
                            elide: Text.ElideRight
                        }

                        IconButton {
                            size: 28
                            icon: playerRow.modelData.isPlaying ? Icons.pause : Icons.play
                            color: playerRow.modelData.isPlaying ? Theme.highlight : Theme.overlay1
                            enabled: playerRow.modelData.canTogglePlaying
                            onClicked: {
                                // starting a player also switches the card to it
                                if (!playerRow.modelData.isPlaying)
                                    Media.pinned = playerRow.modelData;
                                playerRow.modelData.togglePlaying();
                            }
                        }
                    }
                }
            }
        }
    }
}
