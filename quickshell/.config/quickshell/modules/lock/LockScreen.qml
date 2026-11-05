import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Session lock (ext-session-lock, replaces hyprlock + lockscreen.sh).
// A curtain of digital rain drops from the top on every screen; the focused
// screen also gets the clock and password field (same layout as hyprlock.conf).
WlSessionLock {
    id: sessionLock

    locked: Lock.locked

    WlSessionLockSurface {
        id: surface

        readonly property bool isMain: screen?.name === Lock.mainScreen || Lock.mainScreen === ""
        // Blur a still capture of the desktop (Hyprland can't blur lock surfaces)
        readonly property bool blur: Config.lockBlur && !Theme.gamemode && !Lock.instant
        property bool dropped: Lock.instant

        function drop(): void {
            fallback.stop();
            dropped = true;
        }

        // session_lock_xray shows the desktop until the curtain covers it
        color: "transparent"

        // The drop starts once the surface is on screen and the capture is
        // ready (or after a short timeout), otherwise it would finish before
        // the compositor shows the lock.
        function start(): void {
            if (!visible || dropped)
                return;
            if (!blur || capture.hasContent)
                Qt.callLater(drop);
            else
                fallback.start();
        }

        onVisibleChanged: start()
        Component.onCompleted: start()

        Timer {
            id: fallback

            interval: 400
            onTriggered: surface.drop()
        }

        ScreencopyView {
            id: capture

            width: surface.width
            height: surface.height
            visible: false
            live: false
            captureSource: surface.blur ? surface.screen : null
            onHasContentChanged: if (hasContent && surface.visible && !surface.dropped) Qt.callLater(surface.drop)
        }

        Item {
            id: curtain

            width: surface.width
            height: surface.height
            y: surface.dropped && !Lock.unlocking ? 0 : -height
            clip: true

            Behavior on y {
                enabled: !Lock.instant

                NumberAnimation {
                    duration: Lock.unlocking ? 350 : 550
                    easing.type: Lock.unlocking ? Easing.InCubic : Easing.OutQuart
                }
            }

            // Frosted desktop, held still while the curtain slides over it
            MultiEffect {
                visible: surface.blur && capture.hasContent
                y: -curtain.y
                width: surface.width
                height: surface.height
                source: capture
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1
                blurMax: 64
                brightness: -0.15
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.alpha(Theme.crust, Theme.gamemode ? 1 : (surface.blur && capture.hasContent ? 0.55 : 0.94))
            }

            MatrixRain {
                anchors.fill: parent
                visible: Config.lockMatrix
                running: Lock.locked && Config.lockMatrix
            }

            // Glowing bottom edge while the curtain moves
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 2
                color: Theme.green
                opacity: curtain.y < 0 ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }
            }

            // Keyboard: every screen accepts the password, the main one shows it
            Item {
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    Lock.checkCapsLock();
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        Lock.submit();
                    } else if (event.key === Qt.Key_Escape) {
                        Lock.password = "";
                    } else if (event.key === Qt.Key_Backspace) {
                        Lock.password = event.modifiers & Qt.ControlModifier ? "" : Lock.password.slice(0, -1);
                    } else if (event.text.length > 0 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
                        Lock.failed = false;
                        Lock.password += event.text;
                    } else {
                        return;
                    }
                    event.accepted = true;
                }
            }

            // Clock, top right (hyprlock: font 90 / 25, green)
            ColumnLayout {
                visible: surface.isMain
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 30
                spacing: 0

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "black"
                    shadowBlur: 0.8
                }

                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: Qt.formatDateTime(Time.date, "HH:mm")
                    color: Theme.green
                    font.pixelSize: 120
                    font.weight: Font.Medium
                }

                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: Qt.formatDateTime(Time.date, "dddd, d MMMM yyyy")
                    color: Theme.green
                    font.pixelSize: 33
                }
            }

            // Avatar and password, centered
            Rectangle {
                visible: surface.isMain
                anchors.centerIn: parent
                width: 340
                height: box.implicitHeight + 48
                radius: Theme.radius * 1.5
                color: Theme.alpha(Theme.base, 0.75)
                border.color: Theme.alpha(Theme.green, 0.3)

                ColumnLayout {
                    id: box

                    anchors.centerIn: parent
                    spacing: 18

                    // ~/.face, like hyprlock
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 139
                        implicitHeight: 139
                        radius: width / 2
                        color: Theme.green

                        ClippingRectangle {
                            anchors.centerIn: parent
                            width: 135
                            height: 135
                            radius: width / 2
                            color: Theme.surface0

                            Image {
                                id: avatar

                                anchors.fill: parent
                                source: "file://" + Quickshell.env("HOME") + "/.face"
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 270
                                sourceSize.height: 270
                            }

                            Icon {
                                anchors.centerIn: parent
                                visible: avatar.status !== Image.Ready
                                text: Icons.user
                                color: Theme.green
                                font.pixelSize: 56
                            }
                        }
                    }

                    Rectangle {
                        id: field

                        readonly property color stateColor: Lock.authenticating ? Theme.blue : Lock.failed ? Theme.red : Lock.capsLock ? Theme.yellow : Theme.green

                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 260
                        implicitHeight: 36
                        radius: height / 2
                        color: Theme.alpha(Theme.subtext1, 0.2)
                        border.color: stateColor
                        border.width: 1

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        // Shake on a wrong password
                        transform: Translate {
                            id: shake
                        }

                        SequentialAnimation {
                            running: Lock.failed
                            loops: 1

                            NumberAnimation { target: shake; property: "x"; to: -10; duration: 50 }
                            NumberAnimation { target: shake; property: "x"; to: 10; duration: 70 }
                            NumberAnimation { target: shake; property: "x"; to: -6; duration: 60 }
                            NumberAnimation { target: shake; property: "x"; to: 0; duration: 50 }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            width: parent.width - 24
                            horizontalAlignment: Text.AlignHCenter
                            textFormat: Text.StyledText
                            text: {
                                if (Lock.password.length > 0)
                                    return "●".repeat(Math.min(Lock.password.length, 24));
                                if (Lock.failed)
                                    return "<i>ACCESS DENIED</i>";
                                return `<i>${Icons.g(0xf033e)}  Logged in as </i><b><font color="${Theme.blue}">${Quickshell.env("USER")}</font></b>`;
                            }
                            color: Lock.failed && Lock.password.length === 0 ? Theme.red : Lock.password.length > 0 ? Theme.blue : Theme.text
                            font.pixelSize: Lock.password.length > 0 ? 10 : 14
                            font.letterSpacing: Lock.password.length > 0 ? 3 : 0
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Lock.capsLock ? "Caps Lock is on" : " "
                        color: Theme.yellow
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
