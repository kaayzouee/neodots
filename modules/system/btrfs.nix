# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Optional Btrfs tuning (compression, noatime, scrub) guarded by an
#          evaluation-time assertion.
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
  cfg = config.neodots.btrfs;
  mountPoints = lib.unique ([ "/" ] ++ cfg.mountPoints);

  isBtrfs = m: config.fileSystems ? "${m}" && config.fileSystems."${m}".fsType == "btrfs";

  # Names each offending mount point and what hardware-configuration.nix says
  # about it, so the failure is actionable.
  describe =
    m:
    "${m} ("
    + (if config.fileSystems ? "${m}" then config.fileSystems."${m}".fsType else "not declared")
    + ")";

  offenders = lib.filter (m: !isBtrfs m) mountPoints;
in
{
  config = lib.mkIf cfg.enable {
    # Evaluation-time guard. Enabling this on a machine whose root (or a listed
    # mount point) is not Btrfs would otherwise produce an emergency shell at
    # boot. See docs/BTRFS-MIGRATION.md.
    assertions = [
      {
        assertion = offenders == [ ];
        message =
          "[btrfs] neodots.btrfs.enable requires \"/\" and every neodots.btrfs.mountPoints entry to be a Btrfs mount in hardware-configuration.nix. Not Btrfs: "
          + lib.concatMapStringsSep ", " describe offenders
          + ". Regenerate the file on the Btrfs machine (nixos-generate-config --show-hardware-config), or set neodots.btrfs.enable = false until then.";
      }
    ];

    boot.supportedFilesystems = [ "btrfs" ];

    # Merged with the options nixos-generate-config wrote (for example subvol=@).
    fileSystems = lib.genAttrs mountPoints (_: {
      options = [
        "compress=zstd:3"
        "noatime"
      ];
    });

    services.btrfs.autoScrub = {
      enable = true;
      interval = "monthly";
      fileSystems = [ "/" ];
    };

    environment.systemPackages = [
      pkgs.btrfs-progs
      pkgs.compsize
    ];
  };
}
