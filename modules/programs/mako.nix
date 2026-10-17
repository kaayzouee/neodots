# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - mako notification daemon settings.
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

{ ... }:

{
  services.mako = {
    enable = true;

    settings = {
      anchor = "top-right";

      width = 420;
      height = 120;

      margin = 12;
      padding = 12;

      border-size = 2;
      border-radius = 8;

      default-timeout = 5000;
      ignore-timeout = false;

      icons = true;
      markup = true;

      max-visible = 5;

      font = "Sans 11";
    };
  };
}
