import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config
import qs.services

// What the lock screen shows on one screen: the background, and on the main screen the
// clock and date top right and the avatar and password in a centered card. Laid out like
// the login screen (sddm/kuvk/Main.qml), with the colors from Settings > Lock Screen.
// Keys typed on any screen go to the password: Hyprland gives the keyboard to one of the
// lock surfaces, not always the main one.
Item {
    id: root

    required property ShellScreen screen
    // Settings' preview: no keyboard, the field shows its hint, and the clock and password
    // show on its screen
    property bool preview: false
    property bool mainOverride: false

    readonly property bool main: {
        if (mainOverride || screen?.name === Lock.mainScreen)
            return true;
        // the main screen is gone (or never known): the first real one
        const screens = Quickshell.screens.filter(s => s.name && s.name !== "FALLBACK");
        return !screens.some(s => s.name === Lock.mainScreen) && screens[0] === screen;
    }

    property date now: new Date()
    // bumped at each lock, so a changed wallpaper is read again
    property int version: 0

    function tint(name: string): color {
        return Theme[name] ?? Theme.text;
    }

    function takeFocus(): void {
        if (!preview)
            keys.forceActiveFocus();
    }

    Timer {
        interval: 1000
        running: Lock.locked || root.preview
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Connections {
        target: Lock

        function onLockedChanged(): void {
            if (Lock.locked) {
                root.version++;
                root.takeFocus();
            }
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

    // Settings > Lock Screen > Style: the wallpaper, or an image of your own (the wallpaper
    // when none is chosen or it can't be read)
    Image {
        readonly property string wallpaper: Quickshell.env("HOME") + "/.local/state/wallpaper/current"
        readonly property bool useImage: Config.lockStyle === "image" && Config.lockImage !== "" && Config.lockImage !== failedImage
        // an image that couldn't be read; choosing another one tries again
        property string failedImage: ""

        anchors.fill: parent
        source: "file://" + (useImage ? Config.lockImage : wallpaper) + "?v=" + root.version
        onStatusChanged: if (status === Image.Error && useImage) failedImage = Config.lockImage
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root.width
        sourceSize.height: root.height
        asynchronous: false
        cache: false
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
                // a held key repeats while a woken monitor stalls the compositor: only one
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
            onPositionChanged: {
                idle = false;
                idleTimer.restart();
            }

            Timer {
                id: idleTimer

                interval: 5000
                running: !root.preview
                onTriggered: pointer.idle = true
            }
        }
    }

    // Clock and date, top right (Settings > Lock Screen > Clock and date)
    Item {
        anchors.fill: parent
        visible: root.main && Config.lockClock

        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 10
            anchors.rightMargin: 30
            text: Qt.formatDateTime(root.now, "HH:mm")
            color: root.tint(Config.lockClockColor)
            font.family: Theme.font
            font.pixelSize: 96
            font.weight: Font.Medium
        }

        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 120
            anchors.rightMargin: 30
            text: Qt.formatDateTime(root.now, "dddd, d MMMM yyyy")
            color: root.tint(Config.lockClockColor)
            font.family: Theme.font
            font.pixelSize: 37
        }
    }

    // Avatar and password: a 380x300 box in the middle, the avatar's center 45 px above the
    // screen's center, the field's 85 px below
    Rectangle {
        anchors.centerIn: parent
        visible: root.main
        width: 380
        height: 300
        radius: 6
        color: Config.lockBox ? Theme.alpha(root.tint(Config.lockBoxColor), Config.lockBoxOpacity / 100) : "transparent"
        border.width: Config.lockBox ? 2 : 0
        border.color: root.tint(Config.lockBoxOutlineColor)

        // Settings > Lock Screen > Avatar: ~/.face
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -45
            visible: Config.lockAvatar
            width: 139
            height: 139

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.tint(Config.lockAvatarColor)
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
                color: root.tint(Config.lockBoxColor)
                font.family: Theme.iconFont
                font.pixelSize: 56
            }
        }

        Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 85
            width: 260
            height: 36
            // a box with the windows' corners (Hyprland's rounding), square in Work-Game
            radius: Theme.radius
            color: Theme.alpha(root.tint(Config.lockInputColor), Config.lockInputOpacity / 100)
            border.width: 1
            border.color: root.tint(Lock.failed ? Config.lockFailColor : (Lock.authenticating ? Config.lockCheckColor : Config.lockInputOutlineColor))

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

            // The typed password as dots
            Text {
                anchors.centerIn: parent
                width: parent.width - 32
                horizontalAlignment: Text.AlignHCenter
                visible: !root.preview && Lock.password !== ""
                text: "●".repeat(Lock.password.length)
                color: root.tint(Config.lockDotsColor)
                font.family: Theme.font
                font.pixelSize: 11
                font.letterSpacing: 3
                elide: Text.ElideLeft
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 24
                horizontalAlignment: Text.AlignHCenter
                visible: root.preview || Lock.password === ""
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: Lock.failed && !root.preview ? "<i>ACCESS DENIED</i>" : `<i>\u{f033e}  Logged in as </i><b><font color="${root.tint(Config.lockUserColor)}">${Lock.userName}</font></b>`
                color: root.tint(Lock.failed && !root.preview ? Config.lockFailColor : Config.lockTextColor)
                font.family: Theme.font
                font.pixelSize: 14
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: field.bottom
            anchors.topMargin: 8
            visible: Lock.capsLock && !root.preview
            text: "Caps Lock is on"
            color: root.tint(Config.lockCapsColor)
            font.family: Theme.font
            font.pixelSize: 12
        }
    }
}
