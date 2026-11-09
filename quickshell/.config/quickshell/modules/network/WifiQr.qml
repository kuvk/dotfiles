import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// The connected Wi-Fi as a QR code a phone camera can join from, with the password on
// request. After Omarchy's Wi-Fi QR card (shell/plugins/panels/wifiqr,
// github.com/basecamp/omarchy, MIT); network.py qr makes the matrix with qrencode.
NetworkOverlay {
    id: root

    shown: Panels.wifiQr
    layerName: "quickshell-wifiqr"
    onCloseRequested: Panels.wifiQr = false

    readonly property string script: Quickshell.env("HOME") + "/.config/scripts/network.py"
    property var qr: ({}) // { iface, ssid, security, rows }
    readonly property int size: qr.rows?.length ?? 0
    property bool loading: false
    property string error: ""
    // The password is only read when asked for, and dropped on close
    property string password: ""
    property bool passwordShown: false
    property string passwordError: ""

    onShownChanged: {
        qr = {};
        error = "";
        password = "";
        passwordShown = false;
        passwordError = "";
        qrProc.running = false;
        pwProc.running = false;
        if (shown) {
            loading = true;
            qrProc.running = true;
        }
    }

    function togglePassword(): void {
        if (passwordShown) {
            passwordShown = false;
        } else if (password !== "") {
            passwordShown = true;
        } else if (!pwProc.running && qr.iface) {
            passwordError = "";
            pwProc.command = [script, "password", qr.iface];
            pwProc.running = true;
        }
    }

    Process {
        id: qrProc

        command: [root.script, "qr"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.shown)
                    return;
                try {
                    root.qr = JSON.parse(text);
                } catch (e) {}
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (root.shown && text.trim() !== "") root.error = text.trim()
        }
        onExited: code => {
            root.loading = false;
            if (root.shown && code !== 0 && root.error === "")
                root.error = "Could not make the Wi-Fi QR code";
        }
    }

    Process {
        id: pwProc

        stdout: StdioCollector {
            onStreamFinished: if (root.shown) root.password = text.trim()
        }
        onExited: code => {
            if (!root.shown)
                return;
            if (code === 0 && root.password !== "")
                root.passwordShown = true;
            else
                root.passwordError = "Could not read the Wi-Fi password";
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: 320
        text: (root.qr.ssid || Network.connection || "Wi-Fi").toUpperCase()
        color: Theme.subtext
        font.pixelSize: Theme.smallSize
        font.weight: Font.Bold
        font.letterSpacing: 2
        horizontalAlignment: Text.AlignHCenter
    }

    // Each module a whole-pixel rectangle: crisp at any scale. White behind it in every
    // theme, as scanners expect dark on light; the matrix has its quiet zone built in.
    Rectangle {
        id: canvas

        readonly property int module: root.size > 0 ? Math.max(4, Math.floor(260 / root.size)) : 0

        Layout.alignment: Qt.AlignHCenter
        visible: root.size > 0 && root.error === ""
        implicitWidth: root.size * module
        implicitHeight: implicitWidth
        color: "white"
        radius: Theme.radius

        Grid {
            anchors.fill: parent
            columns: root.size

            Repeater {
                model: root.size * root.size

                Rectangle {
                    required property int index

                    width: canvas.module
                    height: canvas.module
                    color: root.qr.rows[Math.floor(index / root.size)].charAt(index % root.size) === "1" ? "#111111" : "transparent"
                }
            }
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        visible: root.loading
        text: "Making the QR code…"
        color: Theme.subtext
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: 320
        visible: root.error !== ""
        text: root.error
        color: Theme.red
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        visible: canvas.visible
        text: "Scan to join this network"
        color: Theme.subtext
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: 320
        visible: canvas.visible && root.qr.security !== "nopass"
        text: root.passwordError || (root.passwordShown ? root.password : "Show password")
        color: root.passwordError ? Theme.red : (root.passwordShown ? Theme.foreground : Theme.accent)
        wrapMode: Text.WrapAnywhere
        horizontalAlignment: Text.AlignHCenter

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.togglePassword()
        }
    }
}
