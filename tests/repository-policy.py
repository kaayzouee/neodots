#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Static CI pin, hardware boundary and private-artifact regression checks.
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

"""Source policy, not a general secret scanner or proof of runtime security."""

import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
PRIVATE = re.compile(r"^(?:-----BEGIN (?:[A-Z]+ )*PRIVATE KEY-----|AGE-SECRET-KEY-[A-Z0-9]+)", re.M)
ACTION = re.compile(r"^\s*(?:-\s*)?uses:\s*([^\s#]+)", re.M)


def pinned_action(source):
    return source.startswith("./") or re.fullmatch(r"[^@]+@[0-9a-f]{40}", source) is not None


def main():
    assert pinned_action("actions/checkout@" + "a" * 40)
    assert not pinned_action("actions/checkout@v4")
    assert PRIVATE.search("AGE-SECRET-KEY-" + "A" * 50)
    assert not PRIVATE.search("public recipient: age1example")
    failures = []
    if (ROOT / ".git").exists():
        paths = [ROOT / p for p in subprocess.check_output(
            ["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0") if p]
    else:
        paths = [p for p in ROOT.rglob("*") if p.is_file()]
    for path in paths:
        rel = path.relative_to(ROOT).as_posix()
        if path.name in {"keys.txt", "id_rsa", "id_ed25519", "credentials.json"} or path.suffix in {".pem", ".p12", ".pfx", ".decrypted"}:
            failures.append(f"{rel}: private/authentication artifact must not be tracked")
        # Never inspect production encrypted payloads, and do not decode binary assets.
        if rel.startswith("secrets/") or path.suffix in {".svg", ".png", ".jpg", ".webp"}:
            continue
        try:
            text = path.read_text()
        except UnicodeDecodeError:
            continue
        if PRIVATE.search(text):
            failures.append(f"{rel}: private-key material detected (value suppressed)")
        if rel.startswith(".github/workflows/"):
            for action in ACTION.findall(text):
                if not pinned_action(action):
                    failures.append(f"{rel}: external action lacks immutable commit pin")
            if "pull_request_target:" in text:
                failures.append(f"{rel}: privileged PR trigger needs a separate security review")
            if "cat > hardware-configuration.nix" in text:
                failures.append(f"{rel}: CI must select a fixture, not overwrite production hardware")
    lock = json.loads((ROOT / "flake.lock").read_text())
    for name, node in lock["nodes"].items():
        if "locked" in node and "narHash" not in node["locked"]:
            failures.append(f"flake.lock: {name} lacks a content hash")
    module = (ROOT / "modules/programs/deepseek-harness.nix").read_text()
    for revision in re.findall(r"github:[^\s\"#]+#([^\s\"]+)", module):
        if not re.fullmatch(r"[0-9a-f]{40}", revision):
            failures.append("DSH plugin Git source lacks a full immutable commit")
    ignored = (ROOT / ".gitignore").read_text().splitlines()
    if "hardware-configuration.nix" in ignored or "/hardware-configuration.nix" in ignored:
        failures.append("tracked owner hardware must not simultaneously be ignored")
    if failures:
        raise SystemExit("\n".join(f"FAIL: {f}" for f in failures))
    print("PASS: immutable CI/plugin pins, hardware separation and private-artifact policy")


if __name__ == "__main__":
    main()
