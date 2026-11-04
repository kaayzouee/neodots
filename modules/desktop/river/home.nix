# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - River/KWM session configuration for Home Manager.
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

{
  lib,
  pkgs,
  riverKwmPackage,
  ...
}:
let
  session = pkgs.writeShellScript "neodots-river-session" (builtins.readFile ./session.sh);
in
{
  imports = [
    ./quickshell.nix
    ../../programs/mako.nix
    ../../theming/wallpaper-swaybg.nix
  ];

  home.packages = with pkgs; [
    fuzzel
    libnotify
    wl-clipboard
    swaylock
    thunar
    wlr-randr
    wtype
  ];
  home.file.".config/kwm/config.zon".source = ../../../config/kwm/config.zon;
  home.file.".config/river/init" = {
    text = ''
      #!${pkgs.runtimeShell}
      export PATH=${
        lib.makeBinPath [
          pkgs.systemd
          pkgs.wlr-randr
          riverKwmPackage
          pkgs.coreutils
        ]
      }:$PATH
      exec ${session}
    '';
    executable = true;
  };

  systemd.user.targets.neodots-river-session.Unit = {
    Description = "Neodots River session";
    PartOf = [ "graphical-session.target" ];
  };
}
