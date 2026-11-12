import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config
import qs.services

// What the lock screen shows on one screen: the background, and on the main screen (the one the
// mouse is on) the avatar and the password field in the middle. Laid out like the login screen
// (sddm/hyprdori/Main.qml), in the theme's colors; the field as on the boot splash: the
// background at Settings > Style > Lock screen's opacity, a 2 px accent outline, its corners rounded or
// square there.
// Keys typed on any screen go to the password: Hyprland gives the keyboard to one of the
// lock surfaces, not always the main one.
Item {
    id: root

    required property ShellScreen screen
    // Settings' preview: no keyboard, and the avatar and password show on its screen
    property bool preview: false
    property bool mainOverride: false

    readonly property bool main: {
        if (mainOverride || screen?.name === Lock.mainScreen)
            return true;
        // the main screen is gone (or never known): the first real one
        const screens = Quickshell.screens.filter(s => s.name && s.name !== "FALLBACK");
        return !screens.some(s => s.name === Lock.mainScreen) && screens[0] === screen;
    }

    function takeFocus(): void {
        if (!preview)
            keys.forceActiveFocus();
    }

    Connections {
        target: Lock

        function onLockedChanged(): void {
            if (Lock.locked)
                root.takeFocus();
        }

        function onFailedChanged(): void {
            if (Lock.failed)
                shake.restart();
        }
    }

    // A wake brings the monitors back one by one; the keyboard may land anywhere
    Connections {
        target: Quickshell

        function onScreensChanged(): void {
            Qt.callLater(root.takeFocus);
        }
    }

    Component.onCompleted: Qt.callLater(takeFocus)

    // The theme's background, or the chosen image (Settings > Style > Lock screen; services/Lock.qml).
    // Already no larger than the largest screen (hyprdori-wallpaper lock), so it loads at once,
    // before the lock is up; decoded once for every screen (Qt's image cache).
    Image {
        anchors.fill: parent
        source: Lock.background
        onStatusChanged: if (status === Image.Error && Lock.backgroundPath === Config.lockImage) Lock.failedImage = Config.lockImage
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
    }

    // Takes the keys; a click anywhere gives it the keyboard again. The pointer hides after
    // 5 s without moving and shows again when it moves.
    Item {
        id: keys

        anchors.fill: parent
        focus: !root.preview

        Keys.onPressed: event => {
            event.accepted = true;
            if (!Lock.locked)
                return;
            Lock.checkCapsLock();
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                Lock.submit();
            } else if (event.key === Qt.Key_Escape) {
                Lock.clearPassword();
            } else if (Lock.authenticating) {
                return;
            } else if (event.key === Qt.Key_Backspace) {
                Lock.password = event.modifiers & Qt.ControlModifier ? "" : Lock.password.slice(0, -1);
            } else if (event.text !== "" && event.text >= " " && !event.isAutoRepeat) {
                // no auto-repeat: a stall after wake would repeat a held key
                Lock.failed = false;
                Lock.password += event.text;
            }
        }

        MouseArea {
            id: pointer

            property bool idle: false

            anchors.fill: parent
            hoverEnabled: !root.preview
            cursorShape: idle ? Qt.BlankCursor : Qt.ArrowCursor
            onClicked: root.takeFocus()
            // the avatar and password come to the monitor the mouse is on
            onEntered: if (!root.preview && Lock.locked) Lock.mainScreen = root.screen.name
            onPositionChanged: {
                idle = false;
                idleTimer.restart();
                if (!root.preview && Lock.locked)
                    Lock.mainScreen = root.screen.name;
            }

            Timer {
                id: idleTimer

                interval: 5000
                running: !root.preview
                onTriggered: pointer.idle = true
            }
        }
    }

    // Avatar and password, at the login screen's positions: the field centered on the screen,
    // the avatar's center 130 px above the field's. Sized for each screen as the default
    // background is (hyprdori-logo-wallpaper, made for the largest screen and shown to cover):
    // as given on a 1920x1080 screen, larger or smaller with the screen, so the field keeps its
    // size against the logos on every monitor.
    Item {
        anchors.centerIn: parent
        visible: root.main
        width: 380
        height: 300
        scale: Math.max(root.width / 1920, root.height / 1200)

        // Settings > Style > Lock screen > Avatar: ~/.face
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -130
            visible: Config.lockAvatar
            width: 139
            height: 139

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.border
            }

            Image {
                id: avatar

                anchors.centerIn: parent
                width: 135
                height: 135
                source: "file://" + Quickshell.env("HOME") + "/.face"
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 270
                sourceSize.height: 270
                visible: false
            }

            Rectangle {
                id: avatarMask

                anchors.fill: avatar
                radius: width / 2
                visible: false
                layer.enabled: true
            }

            MultiEffect {
                anchors.fill: avatar
                visible: avatar.status === Image.Ready
                source: avatar
                maskEnabled: true
                maskSource: ShaderEffectSource {
                    sourceItem: avatarMask
                }
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            Text {
                anchors.centerIn: parent
                visible: avatar.status !== Image.Ready
                text: "\u{f0004}"
                color: Theme.background
                font.family: Theme.iconFont
                font.pixelSize: 56
            }
        }

        Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 0
            width: 338
            height: 38
            // the windows' corner radius (Settings > Style), square at 0
            radius: Config.radius
            // the background with 5% of the text color (Omarchy's field), at Settings' opacity
            color: Theme.alpha(Theme.mix(Theme.background, Theme.foreground, 0.05), Config.lockInputOpacity / 100)
            border.width: 2
            border.color: (Lock.failed ? Theme.red : (Lock.authenticating ? Theme.dimText : Theme.border))

            transform: Translate {
                id: offset
            }

            SequentialAnimation {
                id: shake

                NumberAnimation {
                    target: offset
                    property: "x"
                    to: -10
                    duration: 50
                }

                NumberAnimation {
                    target: offset
                    property: "x"
                    to: 10
                    duration: 80
                }

                NumberAnimation {
                    target: offset
                    property: "x"
                    to: -6
                    duration: 60
                }

                NumberAnimation {
                    target: offset
                    property: "x"
                    to: 0
                    duration: 50
                }
            }

            // The typed password as dots, drawn as the boot splash and login screen draw them
            // (9 px, 4 apart) rather than a font's character, so their size never follows the
            // font; as many as fit
            Row {
                anchors.centerIn: parent
                visible: !root.preview
                spacing: 4

                Repeater {
                    model: Math.min(Lock.password.length, Math.floor((field.width - 32) / 13))

                    Rectangle {
                        width: 9
                        height: 9
                        radius: 4.5
                        color: Theme.foreground
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: field.bottom
            anchors.topMargin: 8
            visible: Lock.capsLock && !root.preview
            text: "Caps Lock is on"
            color: Theme.yellow
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }
}
