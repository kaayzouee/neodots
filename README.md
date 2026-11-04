<!--
SPDX-License-Identifier: GPL-3.0-only

Neodots - Personal NixOS configuration, safe manual setup and validation.

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

# Neodots

A personal **x86_64-linux NixOS configuration** with reusable NixOS modules,
Home Manager, GNOME on Wayland, a custom River/KWM/Quickshell desktop, custom
packages and pinned development toolchains. It is not a generic distribution.
The machine-aware installer is **cancelled**; installation and recovery are
manual. No graphical or terminal installer is planned.

The configuration is actively developed. Build reproducibility does not restore
private keys, passwords or application state, and evaluation does not prove a
working desktop or a secure machine. See the
[architecture inventory](docs/audits/ARCHITECTURE.md),
[security audit](docs/security/SECURITY-AUDIT.md) and
[verification report](docs/audits/FINAL-REPORT.md).

## What is configured

- [flake.nix](flake.nix) and [flake.lock](flake.lock) pin Nixpkgs and integration
  modules. Only x86_64-linux is supported/tested; `--all-systems` does not add architectures.
- [machine.nix](hosts/nixos/machine.nix) selects architecture, **production
  hardware module**, primary username/home, hostname and personal/Btrfs/persistence flags.
- [default.nix](hosts/nixos/default.nix) composes system features. System modules
  own accounts, services, boot/network and hardware; Home Manager owns user
  configuration and user services. See [modules](modules).
- Home Manager has separate [primary](hosts/nixos/home.nix),
  [River](hosts/nixos/river-home.nix) and [guest](hosts/nixos/guest-home.nix) profiles.
  Primary and River are intentionally administrators with password-authenticated
  sudo, NetworkManager, libvirt and uinput access. The guest is intentionally
  passwordless locally, unprivileged, and cleaned **at boot, not logout**.
- GNOME/GDM is the default desktop; select **river** in GDM for the configured
  River account. XWayland is deliberately disabled, including in Mutter. X11-only
  applications will not work. Custom [River feature modules](modules/desktop/river)
  own account capabilities, session registration, KWM and Quickshell lifecycle.
- [packages](packages) contains pinned River 0.4, KWM, fcitx5-lotus and shg recipes
  with dependency hashes and a local KWM patch. These are not installed by an installer.
- Five development shells/templates: `cpp`, `qt`, `asm`, `rust`, `python`.
  direnv/nix-direnv and VS Code extensions are configured. See
  [toolchain notes](docs/REPRODUCIBLE-TOOLCHAINS.md).

## Before adopting this configuration

Required: an existing NixOS installation, Git, flakes-enabled Nix, access to
administrative recovery, working backups and enough disk/ESP space. Review
account policy, laptop-specific drivers/quirks, timezone, native-Wayland limits,
virtualization and installed services. Do not replace a working configuration
blindly or reuse the original author's identities.

[hardware-configuration.nix](hardware-configuration.nix) **is tracked** and is
the owner's machine-specific scan, not a portable example or a fallback. It is
preserved for the existing host. The separate
[test fixture](tests/fixtures/hardware-configuration.nix) has intentionally
nonexistent disk labels and is selected only by `nixosConfigurations.ci` for
evaluation/builds. Neither file is a disk-layout instruction for another machine.
VM tests use their own disposable test-driver disks.

## Safe manual setup

These commands prepare/evaluate/build; they do not partition disks or activate
the system. Keep your existing generated hardware scan and working generation.
Do **not** copy this checkout over `/etc/nixos` or delete its Git metadata.

```sh
git clone https://github.com/kaayzouee/neodots.git "$HOME/neodots"
cd "$HOME/neodots"
# Optional new scan, without overwriting an existing file or changing disks:
(set -C; sudo nixos-generate-config --show-hardware-config > hosts/nixos/hardware-local.nix)
```

Alternatively, copy your existing generated hardware scan into that **new**
checkout-local filename without overwriting the original. Review it before use.
Edit [machine.nix](hosts/nixos/machine.nix):

```nix
system = "x86_64-linux";
hardwareModule = ./hardware-local.nix;
neodots = {
  username = "your-user";
  hostname = "your-host";
  homeDirectory = "/home/your-user";
  personal.enable = false; # Required without your own authorized age identity.
  btrfs.enable = false;    # Enable only if your own declared root is Btrfs.
  persistence.enable = false;
};
```

Preserve the rest of the attribute structure; this snippet illustrates values,
not an additional module. For an existing installation, review NixOS and Home
Manager `stateVersion` compatibility before adoption; do not bump these to
upgrade packages. Additional files referenced by a Git-backed flake must be
staged to be included; staging is not publishing:

```sh
git add hosts/nixos/hardware-local.nix
HOST=your-host
nix flake show --no-write-lock-file
nix flake check --all-systems --no-build --no-write-lock-file
nix eval --raw ".#nixosConfigurations.${HOST}.config.system.build.toplevel.drvPath"
nix build ".#nixosConfigurations.${HOST}.config.system.build.toplevel" --no-link
```

Evaluation rejects missing root device/type, invalid EFI filesystem for
systemd-boot, raw NVMe partition names and unsupported architecture. Persistence
needs a declared nonvolatile `neededForBoot` mount; Btrfs tuning requires Btrfs
mounts. These checks do not verify physical disk contents or safe partitioning.
Do not enable persistence or change encryption/boot layout just to satisfy a test.

### Activation is a separate owner decision

Before activation, ensure recovery media, a known-good generation and an
administrative login are available. Root emergency access remains locked by
default. Newly created primary/River accounts have **no committed password**;
keep an existing privileged recovery session while setting their passwords
locally with `passwd` after first activation, before logging out. Do not commit
passwords, hashes or keys. The configured River user defaults to `river`.

After reviewing the build, an owner may use `sudo nixos-rebuild boot --flake
".#${HOST}"` to prepare the next boot, then reboot deliberately and validate
login, storage, network and both desktops. This writes the boot configuration;
it is not a harmless evaluation command. `nixos-rebuild test` changes the running
system temporarily; `switch` changes the running system and boot default.
Neither is run by the audit or CI. Failed evaluation/build leaves the active
system alone. If a new boot fails, select a retained known-good boot generation
or use trusted NixOS recovery media and your own hardware/storage backups.

## Secrets and recovery

Personal configuration defaults off in reusable options but is on in the
owner's machine settings. New adopters should turn it off until supplying their
own identity/ciphertext. The personal age key is
`~/.config/sops/age/keys.txt`, owned by that user, mode 0600/0400, in a 0700
directory. It is never generated as an insecure replacement for a lost key.
Follow [SOPS recovery](docs/security/SOPS-RECOVERY.md) for initial setup, external
backup, restoring after formatting, independent recovery recipients and rotation.
GitHub authentication, GPG private keys and application databases are separate
external state. Never include `git config --list` or decrypted files in reports.

The system uses static **plaintext** public DNS, not encrypted DNS. Firewall
and AppArmor being enabled do not mean every application is sandboxed. Secure
Boot and full-disk encryption are not established by this repository. Guest
logout privacy, VPN DNS integration and physical protection require explicit
owner decisions; see [security findings](docs/security/SECURITY-AUDIT.md).

## River production and development

Defaults preserve `wheel`, `libvirtd`, `uinput`, `networkmanager` memberships.
`neodots.desktop.river` exposes `enable`, `user` and capability flags
`permissions.{admin,virtualization,input,networkManagement}`. Changing them is a
policy decision, not a recommended automatic hardening step.

Production Quickshell uses an immutable Home Manager deployment. There is no
hard-coded checkout watcher or out-of-store production symlink. For explicit
local development, set the River Home Manager option
`neodots.quickshell.developmentSource` to an absolute directory containing
`shell.qml`; Quickshell loads and natively watches that actual directory. Use
`home-manager.users.<configured-river-user>` from a NixOS module. Missing/invalid
sources fail clearly. After repeated startup failures, fix the source and run
`systemctl --user reset-failed neodots-quickshell; systemctl --user restart
neodots-quickshell`. Quickshell is session-bound and can restart without killing
KWM. See [desktop notes](docs/QUICKSHELL-BARS.md) for UI history; some legacy
Riverctl/XFCE actions remain unresolved and are not evidence of working controls.

## Development and testing

```sh
nix develop .#cpp             # Also qt, asm, rust, python.
nix flake init -t .#cpp       # Run in a project with an appropriate flake reference.
nix fmt -- --ci .
python3 tests/license-headers.py
python3 tests/repository-policy.py
bash tests/check-wayland-migration.sh
nix build .#checks.x86_64-linux.config-invariants \
  .#checks.x86_64-linux.sops-recovery \
  .#checks.x86_64-linux.dsh-installer \
  .#checks.x86_64-linux.river-session \
  .#checks.x86_64-linux.river-quickshell \
  .#checks.x86_64-linux.cpp-toolchain --no-link
# Disposable VM tests require accessible /dev/kvm:
nix build .#checks.x86_64-linux.security-persistence-vm \
  .#checks.x86_64-linux.river-vm .#checks.x86_64-linux.gnome-wayland-vm --no-link
# Build-only synthetic configuration, never install this output:
nix build .#nixosConfigurations.ci.config.system.build.toplevel --no-link
```

Templates retain `~/neodots` as a convenience default; set `NEODOTS_FLAKE` to
another checkout or an immutable flake reference before direnv activation.
A moving local checkout intentionally shares updates across projects; pin a
project reference for historical replay. Only allow trusted direnv files.

CI retains formatting, full CI-host build, QML lint, headless Wayland clients
and conditional GNOME VM checks, and adds security/recovery/River tests. KVM
skips are explicit, not passes. The DSH advisory audit covers a freshly resolved
dependency graph, not personal profiles or arbitrary plugin behavior; see
[DSH supply-chain limits](docs/DEEPSEEK-HARNESS.md).

## Limits and next work

See [reproducibility boundaries](docs/REPRODUCIBILITY.md) for external state,
pinning and disk-failure recovery; [final report](docs/audits/FINAL-REPORT.md) for
verified versus untested behavior and owner approvals. Physical GPU/GDM River
selection, VPN/failure DNS behavior, automatic locking and full root-reset or
rollback workflows need separate validation. Btrfs tuning is not snapshot backup.
Historical [installer proposal](docs/INSTALLER-PLAN.md) is cancelled, not a roadmap.
Contributions should preserve behavior, keep coherent feature ownership and add
focused regressions rather than introduce a generic module framework.
