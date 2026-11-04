# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Machine identity and feature toggles: system, username, hostname,
#          persistence, VM and Btrfs.
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

# Owner-maintained host settings. No installer generates or replaces this file.
# Point hardwareModule at this machine's own generated scan before installation.

{
  system = "x86_64-linux";
  hardwareModule = ../../hardware-configuration.nix;

  neodots = {
    username = "kay";
    hostname = "nixos";
    homeDirectory = "/home/kay";

    personal = {
      enable = true;
    };

    btrfs = {
      enable = true;
      mountPoints = [ "/" ];
    };

    persistence = {
      enable = false;
      path = "/persist";
    };
  };
}
