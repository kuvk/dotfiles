import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Internet speed test: download and upload dials in Mb/s with ping and jitter under them.
// The dials follow Omarchy's speed test overlay (shell/Ui/SpeedTestOverlay.qml,
// github.com/basecamp/omarchy, MIT): open 270° arcs, a tick ring, a needle fading toward
// the pivot, a sweep to full scale on open. The measuring is network.py speedtest
// (Cloudflare's speed endpoints).
NetworkOverlay {
    id: root

    shown: Panels.speedTest
    layerName: "quickshell-speedtest"
    onCloseRequested: Panels.speedTest = false

    readonly property var speed: Network.speed
    readonly property bool running: Network.testing
    readonly property bool failed: speed.phase === "error"

    // Full scale of both dials: starts at 100 and steps up when a reading nears the top
    readonly property var scaleStops: [100, 250, 500, 1000, 2500, 5000, 10000]
    property real fullScale: scaleStops[0]

    Behavior on fullScale {
        NumberAnimation {
            duration: Theme.animDuration * 2.6
            easing.type: Easing.OutCubic
        }
    }

    function expandScale(value: real): void {
        for (const stop of scaleStops) {
            if (value <= stop * 0.92) {
                if (stop > fullScale)
                    fullScale = stop;
                return;
            }
        }
        fullScale = scaleStops[scaleStops.length - 1];
    }

    function start(): void {
        fullScale = scaleStops[0];
        Network.startSpeedtest();
        downDial.ignite();
        upDial.ignite();
    }

    onShownChanged: {
        if (shown)
            Qt.callLater(start);
        else
            Network.stopSpeedtest();
    }

    Connections {
        target: Network

        function onSpeedChanged(): void {
            root.expandScale(Math.max(Network.speed.download ?? 0, Network.speed.upload ?? 0));
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: (Network.connection || "Speed test").toUpperCase()
        color: Theme.subtext
        font.pixelSize: Theme.fontSize - 1
        font.weight: Font.Bold
        font.letterSpacing: 2
    }

    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 48

        SpeedDial {
            id: downDial

            fullScale: root.fullScale

            label: "DOWNLOAD"
            value: root.speed.download ?? 0
            live: root.speed.phase === "download"
        }

        SpeedDial {
            id: upDial

            fullScale: root.fullScale

            label: "UPLOAD"
            value: root.speed.upload ?? 0
            live: root.speed.phase === "upload"
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: root.speed.ping !== undefined ? `PING ${root.speed.ping} ms   ·   JITTER ${root.speed.jitter} ms` : "MEASURING PING…"
        color: Theme.subtext
        font.pixelSize: Theme.fontSize - 1
        font.weight: Font.Bold
        font.letterSpacing: 1.2
        opacity: root.failed ? 0 : 1
    }

    // Fades instead of leaving, so nothing moves when a run ends
    TextButton {
        Layout.alignment: Qt.AlignHCenter
        text: "Run again"
        enabled: !root.running
        opacity: root.running ? 0 : 1
        onClicked: root.start()

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animDuration * 1.6
            }
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: 440
        visible: root.failed
        text: `Speed test failed: ${root.speed.message ?? ""}`
        color: Theme.red
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
    }

}
