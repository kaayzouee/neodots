<!--
SPDX-License-Identifier: GPL-3.0-only

Neodots - Changelog of the feat/river-wayland audit changes.

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

# Changelog

All changes are relative to `neodots-feat-river-wayland.zip` as uploaded.
None of them has been evaluated or built: the audit environment had no Nix.
Run `nix flake check` and `nixos-rebuild build-vm --flake .#<hostname>` first.
Open findings are in `docs/UNRESOLVED-ISSUES.txt`.

## Added

- `tests/default.nix` and `checks.<system>.config-invariants` in `flake.nix`:
  evaluation-time invariants for the guest account, the river user, sudo,
  boot, Btrfs, VM profile, persistence, DNS and input method. A failing
  invariant is reported by name and makes `nix flake check --no-build` fail.
- `tests/license-headers.py`: checks (and with `add FILE DESC` inserts) the
  GPL v3 header; run in CI by the new `license-headers` job in `format.yml`.
- `REUSE.toml`: license annotations for files that cannot carry a header
  (flake.lock, encrypted secrets, the kwm patch, SVG icons).
- `modules/system/vm.nix` and options `neodots.vm.{enable,platform}`: guest
  tools for VMware or QEMU, River software-rendering fallbacks, and a
  `virtualisation.vmVariant` profile for `nixos-rebuild build-vm`.
- `modules/system/btrfs.nix` and option `neodots.btrfs.enable` (default off):
  zstd compression, noatime and monthly scrub. Evaluation fails unless the
  root filesystem is Btrfs.
- Option `neodots.boot.configurationLimit` (default 8).
- Assertion that `neodots.persistence.enable` has a `neededForBoot` `/persist`.
- Assertion that the primary user is not named `river`.
- Docs: `UNRESOLVED-ISSUES.txt`, `VM-TESTING.md`, `BTRFS-MIGRATION.md`, and
  `docs/comments/*.txt` (moved long comments).

## Changed

- Every source file now carries the full GPL v3 notice, a
  "Neodots - <description>" line, copyright and author, at the top of the file
  (after a shebang if there is one).
- Long comment blocks (7+ lines) moved to `docs/comments/` and replaced with a
  one-line pointer: kwm config (8 blocks), fastfetch, guest-home, home,
  inputmethod, tests, and the dead commented-out resolver block in
  networking.nix.
- `boot.nix`: systemd-boot menu bounded by `neodots.boot.configurationLimit`,
  kernel command-line editor disabled, `asus-nb-wmi` skipped inside VMs.
- `river-home.nix`: the Quickshell watcher no longer spins when the live
  checkout is missing (directory guard, 5 s and 30 s backoff,
  `ConditionPathExists`).
- `guest-home.nix`: Alacritty bindings that send tmux prefixes are cleared for
  the guest (plain bash, no tmux).
- `inputmethod.nix`: fcitx5-lotus user taken from `neodots.username`.
- CI stub hardware configuration (`evaluate.yml`, `nixos.yml`) now declares
  `/boot`, which the new invariants require.
- `.gitignore`: ignore `__pycache__/`.
- `config/polybar/scripts/battery.sh`: shebang is the first line again.

## Fixed

- Boot: the unbounded systemd-boot generation list on the ESP shared with
  Windows is the leading suspect for "Failed to start Find NixOS closure".
  Not confirmed; see A1 in `docs/UNRESOLVED-ISSUES.txt`.
- Enabling persistence or Btrfs without the matching filesystem used to
  produce an emergency-mode boot; it now fails at evaluation.

## Btrfs switch

- `hosts/nixos/machine.nix`: `neodots.btrfs.enable = true`.
- New option `neodots.btrfs.mountPoints` (default `[ "/" ]`): mount points that
  get zstd compression and noatime; each must be a Btrfs mount.
- The btrfs assertion now checks every listed mount point, not only `/`.
- CI stub hardware configuration (`evaluate.yml`, `nixos.yml`) uses a Btrfs root.
- The btrfs assertion message names each offending mount point and the
  filesystem type found (or "not declared").
- Replace `hardware-configuration.nix` with the file generated on the Btrfs
  machine; the one in the audited zip is stale ext4 and fails evaluation.

## Not changed on purpose

- DNS-over-TLS has no fallback resolver yet (decision B1).
- `hardware-configuration.nix` is untouched and excluded from header checks.
