#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Offline DSH installer regression check using disposable profiles.
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

import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile


def mock_dsh():
    assert sys.argv[2:8] == ["plugin", "--profile", "web", "add", "--save-exact", "--ignore-scripts"]
    source = sys.argv[8]
    name, version = json.loads(os.environ["TEST_PINS"])[source]
    profile = Path(os.environ.get("DSH_HOME", Path.home() / ".dsh")) / "profiles/web"
    manifest = profile / "node_modules" / name / "package.json"
    manifest.parent.mkdir(parents=True, exist_ok=True)
    installed_version = "0.0.0" if os.environ.get("TEST_BAD_VERSION") else version
    manifest.write_text(json.dumps({"name": name, "version": installed_version}))
    package = profile / "package.json"
    data = json.loads(package.read_text()) if package.exists() else {}
    data.setdefault("dependencies", {})[name] = source if source.startswith("github:") else version
    package.write_text(json.dumps(data))
    with open(os.environ["TEST_LOG"], "a") as log:
        log.write(source + "\n")


def main():
    with tempfile.TemporaryDirectory(prefix="neodots-dsh-test-") as temporary:
        root = Path(temporary)
        # Never inherit DSH_HOME, npm settings, or the real user's HOME.
        env = {"PATH": os.environ["PATH"], "HOME": str(root / "home")}
        Path(env["HOME"]).mkdir()
        if len(sys.argv) == 2:
            script = Path(sys.argv[1]).read_text()
        else:
            module = Path(__file__).resolve().parents[1] / "modules/programs/deepseek-harness.nix"
            expression = '''
              let module = import %s {
                config.home.homeDirectory = "/unused";
                pkgs = {
                  deepseek-harness = null; nodejs_24 = null; pnpm_11 = null;
                  writeShellApplication = args: args.text;
                };
              }; in builtins.elemAt module.home.packages 1
            ''' % json.dumps(str(module))
            script = json.loads(subprocess.check_output(
                ["nix-instantiate", "--eval", "--strict", "--json", "--expr", expression],
                env=env, text=True,
            ))
        installer = root / "installer.sh"
        installer.write_text(script)
        pins = [shlex.split(line.strip())[1:] for line in script.splitlines()
                if line.strip().startswith("install_plugin ")]
        assert any(name.startswith("@") for name, _, _ in pins)
        assert any(source.startswith("github:") for _, _, source in pins)
        mock = root / "bin/dsh"
        mock.parent.mkdir()
        mock.write_text("#!/bin/sh\nexec " + shlex.join([
            sys.executable, str(Path(__file__).resolve()), "--mock-dsh",
        ]) + ' "$@"\n')
        mock.chmod(0o700)
        env.update(PATH=str(mock.parent) + ":" + env["PATH"],
                   DSH_HOME=str(root / "profile"), TEST_LOG=str(root / "calls"),
                   TEST_PINS=json.dumps({source: [name, version] for name, version, source in pins}))

        def run(expected, succeeds=True):
            Path(env["TEST_LOG"]).write_text("")
            result = subprocess.run(["bash", str(installer)], env=env,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            assert (result.returncode == 0) == succeeds, result.stderr
            actual = Path(env["TEST_LOG"]).read_text().splitlines()
            assert actual == expected, (actual, expected)

        sources = [source for _, _, source in pins]
        run(sources)
        run([])
        profile = Path(env["DSH_HOME"]) / "profiles/web"
        for name, version, source in pins:
            manifest = profile / "node_modules" / name / "package.json"
            for wrong in ({"name": name, "version": "0.0.0"},
                          {"name": "wrong-package", "version": version}):
                manifest.write_text(json.dumps(wrong))
                run([source])
                run([])
            package = profile / "package.json"
            data = json.loads(package.read_text())
            data["dependencies"][name] = (source + "-wrong" if source.startswith("github:")
                                           else "^" + version)
            package.write_text(json.dumps(data))
            run([source])
            run([])
            manifest.unlink()
            run([source])
        # A package manager returning the wrong version must fail closed.
        (profile / "node_modules" / pins[0][0] / "package.json").unlink()
        env["TEST_BAD_VERSION"] = "1"
        run(sources[:1], succeeds=False)
        del env["TEST_BAD_VERSION"]
        run(sources[:1])
        # Exercise the HOME/.dsh fallback without touching any real profile.
        del env["DSH_HOME"]
        run(sources)
        run([])
        print("DSH installer: fresh install, scoped npm/Git pins, mismatches, missing manifests, "
              "HOME fallback and idempotence passed (offline disposable profiles).")


if __name__ == "__main__":
    if sys.argv[1:2] == ["--mock-dsh"]:
        mock_dsh()
    else:
        main()
