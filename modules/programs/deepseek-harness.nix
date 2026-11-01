# SPDX-License-Identifier: GPL-3.0-only
# DSH is pinned by the existing flake.lock; SIWC is installed at an exact npm version.
# Note: DSH maintains a mutable profile/pnpm lockfile, so plugin transitive
# dependencies are not yet reproducible at the Nix store level.
{ config, pkgs, ... }:
let
  installer = pkgs.writeShellApplication {
    name = "neodots-install-dsh-siwc";
    runtimeInputs = [ pkgs.deepseek-harness pkgs.nodejs_24 pkgs.pnpm_11 ];
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
in {
  home.packages = [ pkgs.deepseek-harness installer ];

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
