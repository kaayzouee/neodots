pragma Singleton

import Quickshell

Singleton {
    readonly property var apps: [
        {
            role: "Finder",
            name: "Files",
            entry: DesktopEntries.heuristicLookup("Thunar"),
            iconSource: "file://" + Quickshell.shellPath("assets/icons/mactahoe/file-manager.svg"),
            fallbackIcon: "system-file-manager",
            fallbackCommand: ["thunar"],
            matches: ["thunar", "org.xfce.thunar"]
        },
        {
            role: "Safari",
            name: "Browser",
            entry: DesktopEntries.heuristicLookup("Waterfox"),
            iconSource: "file://" + Quickshell.shellPath("assets/icons/mactahoe/waterfox.svg"),
            fallbackIcon: "web-browser",
            fallbackCommand: ["waterfox"],
            matches: ["waterfox", "org.waterfox"]
        },
        {
            role: "Terminal",
            name: "Terminal",
            entry: DesktopEntries.heuristicLookup("Alacritty"),
            iconSource: "file://" + Quickshell.shellPath("assets/icons/mactahoe/alacritty.svg"),
            fallbackIcon: "utilities-terminal",
            fallbackCommand: ["alacritty"],
            matches: ["alacritty"]
        },
        {
            role: "Music",
            name: "Music",
            entry: DesktopEntries.heuristicLookup("Spotify"),
            iconSource: "file://" + Quickshell.shellPath("assets/icons/mactahoe/g4music.svg"),
            fallbackIcon: "multimedia-player",
            fallbackCommand: ["spotify"],
            matches: ["spotify"]
        },
        {
            role: "Messages",
            name: "Messages",
            entry: DesktopEntries.heuristicLookup("Vesktop"),
            iconSource: "file://" + Quickshell.shellPath("assets/icons/mactahoe/Vesktop.svg"),
            fallbackIcon: "internet-chat",
            fallbackCommand: ["vesktop"],
            matches: ["vesktop", "discord"]
        },
        {
            role: "Photos",
            name: "Photos",
            entry: DesktopEntries.heuristicLookup("GIMP"),
            iconSource: "file://" + Quickshell.shellPath("assets/icons/mactahoe/gimp.svg"),
            fallbackIcon: "gimp",
            fallbackCommand: ["gimp"],
            matches: ["gimp", "org.gimp.gimp"]
        },
        {
            role: "Launchpad",
            name: "Apps",
            entry: null,
            iconSource: "file://" + Quickshell.shellPath("assets/icons/mactahoe/applications-system.svg"),
            fallbackIcon: "view-grid",
            fallbackCommand: ["fuzzel"],
            matches: []
        }
    ]
}
