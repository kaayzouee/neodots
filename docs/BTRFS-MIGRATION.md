<!--
SPDX-License-Identifier: GPL-3.0-only

Neodots - How to migrate the NixOS root from ext4 to Btrfs.

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

# Migrating the NixOS root from ext4 to Btrfs

Scope: only the NixOS root partition (`nvme0n1p8` today). The shared ESP
(`nvme0n1p1`) stays FAT32 and Windows (`nvme0n1p3`) is untouched. Partition
numbers change when partitions are added, so always refer to filesystems by
UUID or label, never by `/dev/nvme0n1pN`. `tests/default.nix` enforces this.

## Status

The author's machine already runs Btrfs, and `hosts/nixos/machine.nix` now
sets `neodots.btrfs.enable = true`. The steps below remain for new installs.
Copy the `hardware-configuration.nix` generated on the Btrfs machine into the
checkout: a stale ext4 one makes evaluation fail on purpose.

Subvolume mounts such as `/home` or `/nix` get the compression options only if
they are listed in `neodots.btrfs.mountPoints` and declared in
`hardware-configuration.nix` with `fsType = "btrfs"`.

## What Btrfs does and does not give you

Gives: snapshots and rollback, transparent zstd compression, checksums,
scrub. Does not give: reproducibility (Nix already provides it) or a fix for
the "Find NixOS closure" boot failure.

## Option A: fresh format (recommended)

1. Back up `/home`, `/etc/nixos` and anything under `/var/lib` you care about.
2. From a live USB:
```
mkfs.btrfs -L nixos /dev/disk/by-uuid/<root-uuid>
mount /dev/disk/by-label/nixos /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
umount /mnt
```
3. Mount with `-o subvol=@,compress=zstd:3,noatime` (and the other subvolumes
   under `/mnt/home`, `/mnt/nix`, `/mnt/var/log`), mount the ESP at `/mnt/boot`.
4. `nixos-generate-config --root /mnt`, copy the new
   `hardware-configuration.nix` into the repository checkout, restore `/home`,
   then `nixos-install --flake .#<hostname>`.
5. Set `neodots.btrfs.enable = true;` in `hosts/nixos/machine.nix`.

## Option B: in-place conversion

`btrfs-convert` converts an unmounted ext4 filesystem and keeps the data, but
it needs a full backup first and leaves a flat layout (no subvolumes). Run it
from a live USB on the unmounted root, then `nixos-generate-config`, update
`hardware-configuration.nix`, and rebuild.

## Safety net

`neodots.btrfs.enable` fails evaluation unless `fileSystems."/".fsType` is
`btrfs`, so enabling it too early cannot produce an emergency-mode boot.
