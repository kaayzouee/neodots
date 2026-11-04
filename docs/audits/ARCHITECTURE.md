<!--
SPDX-License-Identifier: GPL-3.0-only

Neodots - Architecture inventory and pre-change audit baseline.

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

# Architecture and baseline

Audit date: 2026-11-03. Baseline commit: `5ff22d9ed93a3ff7220267a9ca9817294f985a96`.
This section records the implementation **before remediation**, not assumptions
from the README. Later changes are tracked in [FINAL-REPORT.md](FINAL-REPORT.md).
No live activation, disk change, credential access, or secret decryption is part
of this audit. The encrypted payload was deliberately not inspected; public
recipient policy and references are sufficient to trace its configuration.

## Assembly and ownership

```text
flake.nix + flake.lock
  hosts/nixos/machine.nix -> system, primary identity, feature flags
  nixpkgs.lib.nixosSystem
    hosts/nixos/default.nix
      ../../hardware-configuration.nix (unconditional baseline import)
      modules/system/* -> accounts, boot, packages, network, persistence, VM
      modules/desktop/desktop-gnome.nix -> GDM, GNOME, native Wayland policy
      modules/hardware/* -> fonts, mice, fcitx5, Lotus/uinput
      programs/{pcscd,thunar,fish}.nix -> system services/integration
    Mutter overlay -> compile out XWayland
    external NixOS modules -> Catppuccin, Home Manager, SOPS, impermanence
    Home Manager (global pkgs; shared SOPS module; extraSpecialArgs.neodots)
      primary -> home.nix + Catppuccin + Spicetify
      river -> river-home.nix + Catppuccin
      guest -> guest-home.nix
```

[flake.nix](../../flake.nix) exports one x86_64-linux host named by
[machine.nix](../../hosts/nixos/machine.nix), five development shells, five
project templates, nixfmt-tree, and three checks. There is no standalone Home
Manager output, installer output, package output, flake-parts or import-tree.
[configuration.nix](../../configuration.nix) is an ignored generated local file,
not the flake entry point; it must not be used to infer the flake's stateVersion.

System ownership is primarily [hosts/nixos/default.nix](../../hosts/nixos/default.nix)
and [modules/system](../../modules/system). Home Manager owns applications,
user configuration, user services and activation scripts. Some paths under
`modules/programs` are NixOS modules (Fish, Thunar, pcscd), others are Home Manager
modules (Alacritty, Waterfox, DSH, etc.); their directory alone does not determine
their module class. [neodots.nix](../../modules/system/neodots.nix) owns typed
host options and basic identity/path assertions.

### Accounts and privileges

| Account | Ownership and baseline behavior |
| --- | --- |
| Primary (`kay` in machine configuration) | Configurable name/home; 0700 home; Fish, GNOME, development tools, DSH; personal Git/SOPS only when explicitly enabled. |
| `river` | Separate fixed account and 0700 home; River/KWM/Quickshell, desktop applications, VS Code and development tools. |
| `guest` | Bash, 0700 home, empty password, no extra groups, separate Git identity/helper and small Home Manager profile. Home cleanup occurs at boot only. |

Both primary and River intentionally have `wheel`, `networkmanager`, `libvirtd`
and `uinput`. River is an administrator, not a sandbox. Sudo is wheel-only and
requires a password. Passwords for primary/River are not declared on the normal
host; mutable local account state is needed. The build-vm variant alone injects
disposable passwords and disables personal secrets, persistence and Btrfs tuning.
GDM explicitly allows null passwords; actual PAM/local-console behavior needs
runtime testing. See [SECURITY-AUDIT.md](../security/SECURITY-AUDIT.md).

### Desktop and custom packages

GNOME/GDM is the default session. River is separately registered through
`services.displayManager.sessionPackages`. XWayland is disabled by an option and
by the custom Mutter overlay. Native-Wayland settings affect GTK, Qt, Electron,
SDL and browsers; this intentionally excludes X11-only programs, not all X11
libraries from the transitive closure.

[packages](../../packages) contains River 0.4, KWM, fcitx5-lotus and shg recipes
with fixed source/dependency hashes and a local KWM patch. Package recipes are
called directly, not exported through an overlay. Repeated callPackage calls
normally resolve the same derivation and do not imply repeated compilation.
Lotus owns an input proxy account, udev integration and per-user system service
instances. Libvirt runs QEMU non-root with seccomp; AppArmor is enabled but this
is not evidence of a profile confining every application. pcscd, GnuPG agent,
Bluetooth, audio, printing/GNOME defaults and device helpers contribute surface.

[river-home.nix](../../hosts/nixos/river-home.nix) mixes account identity,
editor extensions, desktop packages, browser-profile mutation, Quickshell source
deployment/watching and the River init script. Its watcher observes
`/home/river/neodots/config/quickshell/neodots`, while `qs -c neodots` reads the
Home Manager-managed immutable snapshot. Restarting it does not load edited
checkout content. River init imports session environment into user systemd,
sets output scale to 1.5, starts Quickshell/watcher and execs KWM. Wallpaper
services expect optional mutable images under each user's Pictures directory.
Quickshell also executes external commands; package evaluation alone cannot
validate those commands or graphical startup.

### Secrets and persistence

[.sops.yaml](../../.sops.yaml) declares one public age recipient for repository
YAML secrets. The encrypted file's actual recipient metadata was not inspected,
so agreement with that policy is **unverified**. No automatic backup, key
creation, or restore procedure exists in the baseline repository. Home Manager
loads the primary user's key as a runtime string path
`~/.config/sops/age/keys.txt`; upstream `age.generateKey` defaults to false.
[git.nix](../../modules/personal/git.nix) references five secret fields and
renders an included Git configuration, including SMTP password, using SOPS
placeholders. This is not Nix-time plaintext interpolation. Upstream pinned
SOPS Home Manager defaults secret/template modes to 0400 and decrypts through a
user oneshot service and activation hook; decrypted generations reside below
`$XDG_RUNTIME_DIR/secrets.d`, linked from the user's config directory.

[persistence.nix](../../modules/system/persistence.nix) checks for a declared
`neededForBoot` backing filesystem and persists `/etc/nixos`, `/var/lib/nixos`,
`/var/log`, primary Pictures, and (when personal) `/var/lib/sops-nix`. That last
system path does **not** preserve the Home Manager key. Persistence is disabled
in the current machine. There is no automatic root-reset service or snapshot
manager. Missing private keys must fail decryption; new unrelated keys cannot
recover old ciphertext. Key loss after formatting is a supported explanation,
not a forensically confirmed diagnosis of the owner's incident.

## Confirmed findings and boundaries

Severity reflects practical impact, not the mere existence of intended privilege.

| ID | Severity/status | Evidence and boundary |
| --- | --- | --- |
| A01 | High, confirmed | Root hardware file is tracked despite .gitignore and README claiming otherwise; host imports it unconditionally. Evaluate/build workflows overwrite it with synthetic vda devices. Real Btrfs UUIDs and AMD settings identify a machine, not a documented fixture. Historical intent is not proven. |
| A02 | High, confirmed | Personal Home Manager key path in home.nix is absent from persistence.nix; preserving `/var/lib/sops-nix` does not protect it. No in-repo backup can recover a lost sole recipient. |
| A03 | Medium, confirmed | river-home.nix watcher and Quickshell read different source trees; absolute checkout path is a hidden development dependency. |
| A04 | Medium, confirmed | DSH provisioning is a user service with network resolution and mutable pnpm profile. Exact direct versions do not pin the dependency closure. See supply-chain assessment. |
| A05 | Medium, confirmed | Networking writes static public DNS, disables Stubby/resolved/resolvconf and NM DNS management. Header incorrectly claims DNS-over-TLS; VPN/split-DNS and resolver-failure compatibility are untested. |
| A06 | Medium, confirmed | Guest has empty password and GDM null-password support; guest home is reset at boot, not logout. This is intentional local access, with residual between-session privacy risk. |
| A07 | Medium, confirmed | Machine flags cover VM/Btrfs but not ASUS WMI, mt7921e quirk or timezone as coherent hardware features. The host is x86_64-specific. |
| A08 | Low, confirmed | btop is listed twice; many applications are installed system-wide and by Home Manager. System availability for all accounts and HM-owned config explain some duplication; do not delete package ownership blindly. |
| A09 | Low, confirmed | Unused DSH plugin inventory duplicates literal provisioning calls. Removing it is a complexity-only opportunity, not itself a security fix. |
| A10 | Medium, confirmed | README promises a cancelled installer and recommends copying over `/etc/nixos` and immediately switching. That does not protect generated hardware or staged recovery. |
| A11 | Medium, confirmed | Existing license test fails 21 checks. Source-grep migration tests and evaluation invariants do not exercise auth, SOPS recovery, persistence reboots or River startup. |
| A12 | Medium, hypothetical runtime impact | Browser activation imperatively modifies discovered Waterfox profiles; filesystem state and existing preferences are outside Nix's reconstruction boundary. No personal profiles inspected. |
| A13 | High, unverified deployment property | No LUKS or Secure Boot declarations in tracked hardware/boot configuration. Cannot assert disk encryption or firmware protection; live storage and firmware were not inspected or changed. |

## Baseline evidence

Environment: Nix 2.34.9; x86_64 Linux; writable `/dev/kvm`; approximately 150 GiB
free at start. Initial root-owned checkout prevented Git access; owner corrected
ownership during investigation. Baseline worktree was clean. No lock update.
Commands used `--no-write-lock-file` and builds used `--no-link` where supported.

| Check | Baseline result |
| --- | --- |
| `nix flake show` | PASS (all existing outputs evaluated) |
| `nix flake check --all-systems --no-build` | PASS; only x86_64-linux is exported, not cross-architecture verification |
| `nix eval --raw .#nixosConfigurations.nixos.config.system.build.toplevel.drvPath` | PASS: `/nix/store/pa95ns6g72w1vsd6x6dma2xj607r4s2n-nixos-system-nixos-26.11.20261101.0bb2eed.drv` |
| Host `nix build` | PASS, already realized/cached; no live activation |
| `nix fmt -- --ci .` | PASS: 48 Nix files, zero changes |
| `python3 tests/license-headers.py` | FAIL: 21 existing problems across 127 tracked files |
| `bash tests/check-wayland-migration.sh` | PASS (also run independently after license failure) |
| `nix build .#checks.x86_64-linux.wayland-client-smoke` | PASS realization, cached; not freshly executed |
| `nix build .#checks.x86_64-linux.gnome-wayland-vm` | PASS realization, cached; not freshly booted; harmless ignored eval-cache SQLite busy diagnostic |

No baseline SOPS, reinstall/rotation, guest-authentication or River VM integration
suite exists. Cached derivation success is reported separately from new runtime
evidence. Existing GNOME test and headless client test must remain available.

## Reproducibility and recommended refactoring

Pinned flake inputs, Zig dependency hashes and immutable editor extensions cover
many build inputs. They do not reconstruct passwords, age/GPG keys, browser
profiles, GitHub auth, wallpaper assets, mutable DSH dependency resolution, VM
disks or firmware. Templates use a fixed `~/neodots` checkout convention rather
than carrying a project-local lock. Store paths containing encrypted ciphertext
are expected; decrypted personal values must never enter derivations or logs.

The reference [dendritic architecture](https://github.com/workflow/dotfiles/blob/main/doc/DENDRITIC.md)
and its [host assembly](https://github.com/workflow/dotfiles/blob/main/parts/hosts.nix)
co-locate NixOS, Home Manager and persistence by feature and distinguish host
hardware from feature composition. Apply that ownership principle with existing
NixOS/Home Manager modules and typed options; no evidence requires flake-parts,
import-tree, a generic framework or an installer.

Incremental boundaries, in order:

1. Make production hardware selection explicit; keep synthetic fixture separate
   and preserve the historical file until evaluation/build equivalence is shown.
2. Keep primary-user SOPS persistence tied to personal.enable, with isolated
   synthetic integration tests and documented offline recovery recipients.
3. Give River one system feature owning account capabilities/session/packages,
   with cohesive Home Manager session/Quickshell components. Keep editor/browser
   preferences separate from compositor lifecycle. Preserve privilege defaults.
4. Separate immutable Quickshell deployment from explicitly enabled development
   sources; validate paths and avoid mutable production symlinks.
5. Add focused evaluation assertions plus runtime auth/recovery tests, retaining
   current CI. Document decisions requiring owner approval rather than changing
   DNS, guest policy, encryption, boot recovery or active credentials implicitly.
