# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Polybar service and configuration for the XFCE session.
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
