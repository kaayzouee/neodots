<!--
SPDX-License-Identifier: GPL-3.0-only

Neodots - Rebuild boundaries, external state and safe recovery.

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

# Reproducibility and clean-system recovery

Neodots reconstructs **configuration and many package builds**, not the
machine's disks, account credentials or user data. Its only supported flake
system is `x86_64-linux`. The [architecture baseline](audits/ARCHITECTURE.md)
and [final verification](audits/FINAL-REPORT.md) distinguish evaluated, built,
and actually boot-tested outputs. A successful `nix flake check` alone proves
none of the external-state or runtime properties below.

| Boundary | Examples | What must survive or be supplied |
| --- | --- | --- |
| Declaratively reconstructible from the reviewed checkout and locked inputs | NixOS modules, GNOME/River session declarations, Home Manager configuration, custom package source hashes, five development shells/templates, immutable Quickshell deployment | The checkout and `flake.lock`, available pinned sources/binary caches, appropriate machine hardware module; only checks actually run are verified |
| Requires external credentials | Personal SOPS Git/SMTP configuration, account logins, GPG signing, GitHub/DSH authorization | Independently backed-up authorized age identity or recovery recipient; separate password, signing-key and provider recovery. Never commit or inject plaintext into Nix |
| Requires mutable application state | Waterfox browser profiles, VS Code workspace state, DSH OAuth/profile, libvirt images, wallpapers and personal files | Protected backups with tested restores, independent of the flake |
| Not fully reproducible | DSH plugin installation into a mutable pnpm profile and its future transitive resolution, project-specific Python/pip/cargo dependency resolution without a project lock, external service state | Review/lock each closure separately if exact replay matters; an exact direct plugin version is not a complete lock |

## Hardware and host ownership

[Machine settings](../hosts/nixos/machine.nix) explicitly select the owner's
tracked [hardware scan](../hardware-configuration.nix). That scan is **not** a
portable default. The separate synthetic [CI fixture](../tests/fixtures/hardware-configuration.nix)
is only selected by `nixosConfigurations.ci`; its disk labels are intentionally
not production devices. A new installation needs its **own** generated scan,
reviewed root/EFI devices and filesystem types, hostname, username, home and
correct `stateVersion` handling. The flake rejects some unsupported declarations
but cannot check whether a UUID points to the intended physical disk. Follow
[manual setup](../README.md#safe-manual-setup); never copy the fixture to a
new machine or replace an existing `/etc/nixos` tree without a backup.

## Toolchains and project inputs

`flake.lock` pins Nixpkgs, Home Manager and integration inputs. `devShells`
provide C++, Qt, Rust, Python and assembly tools; corresponding templates use
`NEODOTS_FLAKE` when set, otherwise `$HOME/neodots`. A moving local checkout is
convenient but changes projects when the checkout/lock changes; use a reviewed
immutable flake reference or project-specific lock for historical replay.
`checks.x86_64-linux.cpp-toolchain` compiles and executes a minimal C++/CMake
project with a generated clangd compilation database. Other shells are evaluated,
not proven against every editor/project. A generic Python shell does **not** pin
pip packages inside a project's venv. See [toolchain details](REPRODUCIBLE-TOOLCHAINS.md).

Custom River, KWM, Lotus and shg recipes pin fetched source/dependency hashes;
this checks fetched bytes, not upstream trust or future availability. Desktop
package evaluation does not prove a physical GPU, GDM login or all input devices
work. `nix develop` and `direnv allow` can run reviewed project code; neither is a
security sandbox. The DSH service installs version-pinned **direct** plugins to
mutable per-user state with install scripts disabled; [the supply-chain audit](security/SECURITY-AUDIT.md#sec-07--reproducibility-stops-before-mutable-dsh-profile-dependencies)
documents the remaining closure/advisory boundary.

## Persistent state and disaster recovery

The optional [impermanence module](../modules/system/persistence.nix) requires
an explicitly declared nonvolatile, early-mounted backing filesystem. It
retains `/etc/nixos`, `/var/lib/nixos`, `/var/log`, the primary user's Pictures,
and, only with personal configuration, their `.config/sops/age` directory.
This is **not an automatic root reset** and does not cover every identity or
application database. Reconstructible caches can be discarded; application
profiles, VM images and credentials need separate backup decisions. Preserving
the age directory on the same disk cannot recover it after disk loss or format.
[Recovery procedures](security/SOPS-RECOVERY.md) explain independent backup,
recipient custody, key rotation and permanently lost-key consequences. No backup,
format, production rotation or boot configuration change is automated here.

For a clean machine without private keys, disable `neodots.personal.enable`,
select the new machine's hardware module, evaluate and build **without activation**,
and verify a known-good boot path before selecting a new generation. Restore the
correct identity from separately protected media before enabling personal SOPS;
a newly generated key cannot decrypt ciphertext addressed only to the old one.
Recover GPG/GitHub/SMTP authorization and application profiles separately. If a
rebuild/boot fails, keep or select a retained known-good generation or trusted
recovery media, and restore the machine's own hardware scan and data from backup.
The repository does not implement rollback, partitioning, disk encryption or a
machine-aware installer.

## Disposable checks and their limits

```sh
nix flake show --no-write-lock-file
nix flake check --all-systems --no-build --no-write-lock-file
nix eval --raw .#nixosConfigurations.ci.config.system.build.toplevel.drvPath
nix build .#nixosConfigurations.ci.config.system.build.toplevel --no-link
nix build .#checks.x86_64-linux.sops-recovery .#checks.x86_64-linux.config-invariants --no-link
# Only when /dev/kvm is readable and writable:
nix build .#checks.x86_64-linux.security-persistence-vm .#checks.x86_64-linux.river-vm --no-link
```

The CI host uses synthetic hardware and disables personal credentials; builds
must never be installed. Disposable SOPS tests create independent age identities
and do not touch the owner's secrets. The security VM tests persistent key mounts,
synthetic decryption, missing/restored keys and reboot but **does not reset root or
format a real disk**. River/GNOME VMs require KVM to test graphical startup; a
runner without KVM skips that coverage, it does not pass it. Live disk geometry,
VPN DNS, firmware, real restore media, and full application-state recovery remain
unverified and require the owner to test against their own backups.
