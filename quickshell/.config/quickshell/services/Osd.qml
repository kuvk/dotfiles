pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// What the on-screen display shows (modules/osd/OsdPopup.qml): the volume, the screen's
// brightness or the keyboard light, whichever changed last, then hides after a moment.
// Volume comes live from PipeWire. Brightness and the keyboard light are read from sysfs
// a few times a second: nothing reports their changes, and this catches every source
// (keys, asusd, ROG Control Center, brightnessctl). Quiet while a panel with its own
// slider is open.
Singleton {
    id: root

    property string kind: "" // "volume" | "brightness" | "keyboard"
    property real value: 0 // 0..1
    property bool muted: false
    property bool shown: false

    readonly property string icon: kind === "volume" ? Audio.icon : kind === "keyboard" ? Icons.keyboard : Icons.sun
    readonly property bool quiet: Panels.controlCenter || Panels.dropdown === "audio" || Panels.displays

    function show(newKind: string, newValue: real, newMuted: bool): void {
        if (quiet)
            return;
        kind = newKind;
        value = Math.max(0, Math.min(1, newValue));
        muted = newMuted;
        shown = true;
        hide.restart();
    }

    Timer {
        id: hide

        interval: 1500
        onTriggered: root.shown = false
    }

    // Volume: not at startup, and not when the output device changes (its volume differs)
    property bool audioSettled: false

    Timer {
        id: settle

        interval: 1000
        running: true
        onTriggered: root.audioSettled = true
    }

    Connections {
        target: Audio

        function onSinkChanged(): void {
            root.audioSettled = false;
            settle.restart();
        }

        function onVolumeChanged(): void {
            if (root.audioSettled && Audio.ready)
                root.show("volume", Audio.volume, Audio.muted);
        }

        function onMutedChanged(): void {
            if (root.audioSettled && Audio.ready)
                root.show("volume", Audio.volume, Audio.muted);
        }
    }

    // Brightness and keyboard light: the first backlight and keyboard LED, if any
    property string backlight: ""
    property string keyboardLight: ""

    Process {
        running: true
        command: ["sh", "-c", "ls -d /sys/class/backlight/* 2>/dev/null | head -n1; echo; ls -d /sys/class/leds/*kbd_backlight 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [backlight, keyboard] = text.split("\n\n").map(s => s.trim());
                root.backlight = backlight ?? "";
                root.keyboardLight = keyboard ?? "";
            }
        }
    }

    Timer {
        interval: 300
        running: root.backlight !== "" || root.keyboardLight !== ""
        repeat: true
        onTriggered: {
            if (root.backlight)
                screenLevel.reload();
            if (root.keyboardLight)
                keyboardLevel.reload();
        }
    }

    component Level: FileView {
        id: level

        required property string device
        required property string levelKind
        property int max: 0
        property int last: -1

        path: device ? device + "/brightness" : ""
        onLoaded: {
            const now = parseInt(text());
            if (isNaN(now) || level.max <= 0)
                return;
            // the first reading is where it is, not a change
            if (level.last >= 0 && now !== level.last)
                root.show(level.levelKind, now / level.max, false);
            level.last = now;
        }

        property FileView maxFile: FileView {
            path: level.device ? level.device + "/max_brightness" : ""
            onLoaded: level.max = parseInt(text()) || 0
        }
    }

    Level {
        id: screenLevel

        device: root.backlight
        levelKind: "brightness"
    }

    Level {
        id: keyboardLevel

        device: root.keyboardLight
        levelKind: "keyboard"
    }
}
