// SPDX-License-Identifier: GPL-3.0-only
//
// Neodots - Singleton that lists the applications shown in the dock and menu.
//
// Copyright (C) 2026 kaayzouee
// Author: https://github.com/kaayzouee
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the
// Free Software Foundation, version 3 of the License.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
// Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program. If not, see <https://www.gnu.org/licenses/>.

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
