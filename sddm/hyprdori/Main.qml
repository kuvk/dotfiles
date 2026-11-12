import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import SddmComponents

// Login screen in the look of the lock screen (quickshell/.config/quickshell/modules/lock/LockView.qml):
// its background (the lock screen's, from hyprdori-wallpaper), the avatar and password field in
// the middle, with several users the user's name above the avatar between arrows. The field and
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

    // Avatar and password, at the lock screen's positions: the avatar's center 45 px above the
    // screen's center, the field's 85 px below
    Item {
        id: card

        anchors.centerIn: parent
        visible: Window.active
        width: 380
        height: 300

        // Fades in
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }

        // Only with several users: the name between arrows, above the avatar (or the field)
        Controls {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: avatarItem.visible ? avatarItem.top : field.top
            anchors.bottomMargin: 12
            visible: userModel.count > 1
            framed: false
            label: root.userName
            onStepped: d => root.userIndex = root.step(root.userIndex, d, userModel.count)
        }

        // Settings > Style > Lock screen > Avatar
        Item {
            id: avatarItem

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
                text: "\u{f0004}"
                color: root.c.base
                font.family: root.c.iconFont
                font.pixelSize: 56
            }
        }

        // As the lock screen's and the boot splash's: the background at Settings > Style > Lock screen's
        // opacity, a 2 px accent outline, rounded or square corners there
        Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 85
            implicitWidth: 300
            implicitHeight: 40
            radius: Number(root.c.radius)
            color: Qt.alpha(root.c.input, Number(root.c.inputOpacity))
            border.width: 2
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
                // the typed text stays invisible: the dots below stand for it
                color: "transparent"
                cursorVisible: false
                selectByMouse: false
                clip: true
                focus: true
                onTextEdited: root.failed = false
                onAccepted: root.login()
                Keys.onEscapePressed: text = ""
            }

            // The password as dots, as the lock screen and boot splash draw them (9 px, 4 apart),
            // whatever the font; as many as fit
            Row {
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: Math.min(password.text.length, Math.floor((field.width - 32) / 13))

                    Rectangle {
                        width: 9
                        height: 9
                        radius: 4.5
                        color: root.c.dots
                    }
                }
            }
        }

        // Under the field; it takes no room when off
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: field.bottom
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

                // As the shell's buttons: the background at Settings > Style > Lock screen's opacity with
                // the text color faintly over it, a hairline border that lightens under the cursor
                Rectangle {
                    anchors.fill: parent
                    radius: Number(root.c.radius)
                    color: Qt.alpha(root.c.powerBg, Number(root.c.powerOpacity))
                    border.width: 1
                    border.color: power.containsMouse ? root.c.powerHoverOutline : root.c.powerOutline

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Qt.alpha(root.c.text, power.containsMouse ? 0.08 : 0.04)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: power.modelData.glyph
                    color: root.c.text
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
                    radius: Math.max(0, Number(root.c.radius) - 2)
                    color: root.c.powerBg
                    border.color: root.c.powerOutline

                    Text {
                        id: tip

                        anchors.centerIn: parent
                        text: power.modelData.tip
                        color: root.c.text
                        font.family: root.c.font
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
