pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The running distribution's logo (Nerd Font glyph) for the app menu button
// and other places that show it. Read once from /etc/os-release, the file
// fastfetch itself reads: ID first, then ID_LIKE (derivatives), else Tux.
Singleton {
    id: root

    property string osId: ""
    property string name: ""
    property var like: []

    // os-release IDs -> Nerd Font "linux-*" glyphs
    readonly property var logos: ({
            "almalinux": 0xf31d, "alpine": 0xf300, "aosc": 0xf301, "archcraft": 0xf345, "archlabs": 0xf31e,
            "arch": 0xf303, "archarm": 0xf303, "arcolinux": 0xf346, "artix": 0xf31f, "biglinux": 0xf347,
            "centos": 0xf304, "coreos": 0xf305, "crystal": 0xf348, "debian": 0xf306, "deepin": 0xf321,
            "devuan": 0xf307, "elementary": 0xf309, "endeavouros": 0xf322, "fedora": 0xf30a, "freebsd": 0xf30c,
            "garuda": 0xf337, "gentoo": 0xf30d, "guix": 0xf325, "hyperbola": 0xf33a, "kali": 0xf327,
            "neon": 0xf331, "linuxmint": 0xf30e, "mageia": 0xf310, "mandriva": 0xf311, "manjaro": 0xf312,
            "manjaro-arm": 0xf312, "mx": 0xf33f, "nixos": 0xf313, "nobara": 0xf380, "openbsd": 0xf328,
            "opensuse": 0xf314, "opensuse-leap": 0xf37e, "opensuse-tumbleweed": 0xf37d, "suse": 0xf314,
            "parabola": 0xf340, "parrot": 0xf329, "pop": 0xf32a, "postmarketos": 0xf374, "puppy": 0xf341,
            "qubes": 0xf342, "raspbian": 0xf315, "rhel": 0xf316, "rocky": 0xf32b, "sabayon": 0xf317,
            "slackware": 0xf318, "solus": 0xf32d, "tails": 0xf343, "trisquel": 0xf344, "ubuntu": 0xf31b,
            "kubuntu": 0xf333, "vanilla": 0xf366, "void": 0xf32e, "xerolinux": 0xf34a, "zorin": 0xf32f
        })

    // the logo glyph: the ID, then the distributions it's like, then Tux
    readonly property string logo: {
        for (const key of [osId, ...like]) {
            if (logos[key] !== undefined)
                return String.fromCodePoint(logos[key]);
        }
        return String.fromCodePoint(0xf31a);
    }

    FileView {
        path: "/etc/os-release"
        onLoaded: {
            const values = {};
            for (const line of text().split("\n")) {
                const m = line.match(/^([A-Z_]+)=("?)(.*)\2$/);
                if (m)
                    values[m[1]] = m[3];
            }
            root.osId = (values.ID ?? "").toLowerCase();
            root.like = (values.ID_LIKE ?? "").toLowerCase().split(/\s+/).filter(s => s);
            root.name = values.PRETTY_NAME ?? values.NAME ?? "";
        }
    }
}
