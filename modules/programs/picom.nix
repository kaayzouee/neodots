# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - picom compositor settings for the XFCE session.
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

{ pkgs, ... }:
{
  services.picom = {
    enable = true;

    settings = {
      backend = "glx";
      vsync = true;

      blur = {
        method = "dual_kawase";
        strength = 5;
      };

      blur-background = true;

      # Keep Polybar/wallpaper/etc. sharp
      blur-background-exclude = [
        "window_type = 'dock'"
        "window_type = 'desktop'"
        "_GTK_FRAME_EXTENTS@:c"
      ];
    };
  };
}
