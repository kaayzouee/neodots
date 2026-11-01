# SPDX-License-Identifier: GPL-3.0-only

# Neodots - Deepseek Harness setup source code

# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, version 3 of the License.

# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.

# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.

# DSH is pinned by the existing flake.lock; SIWC is installed at an exact npm version.
# Note: DSH maintains a mutable profile/pnpm lockfile, so plugin transitive
# dependencies are not yet reproducible at the Nix store level.

{ config, pkgs, ... }:
let
  installer = pkgs.writeShellApplication {
    name = "neodots-install-dsh-siwc";
    runtimeInputs = [
      pkgs.deepseek-harness
      pkgs.nodejs_24
      pkgs.pnpm_11
    ];
    text = ''
      set -euo pipefail
      manifest="''${DSH_HOME:-$HOME/.dsh}/profiles/web/node_modules/dsh-plugin-chatgpt-siwc/package.json"
      if [ -f "$manifest" ] && node -e '
        const p = require(process.argv[1]);
        process.exit(p.name === process.argv[2] && p.version === process.argv[3] ? 0 : 1);
      ' "$manifest" "dsh-plugin-chatgpt-siwc" "0.9.7"; then
        exit 0
      fi
      dsh plugin --profile web add "dsh-plugin-chatgpt-siwc@0.9.7" --ignore-scripts
      test -f "$manifest"
      node -e '
        const p = require(process.argv[1]);
        process.exit(p.name === process.argv[2] && p.version === process.argv[3] ? 0 : 1);
      ' "$manifest" "dsh-plugin-chatgpt-siwc" "0.9.7"
    '';
  };
in
{
  home.packages = [
    pkgs.deepseek-harness
    installer
  ];

  # Provision outside NixOS rebuild, without running arbitrary npm lifecycle scripts.
  systemd.user.services.neodots-dsh-siwc = {
    Unit = {
      Description = "Provision pinned SIWC plugin for DeepSeek Harness";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${installer}/bin/neodots-install-dsh-siwc";
      Environment = [ "HOME=${config.home.homeDirectory}" ];
    };
    Install.WantedBy = [ "default.target" ];
  };
}
