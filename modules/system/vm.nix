# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Guest tools, software-rendering fallbacks and the nixos-rebuild
#          build-vm profile for virtual machines.
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
  ...
}:

let
  cfg = config.neodots.vm;
in
{
  config = lib.mkMerge [
    # Installed inside a VM (set neodots.vm in hosts/nixos/machine.nix).
    (lib.mkIf cfg.enable {
      virtualisation.vmware.guest.enable = cfg.platform == "vmware";

      services.qemuGuest.enable = cfg.platform == "qemu";
      services.spice-vdagentd.enable = cfg.platform == "qemu";

      # Virtual GPUs often lack a hardware cursor plane and a GBM renderer.
      # Without these River can start with a black screen or no pointer.
      environment.sessionVariables = {
        WLR_NO_HARDWARE_CURSORS = "1";
        WLR_RENDERER_ALLOW_SOFTWARE = "1";
      };
    })

    # `nixos-rebuild build-vm --flake .#<hostname>` (QEMU, uses KVM when
    # /dev/kvm exists). Applied only to the generated VM, never to the host.
    {
      virtualisation.vmVariant = {
        neodots = {
          vm = {
            enable = lib.mkForce true;
            platform = lib.mkForce "qemu";
          };
          # No SOPS age key, /persist partition or Btrfs root inside the VM.
          personal.enable = lib.mkForce false;
          persistence.enable = lib.mkForce false;
          btrfs.enable = lib.mkForce false;
        };

        # Passwords are otherwise unset, which would make the VM unusable.
        # This only exists in the throwaway VM.
        users.users.${config.neodots.username}.initialPassword = "neodots";
        users.users.river.initialPassword = "neodots";

        virtualisation = {
          memorySize = 4096;
          cores = 4;
          diskSize = 20 * 1024;
        };
      };
    }
  ];
}
