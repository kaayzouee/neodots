# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Optional impermanence persistence paths and their evaluation-time
#          guard.
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

# Persistence contract for optional impermanent-root installations.

{ config, lib, ... }:

{
  config = lib.mkIf config.neodots.persistence.enable {
    # Without neededForBoot the persistence filesystem is mounted after
    # impermanence's bind mounts are set up, and the system drops into
    # emergency mode. Fail at evaluation time instead.
    assertions = [
      {
        assertion =
          config.fileSystems ? ${config.neodots.persistence.path}
          && config.fileSystems.${config.neodots.persistence.path}.neededForBoot
          && !(lib.elem config.fileSystems.${config.neodots.persistence.path}.fsType [
            "tmpfs"
            "ramfs"
            "auto"
          ]);
        message = "[persistence] neodots.persistence.enable requires an explicit nonvolatile fileSystems.\"${config.neodots.persistence.path}\" with neededForBoot = true.";
      }
    ];

    environment.persistence.${config.neodots.persistence.path} = {
      hideMounts = true;

      directories = [
        "/etc/nixos"
        "/var/lib/nixos"
        "/var/log"
      ];

      users.${config.neodots.username}.directories = [
        "Pictures"
      ]
      ++ lib.optional config.neodots.personal.enable {
        # This is the Home Manager key, not the unrelated system SOPS state.
        directory = ".config/sops/age";
        mode = "0700";
      };
    };
  };
}
