<!--
SPDX-License-Identifier: GPL-3.0-only

Neodots - Security threat model, evidence and remediation boundaries.

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

# Security audit and threat model

Audit date: **2026-11-03 UTC**. Baseline: `5ff22d9ed93a3ff7220267a9ca9817294f985a96`.
This is a source/configuration audit plus explicitly identified disposable tests,
not a penetration test or an attestation of the running machine. The baseline
inventory is [ARCHITECTURE.md](../audits/ARCHITECTURE.md); remediation and final
aggregate results belong in [FINAL-REPORT.md](../audits/FINAL-REPORT.md).

**Access boundary:** no production encrypted payload, private key, credential,
personal profile, decrypted value, live disk layout, firmware state or password
database was inspected. No production activation, decryption, rotation, disk
operation or reboot was performed. Tests use synthetic data and disposable state.
References to secret paths below are configuration contracts, not opened files.

Status vocabulary: **implemented** means source changed, not deployed; **verified**
identifies an actual completed check; **pending** is not a pass; **owner decision**
preserves an intentional policy instead of silently changing it. Severity assumes
the stated actor and prerequisites; a privileged user intentionally having
privilege is not itself a vulnerability.

## Assets and trust boundaries

- **Recovery authority:** age private keys, independent recovery copies/recipients,
  Git/SMTP/account credentials, and the ability to decrypt existing ciphertext.
- **Machine authority:** root, administrator authentication, boot/EFI state,
  generated hardware configuration, persistent filesystems and restore media.
- **User data:** primary/River home contents, browser sessions, DSH OAuth/profile
  state, guest-session files, clipboard/input, VM images and local logs.
- **Build authority:** reviewed Git history, the committed input lock, upstream
  Nix/npm/Git sources, binary-cache trust, CI workflows and project-local code.
- Primary and River are separate UIDs with 0700 homes, but both have administrative
  or device-management capabilities by default. They are not adversarial security
  compartments. Guest has no extra groups; a compromised same-UID process can
  still access that user's unlocked runtime secrets.
- Nix store immutability/content hashes protect reconstruction and fetched bytes;
  they do not prove upstream code is benign. Decrypted personal values must never
  be evaluated into store artifacts. Plugins, editor extensions and authorized
  project tooling execute with meaningful user authority after installation.

Account evidence: [users:26–72](../../modules/system/users.nix#L26-L72),
[River permissions:43–92](../../modules/desktop/river/default.nix#L43-L92).
Runtime placeholder boundary: [personal Git:28–54](../../modules/personal/git.nix#L28-L54).

## Threat scenarios

| Actor/scenario | Current boundary and attack prerequisites | Residual / required decision |
| --- | --- | --- |
| Remote unauthenticated network peer | Firewall is enabled; no remote-service exposure inventory or port scan was performed. Package installation does not prove a service is listening. | Review enabled/listening services on the actual deployment before claiming an exposed or closed port. |
| Hostile LAN, Wi-Fi, DNS or VPN environment | Static public DNS is configured; an on-path actor can observe/tamper with ordinary resolver traffic absent another transport protection. | DNS encryption, split-DNS and VPN leak policy need owner choice and network tests (SEC-05). |
| Casual person at local login screen | Passwordless guest and GDM null-password support are intentional; primary/River do not receive declared normal-host passwords. | Validate local-console/PAM behavior; do not equate an empty guest password with root access (SEC-04). |
| Next person using guest before reboot | Same guest UID can encounter previous browser/session/filesystem state; reset is boot-time only. | Logout cleanup policy and session-concurrency behavior remain owner decisions (SEC-04). |
| Malicious primary or River administrator | Wheel, libvirt, NetworkManager and uinput are trusted capabilities; sudo requires authentication. | A 0700 home is not protection against an administrator who obtains root (SEC-06). |
| Compromised browser, editor, IME or same-UID plugin | User-process access can expose runtime credentials or inject input; AppArmor enabled globally does not establish a profile for each application. | Minimize authorization and untrusted code; no universal application sandbox is demonstrated (SEC-06/08/09). |
| Prompt injection / untrusted repository or project | LLM tools, plugins, `.envrc`, build hooks and editor tasks can invoke code with the authorized account's permissions. | Review source before authorizing it; a lock or `direnv allow` is not a sandbox (SEC-08). |
| Compromised dependency publisher, registry, Git remote or CI action | Hash-pinned Nix inputs/action commits narrow substitution; mutable plugin transitive resolution remains outside the fixed closure. | Runtime behavior, malicious new releases and actual installed peer versions are not proven by advisory checks (SEC-07/08). |
| Lost/stolen device or malicious physical boot access | Home modes and the disabled boot-menu editor protect narrower paths, not offline disk reads or alternate boot media. | Disk encryption, Secure Boot, firmware/external boot policy and root recovery require explicit owner decisions (SEC-03). |
| Reinstall, formatting or sole-key loss | A new age identity cannot decrypt ciphertext encrypted only for the old identity. Persistence is not an independent backup. | Preserve authorized recovery authority off-machine; no recovery from a genuinely lost sole key is promised (SEC-01). |
| Interrupted upgrade, full ESP or lost known-good generation | Boot entries are bounded and GC removes old generations; neither is an off-machine recovery plan. | Test recovery media/restore procedure; do not change root authentication or boot recovery automatically (SEC-03). |
| Malicious VM guest | QEMU is configured non-root with seccomp; host libvirt management is privileged. | Guest tools, shared folders/clipboard, hypervisor flaws and actual VM networking remain deployment-specific (SEC-06). |

## Findings and disposition

### SEC-01 — Recovery-key availability is not reconstructible from Nix

**High consequence, confirmed configuration gap in baseline; partially implemented.**
Baseline persistence retained unrelated system SOPS state but not the Home Manager
age-key directory. Losing a sole authorized key could permanently lose access to
the existing encrypted data. This explains a possible failure mode, not a forensic
finding about the owner's past incident.

- Evidence: current [key contract:65–78](../../hosts/nixos/home.nix#L65-L78),
  [key persistence:48–54](../../modules/system/persistence.nix#L48-L54),
  [runtime templates:36–54](../../modules/personal/git.nix#L36-L54).
- Implemented: explicitly disable replacement-key generation; check key ownership
  and 0400/0600 mode without reading its value; conditionally persist the correct
  directory only when personal configuration and persistence are enabled.
- Compatibility: restore the existing authorized identity, not an unrelated new
  key. A checked file's ownership/mode does not prove its cryptographic identity.
  Persistence is currently optional and requires an early-mounted backing FS.
- Verified fresh synthetic execution: correct/missing/wrong/reinstall cases,
  runtime manifest boundaries and recipient rotation passed. The metadata guard
  accepted 0400/0600 and rejected 0644/missing keys. These are disposable identities,
  not evidence of production-key availability; persistence VM completion is listed
  separately below.
- Residual: sole-recipient loss cannot be repaired in code. Independent protected
  backup/recovery-recipient enrollment requires owner custody and authorization.
  Actual ciphertext-recipient agreement was not inspected.

### SEC-02 — Hardware selection must not overwrite production storage facts

**High availability impact under wrong-target rebuild; baseline confirmed.**
The baseline tracked machine-specific hardware while CI overwrote the same root
path with synthetic devices. Following generic copy/switch instructions on another
machine could select the wrong filesystem configuration.

- Evidence: baseline [architecture A01](../audits/ARCHITECTURE.md#L138-L150);
  hardware is now selected outside reusable host imports
  [host:29–30](../../hosts/nixos/default.nix#L29-L30).
- Implemented: explicit production hardware selection, a separate CI fixture and
  validation. Configuration invariants passed; aggregate build status belongs in
  the final report. No generated hardware file was overwritten by this audit.
- Exploit assumption: operator error, unsafe copying or maliciously reviewed host
  configuration—not an automatically demonstrated remote exploit.
- Compatibility/test: root device/type, EFI vfat mount and stable device IDs must
  remain explicit [assertions:119–138](../../modules/system/neodots.nix#L119-L138).
  Test fixture and production outputs separately; evaluation cannot validate
  physical UUIDs, partition ownership or the active disk.
- Residual: destructive storage migration and reinstall remain manual, backed-up
  operations; a passing synthetic build must not authorize switching the host.

### SEC-03 — Offline protection and boot/root recovery are unverified policies

**High impact if a hostile actor has physical/offline access; not a deployment finding.**
No reviewed source establishes disk encryption or a verified firmware trust chain.
Do not infer the live device is unencrypted, nor claim it is protected.

- Evidence: [boot:28–39](../../modules/system/boot.nix#L28-L39) configures systemd-boot,
  writable EFI variables, a bounded menu and a disabled editor. None proves LUKS,
  Secure Boot or protected alternate-boot policy.
- Owner decision: encryption/migration, recovery-key custody, Secure Boot signing,
  firmware restrictions and emergency/root-login policy. No password reset,
  repartition, boot enrollment or recovery-lockout change was implemented.
- Compatibility: shared Windows ESP, external recovery media, device replacement
  and VM boot requirements must remain recoverable. Boot-menu restrictions alone
  are not an offline security boundary.
- Tests/status: review generated disk declarations and test recovery in a
  disposable VM first; live firmware/storage/authentication remain untested.
- Residual: a lost encrypted disk without its unlock key or a machine without
  independently usable restore media is not recoverable merely from this flake.

### SEC-04 — Guest privacy ends at reboot, not logout

**Medium, confirmed intentional policy; owner decision outstanding.**
Evidence: [guest account/reset:42–62](../../modules/system/users.nix#L42-L62) and
[GDM null-password support:37–38](../../modules/desktop/desktop-gnome.nix#L37-L38).
A subsequent local guest session before reboot may access the previous guest's
state because it uses the same UID. This does not imply guest has wheel or can
read a protected primary home without another weakness.

- Minimal policy choice: keep the documented shared-between-reboots guest, or
  explicitly authorize logout reset/ephemeral-session isolation. No silent guest
  removal, new password or logout deletion was introduced.
- Compatibility: logout cleanup must handle multiple concurrent sessions and
  user-manager processes; indiscriminate home deletion can destroy a live session.
- Tests/status: source invariants cover empty-password/group/reset declarations;
  actual PAM/TTY/GDM access and two-session privacy tests remain pending.
- Residual: boot cleanup is not secure erasure, including on SSDs/snapshots/backups.

### SEC-05 — Static public DNS is not DNS-over-TLS

**Medium confidentiality/compatibility risk; confirmed source mismatch.**
[Networking:24–44](../../modules/system/networking.nix#L24-L44) disables managed DNS,
resolved, resolvconf and Stubby, writes public resolvers and enables the firewall;
the header's DNS-over-TLS description is therefore inaccurate.

- Assumption: resolver traffic traverses an untrusted link without independent
  VPN/encrypted-DNS protection; actual packet paths were not captured.
- Owner decision: encrypted resolver versus static DNS, VPN/split-DNS integration,
  local domains, captive portals and failure fallback. Do not change DNS or claim
  a VPN leak fix without the owner's intended policy.
- Minimal fix now: truthful documentation/header; later one chosen resolver owner,
  followed by DNS transport, VPN leak, reconnect and failure tests.
- Status/residual: resolver policy unchanged; firewall enablement does not encrypt
  DNS or block same-user/application exfiltration by itself.

### SEC-06 — Administrator, virtualization and input capabilities are powerful

**Medium under same-account compromise; intentional defaults, not isolation.**
Evidence: [primary groups/sudo](../../modules/system/users.nix#L26-L72),
[River permission options](../../modules/desktop/river/default.nix#L43-L92),
[QEMU/AppArmor](../../modules/system/virtualization.nix#L21-L36), and
[Lotus integration](../../modules/hardware/fcitx5-lotus.nix#L97-L107).

- Assumption: attacker compromises a privileged user's process or an authorized
  device/input component. uinput grants input injection; libvirt management must
  not be treated as ordinary unprivileged application access.
- Implemented River refactor exposes explicit permission switches while
  preserving all existing defaults. Dropping capabilities requires owner choice;
  removing input/VM/network permissions can break real workflows.
- Positive controls: separate UIDs, 0700 homes, wheel-only password-authenticated
  sudo, QEMU non-root/seccomp and enabled AppArmor.
- Tests/status: group invariants are evaluation checks; actual polkit, IME ACLs,
  per-application AppArmor confinement and VM escape resistance are not proven.
- Residual: do not run untrusted code as an administrator and expect account-home
  separation, Wayland or a global AppArmor switch to contain it automatically.

### SEC-07 — Reproducibility stops before mutable DSH profile dependencies

**Medium, confirmed boundary; several controls implemented.**
Evidence: [DSH installer](../../modules/programs/deepseek-harness.nix#L20-L70),
[locked nixpkgs](../../flake.lock#L86-L97),
[dependency workflow](../../.github/workflows/dsh-plugin-security.yml).

- Fixed: npm declaration idempotence, duplicate unused inventory, no-op source
  comparison and abbreviated Git identity; source commit verified against the
  public repository. Exact npm pins and Git commit checks remain, install scripts
  remain disabled and incompatible Java LSP remains quarantined.
- CI actions now use commit IDs. Quickshell tooling uses the flake's temporary
  input registry rather than the runner's moving nixpkgs registry.
- Exploit assumption: compromised source/dependency, unsafe version review or
  mutable dependency graph drift. Hashes detect changed fetched bytes; they do
  not establish benign code or prevent exfiltration by later plugin execution.
- Verified: offline disposable installer fixtures, owned workflow actionlint,
  Nix formatting and input-registry narHash identity. No real installer/profile
  was exercised.
- Residual/minimal next step: independently package/lock reviewed plugin closures
  if Nix-level reproducibility is required; do not copy a credential-bearing user
  profile into Git. npm advisory scans are not malware/runtime permission audits.

### SEC-08 — DSH host and plugin advisory audits are independent

**High advisory severity in the previous host; patched Zod in the proposed fork; host-wide audit pending CI.**
The previously packaged DSH 0.2.1-rc.3 and a fresh SIWC peer
resolution could select vulnerable Zod 4.4.3
([GHSA-mrhx-c7xc-m3w5](https://github.com/advisories/GHSA-mrhx-c7xc-m3w5)).
The proposed local DSH package in PR #13 pins a fork commit whose pnpm lockfile
resolves Zod 4.6.7. Its Nix installation check also rejects alternate Zod
versions. Neither claim alone constitutes a full host vulnerability audit.

- The six isolated plugin advisory checks use `--legacy-peer-deps` to reflect
  the generated profile's `autoInstallPeers: false`. They do **not** scan the
  DSH host's production dependency graph or validate host-supplied peers.
- The blocking `host-dependency-audit` GitHub Actions job independently fetches
  exactly the full commit pinned in `packages/deepseek-harness/default.nix`,
  checks its locked Zod version and runs `pnpm audit --prod --audit-level high`
  on the fork's own frozen production dependency graph.
- Status (2026-11-06): the first host audit failed with 35 advisories (10 high,
  22 moderate, 3 low), including multiple high-severity undici advisories.
  This is a genuine dependency-audit failure, not a Zod version-check failure.
  The previous SIWC peer-resolution result is historical evidence, not the
  current plugin CI result. Advisory data can change between workflow runs.
- Residual: vulnerability audits detect known advisories, not arbitrary
  malware, malicious plugin behavior, or exploitability in a deployed profile.

### SEC-09 — Authorized plugins/projects can reach user data and external services

**Medium under malicious code/prompt input; authorization boundary remains.**
[DSH docs](../DEEPSEEK-HARNESS.md#L42-L64) identify OAuth/profile sensitivity and
background-call behavior. [Template example](../../templates/cpp/.envrc) loads
central project tooling; neither dependency pins nor direnv approval isolate code.

- Assumption: user authorizes a malicious plugin, repository instruction, build
  script or tool call; this is not evidence every plugin is malicious.
- Minimal controls: review pins and permissions, use least-privilege sessions,
  authorize external operations narrowly and keep credentials out of Git/logs.
  Script suppression during install does not sandbox execution after load.
- Compatibility: Java LSP stays disabled for DSH incompatibility; do not grant
  prepare-script permission or version exemptions merely to make loading succeed.
- Tests/status: mock provisioning is not OAuth, exfiltration or runtime tool-policy
  verification. DSH server authentication/bind settings and actual plugin runtime
  configuration were outside the no-personal-profile audit boundary.
- Residual: separate Unix users or a deliberately configured sandbox are required
  where an adversarial workload must not share the administrator's data authority.

### SEC-10 — Desktop lifecycle/source mismatch fixed and tested in a disposable VM

**Medium availability/configuration risk in baseline; implemented and VM-verified.**
The baseline watched a live checkout while launching an immutable deployment.
Current [Quickshell source selection/service](../../modules/desktop/river/quickshell.nix#L27-L85)
uses a single selected source, supervised service, bounded restarts and an explicit
optional development path. [Session cleanup](../../modules/desktop/river/session.sh#L33-L55)
stops the session target on completion, failure or signals.

- Assumption: checkout absence, stale source or session lifecycle failure; not a
  demonstrated privilege escalation.
- Compatibility: production source remains Home Manager-managed; live edits are
  an explicit same-user code-trust choice. Display scale remains 1.5; River 0.4/KWM
  and native Wayland remain required. No claim of X11-only application support.
- Verified: native offscreen reload passed in the sandbox. A fresh River VM test
  passed in 26.61 seconds: River/KWM/full QML plus a mapped foot client, Quickshell
  SIGKILL recovery without changing compositor/window-manager/client PIDs, teardown
  with a lingering user manager, and swaylock PAM rejection/acceptance of wrong/
  correct disposable passwords. The synthetic lifecycle fixture passed after
  the sandbox interpreter-path fix. None proves complete GDM/physical-device
  authentication or resistance to every lock-screen bypass.
- Residual: Quickshell invokes user commands; reviewed positional arguments in
  [Dock:298–304](../../config/quickshell/neodots/Dock.qml#L298-L304) are not a finding
  of arbitrary shell interpolation. Compositor/input protocol correctness and
  full lock-screen bypass resistance need dedicated runtime validation.

### SEC-11 — Mutable application state is outside declarative recovery

**Low–Medium data-loss consequence; confirmed boundary, no exploit demonstrated.**
[Waterfox activation:60–128](../../modules/programs/waterfox.nix#L60-L128) discovers
existing profiles, preserves unowned preferences and writes managed user settings.
A rebuild cannot reconstruct every session, cookie, profile or user-modified file.

- Assumption: interrupted mutation, wrong profile selection or a recovery plan
  incorrectly treating Nix configuration as a backup of mutable application data.
- Minimal next step: protected profile backups and disposable migration fixtures;
  consider atomic writes only with a demonstrated failure case. Do not inspect or
  rewrite real profiles during an audit.
- Compatibility/status: existing application behavior preserved; profile rollback,
  concurrent-browser writes and restore were not tested. Same-UID modification is
  not automatically a cross-user or root escalation.

## SOPS/reinstall scenarios and test boundaries

These scenarios describe authorized synthetic testing, not permission to decrypt
production secrets. [sops-recovery.py](../../tests/sops-recovery.py) uses generated
disposable identities, random synthetic plaintext, isolated runtime/home paths,
actual `sops-install-secrets`, controlled diagnostics and private output modes.

| Scenario | Required invariant | Implementation / verification scope |
| --- | --- | --- |
| A — Correct authorized key | Runtime decryption and template substitution succeed; output owner/modes are private. | PASS fresh synthetic runtime installer execution. Not production decryption evidence. |
| B — Missing key | Fail closed; no plaintext fallback or unrelated replacement-key generation. | PASS fresh missing-key execution; explicit `generateKey=false` and metadata checker present. |
| C — Wrong key | Valid syntax/mode is not authorization; fail cryptographic decryption. | PASS fresh wrong-recipient execution. Metadata checker alone cannot establish key identity. |
| D — Reinstall/key loss and protected restore | Absent old identity fails; restoring its independent backup decrypts unchanged ciphertext. | PASS fresh synthetic removal/restore execution. Truly lost sole key remains unrecoverable. |
| E — Personal configuration disabled | No personal SOPS/Git dependency or key requirement; disposable VM must not depend on personal credentials. | PASS configuration invariants for no personal secrets/templates/key and VM overrides. Not a production authentication test. |
| F — Persistence enabled/disabled | Enabled requires an early backing filesystem and retains the correct key directory only when personal is enabled. | PASS evaluation invariants and a fresh security/persistence VM with key mount, synthetic SOPS and reboot; no real root reset or power-loss test. |
| G — Plaintext stays out of build/activation artifacts | Secret/template declarations carry placeholders; decryption is runtime-only. | PASS fresh synthetic runtime-manifest assertions; not a complete production store/log/backup scan. Never place test plaintext in a Nix derivation source. |
| H — Multiple authorized recipients and rotation | Both authorized keys work; removed recipient fails after rewrapping and data-key rotation. | PASS fresh disposable updatekeys/rotate execution. Real recipient enrollment/revocation requires owner approval and intact authorized key. |

The key metadata checker intentionally never prints/reads private-key content;
see [check-age-key.sh:20–29](../../modules/personal/check-age-key.sh#L20-L29).
It is not an anti-race boundary against an already compromised same-UID process.
The recovery procedure is owned by [SOPS-RECOVERY.md](SOPS-RECOVERY.md).

## Evidence ledger: baseline is not a new runtime pass

| Evidence | Result known at this report snapshot | What it does not establish |
| --- | --- | --- |
| Baseline flake evaluation/config derivation | PASS reported in [architecture baseline](../audits/ARCHITECTURE.md#L154-L175). | Post-change build, actual hardware or live account state. |
| Baseline full host, Wayland smoke and GNOME VM realizations | PASS **cached/already realized**, per baseline record. | A new boot, new GUI launch or a freshly executed authentication test. |
| Offline DSH fixture | PASS: fresh install, scoped npm/Git identity, version/name/source mismatch, missing manifest, HOME fallback, idempotence and fail-closed bad installed version. | Actual plugin loading, OAuth, network availability or installed dependency closure. |
| Owned workflows actionlint / module Nix formatting | PASS; actionlint includes available shellcheck/pyflakes. | GitHub-hosted runner execution or absence of malicious upstream code. |
| Quickshell input registry identity | PASS: `--inputs-from .` nixpkgs narHash equals the committed lock. | Full graphical Quickshell session success. |
| Six script-disabled fresh dependency resolutions | PASS in temporary directories; no lifecycle scripts or personal npm config. | Reproducibility of mutable future resolutions. |
| Expanded production advisory audits | Five PASS; SIWC FAIL as SEC-08. | Installed host version/exploitability or absence of malware. |
| New SOPS integration + key metadata guard | PASS fresh A–D, G (runtime manifests), H; 0400/0600 accepted, 0644/missing rejected. | Real key custody, production ciphertext recipients, complete store/log scanning or a production restore. |
| New configuration invariants | PASS after test override-priority correction. | Live hardware layout or actual account passwords. |
| New DSH/offscreen Quickshell checks | PASS in the Nix sandbox. | Actual OAuth/plugin runtime or a physical display. |
| New River VM | PASS actual fresh execution, 26.61 seconds; mapped client, Quickshell crash recovery, lingering-manager teardown and swaylock PAM wrong/right passwords. | Full physical-device/GDM/attack-resistant lock-screen certification. |
| New synthetic lifecycle fixture | PASS after interpreter-path fix; River shell handles startup failure, scaling and signal cleanup. | Real compositor startup is covered separately by the VM. |
| New security/persistence VM | PASS: freshly realized disposable VM test; guest GDM PAM, generated SOPS values, key loss/restore, mount and reboot. | Production persistence/recovery or real GDM login. |
| Source licensing and migration regression | PASS: 145 tracked files, zero license problems; migration syntax/source checks pass. | License provenance of unreviewed future dependencies or runtime security. |
| Guest privacy, production persistence reboot, encrypted-disk/Secure Boot recovery | Not exercised on the live deployment. | No live-deployment security claim should be inferred. |

## Owner decisions deliberately not implemented

1. **DNS/VPN:** choose encrypted/static resolver ownership, split-DNS and leak/failure
   behavior before changing the currently working network policy.
2. **Guest lifecycle:** retain documented boot-only reset or approve logout cleanup/
   stronger isolation, including concurrent-session and privacy requirements.
3. **Disk/firmware trust:** approve encryption/migration, Secure Boot, external-boot
   restrictions and independent unlock-key/recovery-media custody.
4. **Root/emergency recovery:** choose acceptable boot recovery and administrative
   authentication without silently locking out legitimate repair access.
5. **Capability reduction:** decide whether River/primary truly need administrator,
   libvirt, input injection and network-management rights; defaults are preserved.
6. **Real SOPS custody/rotation:** authorize any actual backup recipient enrollment,
   decryption, rotation and restore drill separately. No audit script may infer
   authorization from the existence of a key path.

No owner decision is resolved by a passing evaluation, a cached VM result, or a
source-level permission declaration. Record approved policy and its disposable
runtime test before touching the live machine.
