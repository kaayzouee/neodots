# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

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
