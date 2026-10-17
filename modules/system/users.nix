# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - User accounts: primary user, river user and the ephemeral
#          passwordless guest.
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

{ config, pkgs, ... }:

{
  programs.fish.enable = true;

  users.users.${config.neodots.username} = {
    isNormalUser = true;
    description = config.neodots.username;
    shell = pkgs.fish;

    home = config.neodots.homeDirectory;
    homeMode = "0700";

    extraGroups = [
      "wheel"
      "networkmanager"
      "libvirtd"
      "uinput"
    ];
  };

  users.users.river = {
    isNormalUser = true;
    description = "River Wayland User";
    shell = pkgs.fish;

    home = "/home/river";
    createHome = true;
    homeMode = "0700";

    extraGroups = [
      "wheel"
      "networkmanager"
      "libvirtd"
      "uinput"
    ];
  };

  users.users.guest = {
    isNormalUser = true;
    description = "Friend Guest";

    # Intentional passwordless local guest/fallback account.
    hashedPassword = "";

    shell = pkgs.bash;

    home = "/home/guest";
    createHome = true;
    homeMode = "0700";

    # Deliberately no administrative groups.
    extraGroups = [ ];
  };

  # Guest data is ephemeral.
  systemd.tmpfiles.rules = [
    "D! /home/guest 0700 guest users -"
  ];

  # ---------------------------------------------------------------------------
  # Sudo
  # ---------------------------------------------------------------------------
  # Users outside wheel cannot even execute sudo.

  security.sudo = {
    enable = true;
    execWheelOnly = true;
    wheelNeedsPassword = true;
  };
}
