<!--
SPDX-License-Identifier: GPL-3.0-only

Neodots - Security, reproducibility and modularity implementation report.

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

# Implementation and verification report

Audit baseline: `5ff22d9ed93a3ff7220267a9ca9817294f985a96` (2026-11-03 UTC).
The [pre-change inventory](ARCHITECTURE.md) documents the clean baseline;
[security findings](../security/SECURITY-AUDIT.md),
[SOPS recovery](../security/SOPS-RECOVERY.md) and
[reproducibility boundaries](../REPRODUCIBILITY.md) provide detailed evidence.
**Source changes are not a deployment**: no `nixos-rebuild`, host reboot,
disk operation, real credential access/rotation or production secret decryption
was performed. Changes remain staged: a focused commit attempt failed because
configured GPG pinentry timed out. No unsigned commit was forced. The owner must
unlock their signer in an interactive session before committing.

## 1. Baseline and confirmed problems

Before changes, flake show/check/no-build, the real-host derivation, a cached
full system build, formatting, cached Wayland smoke and GNOME VM outputs passed.
The license script failed 21 existing checks; the Wayland migration shell test
passed. Cached VM outputs are not fresh boot evidence. The baseline had no
isolated age-key/reinstall or River graphical integration tests.

| Finding | Baseline evidence | Consequence |
| --- | --- | --- |
| Hardware fixture confused with production hardware | Tracked root scan ignored by `.gitignore`, imported unconditionally; CI overwrote it with temporary vda fixture | Another machine could reuse wrong disk identifiers or a CI build silently depend on a checkout mutation |
| SOPS key not protected by optional persistence | Home Manager loaded `~/.config/sops/age/keys.txt`; persistence retained unrelated `/var/lib/sops-nix` | Formatting the only authorized key could make ciphertext unrecoverable |
| River watcher followed a different source than Quickshell | Watched `/home/river/neodots`; launched the Home Manager-managed immutable tree | Live edits restarted the wrong snapshot; checkout location was hard-coded |
| Static public DNS claimed to be encrypted | Stubby and resolved disabled; resolv.conf pointed to public resolvers | Incorrect privacy claim; no resolver-policy change without VPN/connectivity tests |
| Guest state reused between logins | Passwordless guest reset only at boot | Local privacy policy needs owner review, not silent account or auth changes |
| Mutable DSH plugin closure | Direct package pins installed into user pnpm state | Pinned first-level versions do not prove a fixed transitive closure or safe plugin behavior |
| Cancelled installer still described as upcoming | README/plan issue references | Misleading installation and hardware guidance |

Further context, evidentiary status and severities are in the linked audit
files; real disk encryption, login paths, installed plugin closure and production
key custody were **not inspected**.

## 2. Incremental implementation

- **Hardware and host boundary:** `flake.nix` selects an explicit production
  `hardwareModule` from `hosts/nixos/machine.nix` and an isolated
  `tests/fixtures/hardware-configuration.nix` for `nixosConfigurations.ci`.
  `hosts/nixos/default.nix` no longer imports hardware itself. The original
  tracked root scan remains intact; `.gitignore`, README and CI now agree about
  its owner-specific role. `modules/system/neodots.nix` and `tests/default.nix`
  reject missing root/EFI declarations, raw NVMe device names, misuse of the
  synthetic fixture as production hardware and invalid feature combinations.
- **SOPS and persistence:** `hosts/nixos/home.nix` explicitly disallows key
  autogeneration and adds a metadata-only runtime guard;
  `modules/personal/check-age-key.sh` checks owner and 0400/0600 key mode.
  `modules/system/persistence.nix` conditionally retains the actual Home
  Manager age directory on a declared early-mounted nonvolatile filesystem;
  it does not create or back up real keys. `tests/sops-recovery.py` covers
  disposable correct/missing/wrong keys, loss-and-backup restore, runtime-only
  template output, file modes and recipient rotation. The disposable
  `tests/security-persistence-vm.nix` exercises mounted key persistence,
  synthetic SOPS, guest isolation/PAM and reboot without resetting real root.
- **River:** `modules/desktop/river/{default,home,quickshell}.nix` and
  `session.sh` own account capabilities, session wiring and one supervised
  Quickshell source/lifecycle. `hosts/nixos/river-home.nix` keeps the user
  application preferences. Existing `wheel`, `networkmanager`, `libvirtd` and
  `uinput` defaults are preserved; toggles permit deliberate owner decisions.
  Production loads the Home Manager snapshot; development live source is
  explicitly opted into. Synthetic script/QML checks and a disposable River VM
  cover actual startup, mapped clients, restart and session teardown.
- **Toolchains/supply chain:** Existing language shells and package source hashes
  remain. Templates accept `NEODOTS_FLAKE` rather than requiring the author's
  checkout; the C++ check compiles and runs a project. DSH installer fixtures
  test idempotent version/source pin handling without touching any user profile;
  CI external Actions are commit-pinned and the npm audit checks peers instead
  of suppressing them. The daily advisory job is **not** a runtime sandbox.
- **CI/documentation:** `tests/repository-policy.py` checks external Action
  pins, fixture ownership and accidentally tracked private-key artifacts without
  printing values; the script is not a comprehensive secret scanner. Updated
  workflows preserve formatter/evaluation/system-build/Wayland/GNOME coverage and
  add focused recovery/security/River checks, skipping KVM explicitly when it is
  unavailable. README and installer-plan references now say cancelled; new
  architecture, security, recovery and reproducibility documents replace promises
  with verification boundaries. No installer, root-reset service or policy-driven
  DNS/authentication/boot change was introduced.

## 3. Final verification ledger

Statuses below apply to the post-change checkout; the baseline above is not
substituted for a post-change check. A derived build may reuse a cache; a fresh
VM derivation realization means the disposable test driver ran for that input.

| Check | Result | Boundary |
| --- | --- | --- |
| `nix flake show --no-write-lock-file` | PASS | Both real and CI host outputs plus eleven focused checks are exported. |
| `nix flake check --all-systems --no-build --no-write-lock-file` and full `nix flake check --all-systems --no-write-lock-file` | PASS both, including repository-policy derivation on final staged tree. | Only declared x86_64 outputs exist; other tests are separate checks below. |
| `nix eval --raw .#nixosConfigurations.nixos.config.system.build.toplevel.drvPath` | PASS | Production-host derivation, not activation. |
| `nix fmt -- --ci .` | Initial run found and formatted eight Nix files; rerun PASS (54 files, zero changes). | Formatting check only. |
| Host and synthetic CI system builds | PASS: both full toplevel closures built after changes. | No live activation; CI fixture must never be installed. |
| Python license/policy and Wayland migration shell checks | PASS: license 145 tracked files, zero problems; policy, script and `git diff --check` pass. | Static source checks, no live login test. |
| Synthetic SOPS, DSH installer, River script/QML, toolchain and config-invariant Nix checks | PASS: focused derivations and independently run Python fixtures; repository-policy build includes actionlint/shellcheck. | Generated credentials only; package evaluation is not desktop boot. |
| Wayland client smoke, GNOME VM and River VM | PASS builds: Wayland and GNOME outputs already cached; River VM freshly executed in prior audit work (26.61 seconds), not re-run in the final build. | KVM available; cached GNOME output is not a new boot. |
| Security/persistence VM | PASS: newly realized disposable NixOS test derivation, exit 0 | Tests synthetic guest/PAM, SOPS guard/decryption and key persistence across reboot, not a real root reset or machine restore. |
| Live disk/firmware, DNS/VPN, production key restore, real GDM login | NOT TESTED | Require controlled owner testing/authorization. |

A concurrent Nix evaluation emitted an ignored SQLite eval-cache busy warning;
that diagnostic is not a failed derivation. No test output should print secret
values. The plaintext sentinel in disposable tests is generated inside isolated
runtime paths, not embedded in a Nix source or stored in persistent CI logs.

## 4. Security, compatibility and recovery assessment

Key-loss behavior is now explicit: missing/wrong keys fail closed, authorized
restores work in disposable tests and mode/owner checks prevent an accidentally
world-readable key from being used. A local persisted copy alone is not an
independent backup. The hardware fixture cannot be silently selected as a real
production host by the same default configuration path. CI tests catch privilege,
firewall and secret-configuration regressions; neither static assertions nor
AppArmor being enabled prove all services are isolated.

GNOME/GDM and native Wayland remain enabled; no XWayland support was added.
River's administrative, virtualization, input and network-management privileges
remain intentional defaults, with a new explicit choice to disable each.
Quickshell production loads declared configuration while opt-in development
loads live files; River 0.4, KWM and the 1.5 output scaling remain. Home Manager
primary, River and guest profiles, the custom packages, and the five language
shells/templates remain in the flake. Only disposable VM and offscreen runs can
establish runtime graphical behavior; physical GPU and user-input paths are not
certified by them.

A clean **nonpersonal** CI host can be reconstructed from reviewed locked inputs
and synthetic hardware without real credentials. A usable personal host additionally
needs its own hardware scan, authorized age identity (or a separately held recovery
recipient), existing provider credentials, local passwords and backed-up application
state. Firmware, encryption, recovery media and actual backup availability are
outside this repository. No Nix expression can recover ciphertext encrypted only
to a permanently lost key.

## 5. Unresolved items and owner decisions

1. **High: external recovery authority** — independently protect/test the actual
   authorized age key or enroll an offline recovery recipient. Only the owner
   can approve real ciphertext changes, backup custody or credential rotation.
2. **High impact if stolen/untrusted boot:** determine actual disk encryption,
   Secure Boot, ESP/recovery-media and firmware policies before any storage or
   bootloader changes; test on a disposable target first.
3. **High advisory, runtime impact unknown:** review the SIWC peer dependency
   graph and reported Zod advisory against the *actual* installed DSH version;
   do not hide audit failures or override incompatible packages blindly.
4. **Medium: guest policy:** decide whether a shared, passwordless account with
   boot-only cleanup is appropriate; changing it needs local PAM/GDM and
   concurrent-session tests and owner approval.
5. **Medium: DNS/VPN:** choose static versus encrypted resolver ownership and
   failure/fallback/split-DNS behavior; verify traffic and VPN connectivity before
   applying network changes.
6. **Medium: mutable/runtime state:** test restoration of Waterfox profiles,
   developer/DSH data, complete persistence root-reset topology and actual
   physical GDM/River/hardware input. A VM reboot alone is not disaster recovery.
7. **Medium: privilege reduction and software supply chain:** River and the
   primary account are intentionally administrators; any capability removal,
   profile sandboxing or complete plugin dependency lock requires explicit
   compatibility review, not speculative hardening.

**Commit signing:** the proposed focused code commit failed (`gpg: signing failed:
Timeout` after pinentry launched). Unlock the existing signing identity yourself
and make signed code, CI/template and documentation commits. Do not disable the
configured signature merely to mark this audit complete. The changes are
staged for review and subsequent signed commits.

No production privileges, disk, secrets, VPN resolver policy, boot setting or
active credentials were changed by this project.
