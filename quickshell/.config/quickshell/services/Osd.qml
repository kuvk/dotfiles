pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config

// The on-screen display's state (modules/osd/OsdPopup.qml): what changed last, shown for a
// moment. `kinds` says what each OSD shows; the sources below call show(name) when their
// value changes.
Singleton {
    id: root

    // Each OSD by name: an icon, then a `level` (0..1, drawn as a bar; `dim` greys it) or a
    // `label`, and `quiet` while a panel with its own control for it is open. Brightness and
    // the keyboard light get their level from their source.
    readonly property var kinds: ({
            volume: () => ({
                    icon: Audio.icon,
                    level: Audio.volume,
                    dim: Audio.muted,
                    quiet: Panels.controlCenter || Panels.dropdown === "audio"
                }),
            mute: () => ({
                    icon: Audio.muted ? Icons.volumeMuted : Audio.icon,
                    label: Audio.muted ? "Muted" : "Sound on",
                    quiet: Panels.controlCenter || Panels.dropdown === "audio"
                }),
            mic: () => ({
                    icon: Audio.micMuted ? Icons.micMuted : Icons.mic,
                    label: Audio.micMuted ? "Microphone off" : "Microphone on",
                    quiet: Panels.dropdown === "audio"
                }),
            brightness: level => ({
                    icon: Icons.sun,
                    level: level,
                    quiet: Panels.controlCenter || Panels.displays
                }),
            keyboard: level => ({
                    icon: Icons.keyboard,
                    level: level
                }),
            power: kernelName => ({
                    icon: Battery.modeFor(kernelName).icon,
                    label: Battery.modeFor(kernelName).label,
                    quiet: Panels.dropdown === "battery"
                })
        })

    // What's on screen: { icon, level (-1: none), label, dim }
    property var entry: ({ icon: "", level: -1, label: "", dim: false })
    property bool shown: false

    function show(name: string, value: var): void {
        const e = root.kinds[name](value);
        if (e.quiet)
            return;
        root.entry = {
            icon: e.icon,
            level: e.level === undefined ? -1 : Math.max(0, Math.min(1, e.level)),
            label: e.label ?? "",
            dim: e.dim ?? false
        };
        root.shown = true;
        hide.restart();
    }

    Timer {
        id: hide

        interval: 1500
        onTriggered: root.shown = false
    }

    // ------------------------------------------------ Sources

    // Not at startup, or right after the output or input device changes (its volume and
    // mute differ): those aren't the user's changes
    property bool settled: false

    Timer {
        id: settle

        interval: 1000
        running: true
        onTriggered: root.settled = true
    }

    function changed(name: string): void {
        if (root.settled && Audio.ready)
            root.show(name, 0);
    }

    // Volume, mute and the microphone: PipeWire, live
    Connections {
        target: Audio

        function onSinkChanged(): void {
            root.settled = false;
            settle.restart();
        }

        function onSourceChanged(): void {
            root.settled = false;
            settle.restart();
        }

        function onVolumeChanged(): void {
            root.changed("volume");
        }

        function onMutedChanged(): void {
            root.changed("mute");
        }

        function onMicMutedChanged(): void {
            root.changed("mic");
        }
    }

    // Power mode: the kernel's platform_profile where there is one (below): it changes at
    // once, whoever changes it (the mode key, asusd on plugging in or out, the dropdown),
    // while power-profiles-daemon follows a second or more later. Elsewhere the daemon.
    Connections {
        target: PowerProfiles
        enabled: root.platformProfile === ""

        function onProfileChanged(): void {
            if (root.settled)
                root.show("power", "");
        }
    }

    // Brightness and the keyboard light: the first backlight and keyboard LED, read from
    // sysfs a few times a second. Nothing reports their changes, and this catches every
    // source (keys, asusd, ROG Control Center, brightnessctl).
    property string backlight: ""
    property string keyboardLight: ""
    property string platformProfile: ""

    Process {
        running: true
        command: ["sh", "-c", "ls -d /sys/class/backlight/* 2>/dev/null | head -n1; echo; ls -d /sys/class/leds/*kbd_backlight 2>/dev/null | head -n1; echo; ls /sys/firmware/acpi/platform_profile 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [backlight, keyboard, profile] = text.split("\n\n").map(s => s.trim());
                root.backlight = backlight ?? "";
                root.keyboardLight = keyboard ?? "";
                root.platformProfile = profile ?? "";
            }
        }
    }

    Timer {
        interval: 300
        running: root.backlight !== "" || root.keyboardLight !== "" || root.platformProfile !== ""
        repeat: true
        onTriggered: {
            if (root.backlight)
                screenLevel.reload();
            if (root.keyboardLight)
                keyboardLevel.reload();
            if (root.platformProfile)
                profileFile.reload();
        }
    }

    // the first reading is where it is, not a change
    FileView {
        id: profileFile

        property string last: ""

        path: root.platformProfile
        onLoaded: {
            const now = text().trim();
            if (profileFile.last !== "" && now !== profileFile.last)
                root.show("power", now);
            profileFile.last = now;
        }
    }

    component Level: FileView {
        id: level

        required property string device
        required property string kind
        property int max: 0
        property int last: -1

        path: device ? device + "/brightness" : ""
        onLoaded: {
            const now = parseInt(text());
            if (isNaN(now) || level.max <= 0)
                return;
            // the first reading is where it is, not a change
            if (level.last >= 0 && now !== level.last)
                root.show(level.kind, now / level.max);
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
        kind: "brightness"
    }

    Level {
        id: keyboardLevel

        device: root.keyboardLight
        kind: "keyboard"
    }
}
