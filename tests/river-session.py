#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Synthetic River session lifecycle regression check.
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
import signal
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "modules/desktop/river/session.sh"
STUB = '''#!/usr/bin/env python3
import os, pathlib, signal, sys, time
name = pathlib.Path(sys.argv[0]).name
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(name + " " + " ".join(sys.argv[1:]) + "\\n")
if name == "wlr-randr" and len(sys.argv) == 1:
    print("HEADLESS-1 connected\\n  1920x1080")
if name == "systemctl" and "start" in sys.argv and os.environ.get("FAIL_START"):
    sys.exit(1)
if name == "systemctl" and "reset-failed" in sys.argv and os.environ.get("FAIL_RESET"):
    sys.exit(1)
if name == "kwm":
    if os.environ["MODE"] == "signal":
        print("kwm-ready", flush=True)
        time.sleep(30)
    sys.exit(int(os.environ.get("KWM_EXIT", "0")))
'''

with tempfile.TemporaryDirectory(prefix="river-session-test-") as temporary:
    work = Path(temporary)
    for name in ("systemctl", "wlr-randr", "kwm"):
        binary = work / name
        binary.write_text(STUB.replace("#!/usr/bin/env python3", f"#!{sys.executable}", 1))
        binary.chmod(0o755)

    for mode, status in (("normal", 0), ("fresh-manager", 0), ("failure", 7), ("start-failure", 1), ("signal", 143)):
        log = work / f"{mode}.log"
        env = os.environ | {
            "PATH": str(work) + os.pathsep + os.environ["PATH"],
            "TEST_LOG": str(log), "MODE": mode,
            "KWM_EXIT": "7" if mode == "failure" else "0",
        }
        if mode == "start-failure":
            env["FAIL_START"] = "1"
        if mode == "fresh-manager":
            env["FAIL_RESET"] = "1"
        process = subprocess.Popen(["bash", str(SCRIPT)], env=env,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                   start_new_session=True)
        try:
            if mode == "signal":
                assert select.select([process.stdout], [], [], 5)[0], "KWM never started"
                assert process.stdout.readline().strip() == "kwm-ready"
                process.send_signal(signal.SIGTERM)
            stdout, stderr = process.communicate(timeout=5)
            assert process.returncode == status, (mode, process.returncode, stdout, stderr)
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate(timeout=5)
        events = log.read_text().splitlines()
        imported = next(i for i, line in enumerate(events) if "import-environment" in line)
        started = events.index("systemctl --user start neodots-river-session.target")
        stopped = events.index("systemctl --user stop neodots-river-session.target")
        assert imported < started < stopped, events
        assert events.count("systemctl --user stop neodots-river-session.target") == 1
        assert "wlr-randr --output HEADLESS-1 --scale 1.5" in events
        if mode == "start-failure":
            assert "kwm " not in events
        else:
            assert started < events.index("kwm ") < stopped
print("River session startup, failure, scale and signal cleanup checks passed.")
