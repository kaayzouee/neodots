# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

# modules/programs/polybar.nix
{ pkgs, lib, ... }:

{
  home.file.".config/polybar/scripts/battery.sh" = {
    source = ../../config/polybar/scripts/battery.sh;
    executable = true;
  };

  services.polybar = {
    enable = true;
    package = pkgs.polybar.override { pulseSupport = true; };
    config = ../../config/polybar/config.ini;
    script = "polybar main &";
  };

  systemd.user.services.polybar = {
    Unit = {
      Description = lib.mkForce "Polybar status bar";
      After = lib.mkForce [ "graphical-session.target" ];
      PartOf = lib.mkForce [ "graphical-session.target" ];
      ConditionPathExists = lib.mkForce [ ];
      ConditionEnvironment = lib.mkForce [ ];
      AssertPathExists = lib.mkForce [ ];
    };

    Service = {
      Environment = lib.mkForce [
        "PATH=/run/current-system/sw/bin:/run/wrappers/bin:${pkgs.polybar}/bin"
      ];
    };

    Install.WantedBy = lib.mkForce [ "graphical-session.target" ];
  };
}
