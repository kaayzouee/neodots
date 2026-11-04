# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Build Mutter without XWayland support.
#
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.

#
# Disable XWayland support in Mutter itself. The NixOS
# programs.xwayland.enable option alone does not prevent Mutter from starting
# XWayland directly when the compositor was built with that feature enabled.

final: prev: {
  mutter = prev.mutter.overrideAttrs (old: {
    mesonFlags =
      (builtins.filter (flag: !(prev.lib.hasPrefix "-Dxwayland=" flag)) (old.mesonFlags or [ ]))
      ++ [ "-Dxwayland=false" ];
  });
}
