import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import SddmComponents

// Login screen in the look of the lock screen (theme/.config/theme/templates/hyprlock.conf.tpl):
// wallpaper, clock top right, avatar and password in a centered card. The card and
// controls only show on the primary screen.
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

    // Clock, top right
    Column {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 30
        visible: primaryScreen
        spacing: 0

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowBlur: 0.8
        }

        Text {
            anchors.right: parent.right
            text: Qt.formatDateTime(root.now, "HH:mm")
            color: root.c.clock
            font.family: root.c.font
            font.pixelSize: 120
            font.weight: Font.Medium
        }

        Text {
            anchors.right: parent.right
            text: Qt.formatDateTime(root.now, "dddd, d MMMM yyyy")
            color: root.c.clock
            font.family: root.c.font
            font.pixelSize: 33
        }
    }

    // Avatar and password
    Rectangle {
        id: card

        anchors.centerIn: parent
        visible: primaryScreen
        width: 340
        height: box.implicitHeight + 48
        radius: 9
        color: Qt.alpha(root.c.base, 0.75)
        border.color: Qt.alpha(root.c.outline, 0.3)

        // Fades in
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: box

            anchors.centerIn: parent
            spacing: 18

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 139
                implicitHeight: 139

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.c.outline
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
                    color: root.c.base
                    font.family: root.c.iconFont
                    font.pixelSize: 56
                }
            }

            // Only with several users
            Controls {
                Layout.alignment: Qt.AlignHCenter
                visible: userModel.count > 1
                label: root.userName
                onStepped: d => root.userIndex = root.step(root.userIndex, d, userModel.count)
            }

            Rectangle {
                id: field

                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 260
                implicitHeight: 36
                radius: height / 2
                color: Qt.alpha(root.c.subtext, 0.2)
                border.width: 1
                border.color: root.failed ? root.c.red : (root.busy ? root.c.dots : root.c.outline)

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
                    focus: primaryScreen
                    onTextEdited: root.failed = false
                    onAccepted: root.login()
                    Keys.onEscapePressed: text = ""
                    Component.onCompleted: if (primaryScreen) forceActiveFocus()
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    horizontalAlignment: Text.AlignHCenter
                    visible: password.text === ""
                    elide: Text.ElideRight
                    textFormat: Text.StyledText
                    text: root.failed ? "<i>ACCESS DENIED</i>" : `<i>\u{f033e}  Log in as </i><b><font color="${root.c.dots}">${root.userName}</font></b>`
                    color: root.failed ? root.c.red : root.c.text
                    font.family: root.c.font
                    font.pixelSize: 14
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: keyboard.capsLock ? "Caps Lock is on" : " "
                color: root.c.yellow
                font.family: root.c.font
                font.pixelSize: 12
            }
        }
    }

    // Session, bottom left
    Controls {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 30
        visible: primaryScreen
        label: root.sessionName
        onStepped: d => root.sessionIndex = root.step(root.sessionIndex, d, sessionModel.rowCount())
    }

    // Power, bottom right
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 30
        visible: primaryScreen
        spacing: 8

        Repeater {
            model: [
                { glyph: "", enabled: sddm.canSuspend, action: () => sddm.suspend() },
                { glyph: "", enabled: sddm.canReboot, action: () => sddm.reboot() },
                { glyph: "", enabled: sddm.canPowerOff, action: () => sddm.powerOff() }
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

                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: Qt.alpha(root.c.base, power.containsMouse ? 0.95 : 0.75)
                    border.color: Qt.alpha(root.c.outline, 0.3)
                }

                Text {
                    anchors.centerIn: parent
                    text: power.modelData.glyph
                    color: power.containsMouse ? root.c.dots : root.c.text
                    font.family: root.c.iconFont
                    font.pixelSize: 16
                }
            }
        }
    }
}
