<!--
SPDX-License-Identifier: GPL-3.0-only

Neodots - How to test the configuration in QEMU/KVM or VMware Workstation.

Copyright (C) 2026 kaayzouee
Author: https://github.com/kaayzouee

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, version 3 of the License.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>.
-->

# Testing Neodots in a virtual machine

Two supported routes. Pick the one that fits.

## 1. QEMU/KVM with `build-vm` (fastest, no installer)

```
nixos-rebuild build-vm --flake .#<hostname>
./result/bin/run-<hostname>-vm
```

`modules/system/vm.nix` defines `virtualisation.vmVariant`, which applies only
to the generated VM:

- SOPS/personal config, `/persist` and Btrfs requirements are switched off.
- The primary user and `river` get the initial password `neodots`.
- 4 GiB RAM, 4 cores, 20 GiB disk.

KVM acceleration is used automatically when `/dev/kvm` exists. Inside VMware
Workstation enable *Virtualize Intel VT-x/EPT or AMD-V/RVI* in the VM settings
for nested KVM; without it QEMU falls back to slow emulation.

## 2. NixOS installed in VMware Workstation Pro

1. Create the VM with **UEFI** firmware, at least 4 GiB RAM, 2+ cores, and
   *Accelerate 3D graphics* enabled.
2. Install NixOS, then run `nixos-generate-config` inside the VM and use that
   `hardware-configuration.nix` (never copy the laptop's).
3. In `hosts/nixos/machine.nix` set:

```nix
neodots.vm = {
  enable = true;
  platform = "vmware";   # or "qemu" for virt-manager
};
neodots.personal.enable = false;   # no SOPS age key in the VM
```

This installs open-vm-tools (or the QEMU guest agent and SPICE agent), sets
`WLR_NO_HARDWARE_CURSORS=1` and `WLR_RENDERER_ALLOW_SOFTWARE=1` for River, and
skips the ASUS-only kernel module.

## Checks that run without a VM

`nix flake check --no-build` runs `tests/default.nix`, which includes the VM
options above. `python3 tests/check-license-headers.py` checks license headers.

## Not verified

The VM profile was written without access to Nix. If River shows a black screen
under VMware, check that 3D acceleration is on and try `WLR_RENDERER=pixman`.
