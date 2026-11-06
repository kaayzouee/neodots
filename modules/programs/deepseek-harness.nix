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

# DSH is built from the security-patched fork using the local package recipe.
# Note: DSH maintains a mutable profile/pnpm lockfile, so plugin transitive
# dependencies are not yet reproducible at the Nix store level.

{ config, pkgs, ... }:
let
  dsh = pkgs.callPackage ../../packages/deepseek-harness { };
  installer = pkgs.writeShellApplication {
    name = "neodots-install-dsh-plugins";
    runtimeInputs = [
      dsh
      pkgs.nodejs_24
      pkgs.pnpm_11
    ];
    text = ''
      set -euo pipefail
      # Ensure the profile exists before resolving its installed dependencies.
      install_plugin() {
        local name="$1" version="$2" source="$3"
        local manifest="''${DSH_HOME:-$HOME/.dsh}/profiles/web/node_modules/$name/package.json"
        # npm packages are version-checked; Git packages are also checked
        # against the profile's explicit dependency source in package.json.
        if [ -f "$manifest" ] && [ -f "''${DSH_HOME:-$HOME/.dsh}/profiles/web/package.json" ]; then
          if node -e '
            const fs = require("node:fs");
            const profile = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
            const installed = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
            const [name, version, source] = process.argv.slice(3);
            const declared = profile.dependencies?.[name];
            const expected = source.startsWith("github:") ? source : version;
            process.exit(installed.name === name && installed.version === version
              && declared === expected ? 0 : 1);
          ' "''${DSH_HOME:-$HOME/.dsh}/profiles/web/package.json" "$manifest" "$name" "$version" "$source"; then
            echo "[dsh] $name is pinned and installed"
            return 0
          fi
        fi
        echo "[dsh] installing $name from pinned source"
        dsh plugin --profile web add --save-exact --ignore-scripts "$source"
        test -f "$manifest"
        node -e '
          const p = require(process.argv[1]);
          process.exit(p.name === process.argv[2] && p.version === process.argv[3] ? 0 : 1);
        ' "$manifest" "$name" "$version"
      }
      install_plugin "dsh-plugin-chatgpt-siwc" "0.9.7" "dsh-plugin-chatgpt-siwc@0.9.7"
      install_plugin "@wenaixi/dsh-ponytail" "5.6.2" "@wenaixi/dsh-ponytail@5.6.2"
      install_plugin "dsh-ghidra" "0.11.4" "dsh-ghidra@0.11.4"
      # Git sources use full immutable commits, never moving branches.
      install_plugin "dsh-nix-dev-shell" "0.3.0" "github:running-grass/dsh-nix-dev-shell#90d39a724613d151838faac7972e3a06693df56a"
      # Java LSP 0.1.0 requires DSH < 0.2.0; do not bypass allow-version.
      install_plugin "dsh-github-ci" "1.0.0" "dsh-github-ci@1.0.0"
    '';
  };
in
{
  home.packages = [
    dsh
    installer
  ];
  systemd.user.services.neodots-dsh-plugins = {
    Unit = {
      Description = "Provision pinned DeepSeek Harness plugins";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${installer}/bin/neodots-install-dsh-plugins";
      Environment = [ "HOME=${config.home.homeDirectory}" ];
    };
    Install.WantedBy = [ "default.target" ];
  };
}
