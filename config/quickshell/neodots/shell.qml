// SPDX-License-Identifier: GPL-3.0-only
//
// Neodots - Quickshell entry point that creates the top bar and dock for every
//          screen.
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

import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        TopBar {
            property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        Dock {
            property var modelData
            screen: modelData
        }
    }
}
