# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Supervised Quickshell with immutable production sources.
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
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.neodots.quickshell;
  source =
    if cfg.developmentSource == null then
      "${config.xdg.configHome}/quickshell/neodots"
    else
      cfg.developmentSource;
  launch = pkgs.writeShellScript "neodots-quickshell" ''
    test -f ${lib.escapeShellArg "${source}/shell.qml"} || {
      echo 'Quickshell source must contain shell.qml' >&2
      exit 1
    }
    exec ${pkgs.quickshell}/bin/qs -p ${lib.escapeShellArg source}
  '';
in
{
  options.neodots.quickshell.developmentSource = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "/home/river/neodots/config/quickshell/neodots";
    description = ''
      Explicit absolute live source directory. Null uses the immutable Home
      Manager deployment. Quickshell's native file watcher reloads live edits.
    '';
  };

  config = {
    assertions = [
      {
        assertion =
          cfg.developmentSource == null
          || (
            lib.hasPrefix "/" cfg.developmentSource
            && !(lib.hasInfix "\n" cfg.developmentSource)
            && !(lib.hasInfix "\r" cfg.developmentSource)
          );
        message = "neodots.quickshell.developmentSource must be an absolute directory path without newlines.";
      }
    ];

    home.packages = [ pkgs.quickshell ];
    xdg.configFile."quickshell/neodots" = {
      source = ../../../config/quickshell/neodots;
      recursive = true;
    };

    systemd.user.services.neodots-quickshell = {
      Unit = {
        Description = "Neodots Quickshell shell";
        PartOf = [ "neodots-river-session.target" ];
        StartLimitIntervalSec = 30;
        StartLimitBurst = 5;
      };
      Service = {
        ExecStart = "${launch}";
        Restart = "on-failure";
        RestartSec = "1s";
      };
      Install.WantedBy = [ "neodots-river-session.target" ];
    };
  };
}
