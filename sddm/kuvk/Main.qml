import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import SddmComponents

// Login screen in the look of the lock screen (theme/.config/theme/templates/hyprlock.conf.tpl):
// wallpaper, clock top right, avatar and password in a centered card. The card and
// controls show on the monitor with the keyboard, which follows the mouse.
Rectangle {
    id: root

    readonly property var c: config
    readonly property int nameRole: 257
    readonly property int iconRole: 260
    readonly property int sessionNameRole: 260

    property int userIndex: Math.max(0, userModel.lastIndex)
    property int sessionIndex: Math.max(0, sessionModel.lastIndex)
    property bool failed: false
    property bool busy: false
    property date now: new Date()

    readonly property string userName: userModel.data(userModel.index(userIndex, 0), nameRole) ?? ""
    readonly property string userIcon: userModel.data(userModel.index(userIndex, 0), iconRole) ?? ""
    readonly property string sessionName: sessionModel.data(sessionModel.index(sessionIndex, 0), sessionNameRole) ?? ""

    function login(): void {
        if (busy || password.text === "")
            return;
        busy = true;
        failed = false;
        sddm.login(userName, password.text, sessionIndex);
    }

    function step(index: int, delta: int, count: int): int {
        return (index + delta + count) % count;
    }

    color: c.base

    Window.onActiveChanged: if (Window.active) password.forceActiveFocus()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Connections {
        target: sddm

        function onLoginFailed(): void {
            root.busy = false;
            root.failed = true;
            password.text = "";
            password.forceActiveFocus();
            shake.restart();
        }
    }

    Image {
        anchors.fill: parent
        source: root.c.background ? "file://" + root.c.background : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }

    // Clock and date, top right, where the lock screen puts them (templates/hyprlock.conf.tpl:
    // 72 pt and 28 pt, which Pango draws at 96 and 37 px; tops 10 and 120 px down, 30 in)
    // (Settings > Lock Screen > Clock and date)
    Item {
        anchors.fill: parent
        visible: Window.active && String(root.c.showClock) !== "false"

        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 10
            anchors.rightMargin: 30
            text: Qt.formatDateTime(root.now, "HH:mm")
            color: root.c.clock
            font.family: root.c.font
            font.pixelSize: 96
            font.weight: Font.Medium
        }

        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 120
            anchors.rightMargin: 30
            text: Qt.formatDateTime(root.now, "dddd, d MMMM yyyy")
            color: root.c.date
            font.family: root.c.font
            font.pixelSize: 37
        }
    }

    // Avatar and password, at the lock screen's positions: a 380x300 box in the middle, the
    // avatar's center 45 px above the screen's center, the field's 85 px below
    Rectangle {
        id: card

        anchors.centerIn: parent
        visible: Window.active
        width: 380
        height: 300
        radius: 6
        // Settings > Lock Screen > Box off: only the avatar and password, no card
        readonly property bool shown: String(root.c.showBox) !== "false"

        color: shown ? Qt.alpha(root.c.box, Number(root.c.boxOpacity)) : "transparent"
        border.width: shown ? 2 : 0
        border.color: root.c.boxOutline

        // Fades in
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }

        // Settings > Lock Screen > Avatar
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -45
            visible: String(root.c.showAvatar) !== "false"
            implicitWidth: 139
            implicitHeight: 139

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.c.avatar
            }

            Image {
                id: avatar

                anchors.centerIn: parent
                width: 135
                height: 135
                source: root.userIcon
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
                text: ""
                color: root.c.box
                font.family: root.c.iconFont
                font.pixelSize: 56
            }
        }

        // Only with several users: under the field
        Controls {
            id: users

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: field.bottom
            anchors.topMargin: 10
            visible: userModel.count > 1
            label: root.userName
            onStepped: d => root.userIndex = root.step(root.userIndex, d, userModel.count)
        }

        Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 85
            implicitWidth: 260
            implicitHeight: 36
            radius: height / 2
            color: Qt.alpha(root.c.input, Number(root.c.inputOpacity))
            border.width: 1
            border.color: root.failed ? root.c.fail : (root.busy ? root.c.check : root.c.inputOutline)

            transform: Translate {
                id: offset
            }

            SequentialAnimation {
                id: shake

                NumberAnimation { target: offset; property: "x"; to: -10; duration: 50 }
                NumberAnimation { target: offset; property: "x"; to: 10; duration: 80 }
                NumberAnimation { target: offset; property: "x"; to: -6; duration: 60 }
                NumberAnimation { target: offset; property: "x"; to: 0; duration: 50 }
            }

            TextInput {
                id: password

                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                color: root.c.dots
                selectByMouse: false
                font.family: root.c.font
                font.pixelSize: 11
                font.letterSpacing: 3
                clip: true
                focus: true
                onTextEdited: root.failed = false
                onAccepted: root.login()
                Keys.onEscapePressed: text = ""
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 24
                horizontalAlignment: Text.AlignHCenter
                visible: password.text === ""
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: root.failed ? "<i>ACCESS DENIED</i>" : `<i>\u{f033e}  Log in as </i><b><font color="${root.c.user}">${root.userName}</font></b>`
                color: root.failed ? root.c.fail : root.c.text
                font.family: root.c.font
                font.pixelSize: 14
            }
        }

        // Under the field (and the user switch); it takes no room when off
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: users.visible ? users.bottom : field.bottom
            anchors.topMargin: 8
            visible: keyboard.capsLock
            text: "Caps Lock is on"
            color: root.c.caps
            font.family: root.c.font
            font.pixelSize: 12
        }
    }

    // Session, bottom left; only with several to choose from
    Controls {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 30
        visible: Window.active && sessionModel.rowCount() > 1
        label: root.sessionName
        onStepped: d => root.sessionIndex = root.step(root.sessionIndex, d, sessionModel.rowCount())
    }

    // Power, bottom right
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 30
        visible: Window.active
        spacing: 8

        Repeater {
            model: [
                { glyph: "\u{f03e6}", tip: "Suspend", enabled: sddm.canSuspend, action: () => sddm.suspend() },
                { glyph: "\u{f0709}", tip: "Reboot", enabled: sddm.canReboot, action: () => sddm.reboot() },
                { glyph: "\u{f0425}", tip: "Shut down", enabled: sddm.canPowerOff, action: () => sddm.powerOff() }
            ]

            MouseArea {
                id: power

                required property var modelData

                visible: modelData.enabled
                width: 40
                height: 40
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: modelData.action()

                // Settings > Lock Screen > Power buttons (older theme.conf files: the box's colors)
                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: Qt.alpha(root.c.powerBg || root.c.box, power.containsMouse ? 0.95 : Number(root.c.powerOpacity || root.c.boxOpacity))
                    border.color: root.c.powerOutline || root.c.boxOutline
                }

                Text {
                    anchors.centerIn: parent
                    text: power.modelData.glyph
                    color: power.containsMouse ? root.c.dots : (root.c.powerIcon || root.c.text)
                    font.family: root.c.iconFont
                    font.pixelSize: 20
                }

                // Tooltip above the button, aligned to its right so it stays on screen
                Rectangle {
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 6
                    anchors.right: parent.right
                    visible: power.containsMouse
                    width: tip.implicitWidth + 16
                    height: tip.implicitHeight + 8
                    radius: 6
                    color: Qt.alpha(root.c.powerBg || root.c.box, 0.95)
                    border.color: root.c.powerOutline || root.c.boxOutline

                    Text {
                        id: tip

                        anchors.centerIn: parent
                        text: power.modelData.tip
                        color: root.c.text
                        font.family: root.c.font
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
