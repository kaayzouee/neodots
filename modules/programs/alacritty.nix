# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Alacritty terminal settings and key bindings.
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
  programs.alacritty = {
    enable = true;
    package = null;

    settings = {
      font = {
        size = 11.25;
      };

      window = {
        opacity = 0.88;
      };
      keyboard.bindings = [

        {
          key = "T";
          mods = "Super";
          chars = "\\u0002c";
        }

        {
          key = "Q";
          mods = "Super";
          chars = "\\u0002p";
        }

        {
          key = "E";
          mods = "Super";
          chars = "\\u0002n";
        }

        {
          key = "D";
          mods = "Super";
          chars = "\\u0002&";
        }
      ];
    };
  };
}
