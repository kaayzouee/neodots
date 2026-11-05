#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Check native Quickshell source reload in a disposable environment.
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

import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time

if len(sys.argv) != 2:
    raise SystemExit("usage: python3 tests/river-quickshell.py /path/to/qs")

with tempfile.TemporaryDirectory(prefix="river-quickshell-test-") as temporary:
    work = Path(temporary)
    source = work / "live"
    source.mkdir()
    runtime = work / "runtime"
    runtime.mkdir(mode=0o700)
    qml = source / "shell.qml"

    def save(marker):
        # Component.onCompleted runs before Quickshell installs its file watcher.
        # Emit readiness from the event loop after initial setup instead, so
        # rewriting the file cannot race the watch registration.
        qml.write_text('import QtQuick\nimport Quickshell\nShellRoot {\n'
                       '  Timer {\n'
                       '    interval: 100\n'
                       '    running: true\n'
                       '    repeat: false\n'
                       f'    onTriggered: console.log("{marker}")\n'
                       '  }\n'
                       '}\n')

    save("NEODOTS_RELOAD_A")
    env = os.environ | {
        "HOME": str(work), "XDG_RUNTIME_DIR": str(runtime),
        "XDG_CONFIG_HOME": str(work / "config"), "XDG_CACHE_HOME": str(work / "cache"),
        "XDG_STATE_HOME": str(work / "state"), "QT_QPA_PLATFORM": "offscreen",
    }
    env.pop("QS_DISABLE_FILE_WATCHER", None)
    env.pop("WAYLAND_DISPLAY", None)
    env.pop("DISPLAY", None)
    process = subprocess.Popen([sys.argv[1], "--no-color", "-p", str(source)], env=env,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = bytearray()

    def wait_for(marker):
        deadline = time.monotonic() + 10
        while marker.encode() not in output:
            remaining = deadline - time.monotonic()
            assert remaining > 0, output.decode(errors="replace")
            if select.select([process.stdout], [], [], remaining)[0]:
                chunk = os.read(process.stdout.fileno(), 4096)
                assert chunk, output.decode(errors="replace")
                output.extend(chunk)

    try:
        wait_for("NEODOTS_RELOAD_A")
        save("NEODOTS_RELOAD_B")
        wait_for("NEODOTS_RELOAD_B")
        assert process.poll() is None, "Reload terminated Quickshell"
    finally:
        process.terminate()
        try:
            process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate()
print("Quickshell -p loads and natively reloads the same live source without a restart.")
