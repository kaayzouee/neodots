<!--
SPDX-License-Identifier: GPL-3.0-only

Neodots - Age identity backup, SOPS recovery and safe recipient rotation.

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

# SOPS recovery

## What exists and what does not

Personal configuration imports [git.nix](../../modules/personal/git.nix) through
[home.nix](../../hosts/nixos/home.nix). SOPS decrypts Git identity, signing-key
identifier and SMTP fields at **user activation/login**, not during Nix
evaluation. The GPG private signing key and GitHub CLI login are separate state;
SOPS's signingkey field alone is not a GPG private-key backup.

The age private key is `~/.config/sops/age/keys.txt`. The repository neither
creates it automatically nor contains a recoverable private key. The public
[recipient policy](../../.sops.yaml) declares a single recipient; this audit did
not inspect encrypted payloads or verify their actual metadata. The owner must
verify policy/ciphertext agreement locally without sharing plaintext.

Formatting the filesystem that holds the sole private key can make encrypted
secrets permanently unrecoverable. A newly generated key has a new recipient
and **cannot** decrypt ciphertext encrypted only to the old recipient. This is
a likely failure mechanism, not a confirmed forensic diagnosis of a past format.

## Recovery model

Keep the daily-use age identity on the machine with owner-only access. Maintain
an independently protected backup outside its disk. Prefer an independently
authorized **offline recovery recipient** so loss of the online identity does
not require the running system to hold the recovery private key.

- Existing authorized key: restore its path/ownership/mode, then activate SOPS.
- Protected backup: restore the exact original identity; ciphertext need not change.
- Independent authorized recovery recipient: use it on a trusted recovery system
  to re-encrypt for a new machine recipient, then return it offline.
- All authorized private keys lost: encrypted data cannot be recovered. Reissue
  Git/SMTP/provider credentials with the respective providers, create a new age
  identity, and encrypt newly supplied values. Do not install empty credentials
  or turn off authentication to make activation succeed.

No backup or recipient change was performed on production credentials by this
project. The owner must choose backup media, custodians and recovery recipients.

## Initial setup (owner action)

Use a trusted terminal, no shell tracing, no screen sharing of private material.
For a **new identity only**, not as a substitute for restoring a lost key:

```sh
umask 077
install -d -m 700 "$HOME/.config/sops/age"
age-keygen -o "$HOME/.config/sops/age/keys.txt"
chmod 600 "$HOME/.config/sops/age/keys.txt"
# Prints only the public recipient. Compare with your intended policy.
age-keygen -y "$HOME/.config/sops/age/keys.txt"
```

Refuse to overwrite an existing identity. `age-keygen -o` also refuses an
existing output. Register the **public** recipient in [.sops.yaml](../../.sops.yaml).
Changing that file alone does not change recipients on existing ciphertext.
An already authorized identity must run `sops updatekeys` on the encrypted file.
Do not commit plaintext or an editor backup; SOPS editing still requires a
trusted local editor and temporary storage.

## Protected backup and verification

Use an encrypted offline volume or encrypted backup service with a separate,
recoverable access method. Do not rely on a single laptop disk, a public Git
repository, a plaintext cloud sync folder or an SSH key on the same lost device.
Back up the age identity, GPG signing identity if needed, recovery codes and
hardware/storage recovery information according to their separate policies.
Do not put a backup decryption password next to its encrypted backup.

Backup directories should be mode 0700 and key files 0600 (0400 is also accepted
by the runtime guard). The restore must be owned by the target interactive user,
not root. Verify recipient and test a restore on a disposable trusted system.
Do not print private keys, run `git diff` on decrypted data, or upload diagnostics
containing credential files. Protect backup retention and old ciphertext copies.

## Clean installation or disk-format recovery

1. Keep `neodots.personal.enable = false` while installing/evaluating a machine
   that does not have an authorized identity. This deliberately omits personal
   Git/SMTP secrets, not a plaintext fallback.
2. Restore your own generated hardware scan; never use the CI fixture. Follow
   [README.md](../../README.md) before building or choosing a boot generation.
3. Unlock/mount the protected backup yourself. As the target user, copy **only**
   the authorized age identity into `~/.config/sops/age/keys.txt` with `install
   -m 600`. Make the directory 0700. If restoring as root, explicitly set owner
   and group to the target user. Do not paste any private content into an issue.
4. Compare `age-keygen -y` output with the expected public recipient. Verify
   decryption with output discarded:

   ```sh
   SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" \
     sops decrypt secrets/secrets.yaml >/dev/null
   ```

   Run from your checkout. Never use `tee`, command substitution, `nix eval`,
   `git config --list`, or debug logging to inspect decrypted values.
5. Re-enable personal configuration, build it, and review before activation.
   Once Home Manager is deployed, retry `systemctl --user restart sops-nix` and
   inspect **status only**. A missing key, wrong key, owner mismatch or loose
   file mode must fail; it must not create a replacement identity.
6. Restore GPG/SSH/GitHub/browser state separately as needed. Verify signing or
   authentication with a synthetic/non-sensitive operation, never a credential
   dump. SMTP provider reauthorization may be necessary after a compromise.

## Impermanence and mount ordering

When personal configuration **and** persistence are enabled,
[persistence.nix](../../modules/system/persistence.nix) persists the primary
user's `.config/sops/age` directory with mode 0700. The private key is still
0600/0400; it is not a store path. A declared nonvolatile persistence filesystem
with `neededForBoot = true` is required so its bind mount is available before
user activation. `/var/lib/sops-nix` is not a substitute for this Home Manager key.

This protects against loss of ephemeral **home/root state only when the backing
persistence filesystem survives**. Formatting that filesystem or losing the
whole disk still requires the external backup. Persistence is not a backup.
Current host persistence remains disabled. No automatic root-reset service is
installed. The VM test exercises a disposable backing disk, mount ordering,
missing/restored keys and a reboot; it does not format or reset a real root.
Broader impermanence identity/application state remains an owner-reviewed task.

## Recipient rotation (deliberate owner operation)

1. Create the new identity on its intended trusted system and verify the public
   recipient out of band. Keep the current authorized identity available.
2. Add the new public recipient to policy; use the current authorized identity
   to run `sops updatekeys secrets/secrets.yaml`. Verify both identities decrypt
   with output discarded. Record the change without secret contents.
3. Store the recovery identity offline; the running laptop needs only its daily
   identity. Test recovery before removing any old recipient.
4. Remove the old recipient from policy and update existing ciphertext. Rotate
   the SOPS data-encryption key (`sops rotate --in-place secrets/secrets.yaml`)
   under the retained authorized identity. Verify the new identity succeeds
   and the removed identity fails against the **new** ciphertext.
5. Removal cannot revoke access to old Git revisions/backups already decryptable
   by the old identity. If compromise is suspected, rotate/revoke actual provider
   credentials too. SOPS recipient rotation alone does not change an SMTP password.

The automated rotation test does this only with disposable keys and synthetic
values. It never modifies [.sops.yaml](../../.sops.yaml) or production ciphertext.

## Exposure and common failures

Decrypted files/templates are mode 0400 under `$XDG_RUNTIME_DIR/secrets.d`, linked
from `~/.config/sops-nix/secrets`. They are readable by the user and root, and by
malware running as that user; SOPS is not an application sandbox. The Git SMTP
password remains in a runtime-only private include to preserve working behavior.
`git config --list` can expose it, so never include that output in logs. Moving
to a runtime credential helper requires an integration-tested SMTP policy change;
it is not automatically safer against a compromised same-UID process.

| Failure | Safe response |
| --- | --- |
| Missing key after format | Restore exact authorized backup or use independent recipient; do not generate a replacement and expect recovery. |
| Wrong recipient/key | Check public identity and encrypted recipient policy locally; do not post ciphertext diagnostics with private key material. |
| Key owned by root or mode 0644 | Correct owner and set 0600/0400 yourself; runtime guard does not chmod or rotate active credentials. |
| Persistence mount absent/volatile | Fix declarative topology and evaluate before booting; never bypass assertion. |
| User systemd manager absent | Activation may defer SOPS until login; verify user manager and runtime directory first. |
| Git config missing/stale secrets | Check SOPS service status and rendered file permissions, not contents; restore/activate SOPS before Git use. |
| All identities lost | Recreate provider credentials and encrypt new values. No secure automatic fallback exists. |

Tests: `nix build .#checks.x86_64-linux.sops-recovery` runs A–D, runtime-manifest
exposure checks and H. `security-persistence-vm` covers mounted persistence,
Home Manager runtime templates and permissions/authentication. `config-invariants`
covers nonpersonal evaluation and persistence prerequisites. See
[FINAL-REPORT.md](../audits/FINAL-REPORT.md) for actual run status and limitations.
