# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Random wallpaper picker for GNOME on Wayland.
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

{ pkgs, config, ... }:

let
  picturesDir = "${config.home.homeDirectory}/Pictures";

  pickWallpaper = pkgs.writeShellScript "pick-gnome-wallpaper" ''
    set -euo pipefail

    dir=${picturesDir}
    if [ ! -d "$dir" ]; then
      echo "wallpaper dir does not exist: $dir" >&2
      exit 1
    fi

    mapfile -d "" files < <(
      ${pkgs.findutils}/bin/find "$dir" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
           -o -iname '*.webp' -o -iname '*.bmp' \) -print0
    )

    if [ "''${#files[@]}" -eq 0 ]; then
      echo "no images found in $dir" >&2
      exit 1
    fi

    choice=$(printf '%s\0' "''${files[@]}" | ${pkgs.coreutils}/bin/shuf -z -n1 | ${pkgs.coreutils}/bin/tr -d '\0')
    uri=$(${pkgs.python3}/bin/python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().as_uri())' "$choice")

    ${pkgs.glib}/bin/gsettings set org.gnome.desktop.background picture-uri "'$uri'"
    ${pkgs.glib}/bin/gsettings set org.gnome.desktop.background picture-uri-dark "'$uri'"
    ${pkgs.glib}/bin/gsettings set org.gnome.desktop.background picture-options "'zoom'"
  '';
in
{
  systemd.user.services.gnome-wallpaper = {
    Unit = {
      Description = "Choose a random GNOME wallpaper";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pickWallpaper}";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
