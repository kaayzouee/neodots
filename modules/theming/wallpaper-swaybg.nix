# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Random wallpaper picker using swaybg for the River session.
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

# modules/theming/wallpaper-swaybg.nix
{ pkgs, config, ... }:

let
  picturesDir = "${config.home.homeDirectory}/Pictures";

  pickWallpaper = pkgs.writeShellScript "pick-swaybg-wallpaper" ''
    set -euo pipefail

    dir=${picturesDir}

    if [ ! -d "$dir" ]; then
      echo "wallpaper dir does not exist: $dir" >&2
      exit 1
    fi

    mapfile -d "" files < <(
      find "$dir" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
           -o -iname '*.webp' -o -iname '*.bmp' \) -print0
    )

    if [ "''${#files[@]}" -eq 0 ]; then
      echo "no images found in $dir" >&2
      exit 1
    fi

    choice=$(printf '%s\0' "''${files[@]}" | shuf -z -n1 | tr -d '\0')

    exec ${pkgs.swaybg}/bin/swaybg \
      --mode fill \
      --image "$choice"
  '';
in
{
  systemd.user.services.swaybg-wallpaper = {
    Unit = {
      Description = "Set random Wayland wallpaper with swaybg";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "exec";
      ExecStart = "${pickWallpaper}";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
