# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Synthetic hardware for evaluation and build tests, never installation.
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

{ config, modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  assertions = [
    {
      assertion = config.neodots.vm.enable && !config.neodots.personal.enable;
      message = "[hardware-fixture] Synthetic CI hardware requires VM mode and personal configuration disabled; never install this fixture on a real machine.";
    }
  ];

  # Deliberately nonexistent labels: evaluation/build fixture, not a boot image.
  # Boot tests use the NixOS test driver's disposable filesystem instead.
  fileSystems."/" = {
    device = "/dev/disk/by-label/NEODOTS_TEST_ROOT";
    fsType = "btrfs";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NEODOTS_TEST_EFI";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };
}
