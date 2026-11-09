import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// A Wi-Fi network under its section's title (connected, known, other), with its password
// field. After the network rows of Omarchy's network panel (github.com/basecamp/omarchy, MIT).
ColumnLayout {
    id: row

    // the NetworkDropdown: password state and actions
    required property var dropdown
    required property var modelData
    required property int index
    readonly property var net: modelData
    readonly property var previous: index > 0 ? Network.networks[index - 1] : null
    readonly property string group: net.connected ? "connected" : (net.known ? "known" : "other")
    readonly property string previousGroup: !previous ? "" : (previous.connected ? "connected" : (previous.known ? "known" : "other"))
    readonly property bool busyHere: Network.busy && Network.actionSsid === net.ssid
    readonly property bool failed: Network.failureSsid === net.ssid && Network.failureReason !== ""
    readonly property bool passwordOpen: dropdown.passwordSsid === net.ssid
    readonly property bool enterprise: Network.isEnterprise(net.security)
    readonly property bool canForget: net.known && !net.connected

    Layout.fillWidth: true
    spacing: 4

    Caption {
        visible: row.group !== row.previousGroup
        Layout.topMargin: row.index > 0 ? 6 : 0
        text: ({ connected: "CONNECTED", known: "KNOWN NETWORKS", other: "OTHER NETWORKS" })[row.group]
    }

    ListItem {
        id: item

        icon: row.net.connected && Network.restricted ? Icons.wifiAlert : Network.wifiIcon(row.net.signal)
        label: row.net.ssid || "Hidden network"
        sublabel: {
            if (row.busyHere)
                return ({ connect: "Connecting…", disconnect: "Disconnecting…", forget: "Forgetting…" })[Network.actionKind];
            if (row.failed)
                return Network.failureReason;
            if (row.net.connected)
                return Network.connectivity === "portal" ? "Sign-in required" : "Connected";
            return "";
        }
        highlighted: row.net.connected
        enabled: !Network.busy || row.busyHere
        onClicked: dropdown.activate(row.net)

        // Forget a known network (on hover for one with a password); a lock otherwise
        IconButton {
            visible: row.canForget && (!row.net.secured || item.containsMouse)
            icon: Icons.close
            color: Theme.dimText
            tooltip: "Forget"
            size: 26
            onClicked: Network.forget(row.net.ssid)
        }

        Icon {
            visible: row.net.secured && !(row.canForget && item.containsMouse)
            text: Icons.lockOutline
            color: Theme.dimText
            font.pixelSize: Theme.iconSize - 2
            width: 26
            height: 30
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 10
        Layout.rightMargin: 4
        visible: row.passwordOpen && !row.busyHere
        spacing: 6

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            InputField {
                visible: row.enterprise
                placeholder: "Identity (user@domain)"
                text: dropdown.identityText
                active: row.passwordOpen && row.enterprise
                onTextChanged: dropdown.identityText = text
                onCanceled: dropdown.closePassword()
            }

            InputField {
                placeholder: "Password"
                password: true
                text: dropdown.passwordText
                active: row.passwordOpen && !row.enterprise
                onTextChanged: dropdown.passwordText = text
                onAccepted: dropdown.submitPassword(row.net)
                onCanceled: dropdown.closePassword()
            }
        }

        IconButton {
            Layout.alignment: Qt.AlignBottom
            icon: Icons.check
            color: dropdown.passwordText !== "" && (!row.enterprise || dropdown.identityText !== "") ? Theme.accent : Theme.dimText
            onClicked: dropdown.submitPassword(row.net)
        }
    }
}
