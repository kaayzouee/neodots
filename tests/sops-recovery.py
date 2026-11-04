#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Disposable age/SOPS recovery and runtime installer integration tests.
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

"""No production files, ambient credentials, plaintext diagnostics or store outputs."""

import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import stat
import subprocess
import tempfile


def main():
    os.umask(0o077)
    with tempfile.TemporaryDirectory(prefix="neodots-sops-") as directory:
        root = Path(directory).resolve()
        env = {
            "PATH": os.environ["PATH"],
            "HOME": str(root / "home"),
            "XDG_CONFIG_HOME": str(root / "home/.config"),
            "XDG_RUNTIME_DIR": str(root / "runtime"),
            "GNUPGHOME": str(root / "gnupg"),
        }
        for name in ("home", "runtime", "gnupg", "backup"):
            (root / name).mkdir(mode=0o700)

        def run(label, args, *, key=None, data=None, succeeds=True):
            child_env = dict(env, SOPS_AGE_KEY_FILE=str(key or root / "absent-key"))
            result = subprocess.run(args, input=data, capture_output=True, env=child_env)
            if (result.returncode == 0) != succeeds:
                # Never include subprocess diagnostics: they may contain test plaintext.
                raise AssertionError(f"{label}: unexpected exit status {result.returncode}")
            return result.stdout

        def make_key(name):
            path = root / name
            run("create disposable key", ["age-keygen", "-o", str(path)])
            assert stat.S_IMODE(path.stat().st_mode) == 0o600, "private key mode"
            public = run("derive public recipient", ["age-keygen", "-y", str(path)])
            return path, public.decode().strip()

        key_a, pub_a = make_key("machine-key")
        key_b, pub_b = make_key("recovery-key")
        run("private key guard accepts mode 0600", ["check-sops-age-key", str(key_a)])
        key_a.chmod(0o400)
        run("private key guard accepts mode 0400", ["check-sops-age-key", str(key_a)])
        key_a.chmod(0o644)
        run("private key guard rejects public mode", ["check-sops-age-key", str(key_a)], succeeds=False)
        key_a.chmod(0o600)
        run("private key guard rejects absent key", ["check-sops-age-key", str(root / "absent-key")], succeeds=False)
        sentinel = secrets.token_hex(32)
        encrypted = root / "encrypted.json"
        encrypted.write_bytes(run("encrypt synthetic secret", [
            "sops", "encrypt", "--age", pub_a, "--input-type", "json", "--output-type", "json", "/dev/stdin",
        ], data=json.dumps({"value": sentinel}).encode()))
        original_digest = hashlib.sha256(encrypted.read_bytes()).digest()
        assert sentinel.encode() not in encrypted.read_bytes(), "plaintext in ciphertext"

        def decrypt(key, succeeds=True):
            plaintext = run("decrypt synthetic secret", ["sops", "decrypt", str(encrypted)],
                            key=key, succeeds=succeeds)
            if succeeds:
                assert json.loads(plaintext)["value"] == sentinel, "incorrect recovered value"
            else:
                assert sentinel.encode() not in plaintext, "plaintext on failed decryption"

        def install(name, key, succeeds=True):
            target = root / name
            target.mkdir(mode=0o700)
            placeholder = "<SOPS:synthetic:PLACEHOLDER>"
            manifest = {
                "secrets": [{"name": "value", "key": "value", "path": str(target / "secrets/value"),
                             "sopsFile": str(encrypted), "format": "json", "mode": "0400"}],
                "templates": [{"name": "identity.conf", "content": "token=" + placeholder,
                               "path": str(target / "identity.conf"), "mode": "0400"}],
                "placeholderBySecretName": {"value": placeholder},
                "secretsMountPoint": str(target / "generations"),
                "symlinkPath": str(target / "secrets"), "keepGenerations": 1,
                "ageKeyFile": str(key), "userMode": True,
                "logging": {"keyImport": False, "secretChanges": False},
            }
            manifest_path = target / "manifest.json"
            manifest_path.write_text(json.dumps(manifest))
            assert sentinel not in manifest_path.read_text(), "plaintext in activation manifest"
            run("runtime sops-nix installation", ["sops-install-secrets", "-ignore-passwd", str(manifest_path)],
                key=key, succeeds=succeeds)
            if succeeds:
                for path in (target / "secrets/value", target / "identity.conf"):
                    assert stat.S_IMODE(path.stat().st_mode) == 0o400, "decrypted file mode"
                    assert path.stat().st_uid == os.getuid(), "decrypted file owner"
                    assert sentinel in path.read_text(), "runtime template substitution"
            else:
                assert not (target / "secrets/value").exists(), "plaintext fallback"
                assert not (target / "identity.conf").exists(), "template fallback"

        # A/B/C: correct key, no key, unrelated key. No inherited provider or SSH keys.
        decrypt(key_a)
        install("valid", key_a)
        decrypt(root / "absent-key", False)
        install("missing", root / "absent-key", False)
        assert not (root / "absent-key").exists(), "silently generated replacement key"
        decrypt(key_b, False)
        install("incorrect", key_b, False)
        print("PASS A/B/C: authorized runtime files are private; missing/wrong keys fail closed")

        # D: backup is separate from the disposable machine-local key state.
        backup = root / "backup/key"
        shutil.copyfile(key_a, backup)
        backup.chmod(0o600)
        assert key_a.parent == root, "refuse deletion outside disposable test root"
        key_a.unlink()
        decrypt(key_a, False)
        install("reinstalled-without-key", key_a, False)
        shutil.copyfile(backup, key_a)
        key_a.chmod(0o600)
        decrypt(key_a)
        install("restored", key_a)
        assert hashlib.sha256(encrypted.read_bytes()).digest() == original_digest, "restore changed ciphertext"
        print("PASS D: reinstall fails without key; separate backup restores unchanged ciphertext")

        # G: manifests/templates contain placeholders, never plaintext; files are rendered at runtime.
        for artifact in root.glob("*/manifest.json"):
            assert sentinel not in artifact.read_text(), "plaintext in activation artifact"
        print("PASS G (runtime manifest scope): synthetic plaintext is absent from activation manifests")

        # H: authorize a separate recipient, then remove and rotate the original.
        policy = root / "policy.yaml"
        policy.write_text(f"creation_rules:\n  - age: '{pub_a},{pub_b}'\n")
        run("add recovery recipient", ["sops", "--config", str(policy), "updatekeys", "--yes", str(encrypted)], key=key_a)
        decrypt(key_a)
        decrypt(key_b)
        policy.write_text(f"creation_rules:\n  - age: '{pub_b}'\n")
        run("remove old recipient", ["sops", "--config", str(policy), "updatekeys", "--yes", str(encrypted)], key=key_b)
        run("rotate data key", ["sops", "rotate", "--in-place", str(encrypted)], key=key_b)
        decrypt(key_b)
        decrypt(key_a, False)
        print("PASS H: both authorized recipients decrypt; removed recipient fails after rotation")


if __name__ == "__main__":
    main()
