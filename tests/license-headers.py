#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - checks (and inserts) the GNU GPL v3 header on every source file.
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

"""Usage:
    tests/license-headers.py                 check every tracked file
    tests/license-headers.py add FILE DESC   insert or replace the header

A header must contain the SPDX identifier, a "Neodots - <description>" line,
the copyright and author lines, and the GPL v3 notice, all before the code.
Files that cannot hold comments are listed in REUSE.toml and skipped.
"""

import fnmatch
import pathlib
import subprocess
import sys
import textwrap
import tomllib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SKIP_NAMES = {"LICENSE", "hardware-configuration.nix"}  # text / generated
SPDX = "SPDX-License-Identifier: GPL-3.0-only"
NOTICE = [
    "This program is free software: you can redistribute it and/or modify it",
    "under the terms of the GNU General Public License as published by the",
    "Free Software Foundation, version 3 of the License.",
    "",
    "This program is distributed in the hope that it will be useful, but",
    "WITHOUT ANY WARRANTY; without even the implied warranty of",
    "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General",
    "Public License for more details.",
    "",
    "You should have received a copy of the GNU General Public License along",
    "with this program. If not, see <https://www.gnu.org/licenses/>.",
]
LINE = {
    "nix": "#", "sh": "#", "yml": "#", "yaml": "#", "toml": "#", "py": "#",
    "ini": "#", "gitignore": "#", "qmldir": "#",
    "qml": "//", "js": "//", "jsonc": "//", "zon": "//",
}


def kind(path):
    name = pathlib.Path(path).name
    ext = name.rsplit(".", 1)[-1] if "." in name else name
    if ext in LINE:
        return "line", LINE[ext]
    if ext == "css":
        return "css", None
    if ext == "md":
        return "html", None
    if ext == "txt":
        return "plain", None
    return None, None


def header_lines(desc):
    body = textwrap.wrap(desc, 66)
    out = [SPDX, "", "Neodots - " + body[0]] + ["         " + b for b in body[1:]]
    out += ["", "Copyright (C) 2026 kaayzouee", "Author: https://github.com/kaayzouee", ""]
    return out + NOTICE


def render(path, desc):
    k, c = kind(path)
    lines = header_lines(desc)
    if k == "line":
        return [(c + " " + l).rstrip() for l in lines]
    if k == "css":
        return ["/*"] + [(" * " + l).rstrip() for l in lines] + [" */"]
    if k == "html":
        return ["<!--"] + lines + ["-->"]
    return lines + [""]


def reuse_skips():
    cfg = tomllib.loads((ROOT / "REUSE.toml").read_text())
    pats = []
    for a in cfg.get("annotations", []):
        p = a["path"]
        pats += p if isinstance(p, list) else [p]
    return pats


def skipped(rel, pats):
    return pathlib.Path(rel).name in SKIP_NAMES or any(
        fnmatch.fnmatch(rel, p.replace("**", "*")) for p in pats
    )


def check_text(rel, text):
    head = "\n".join(text.split("\n")[:40])
    problems = []
    for needle, label in [
        (SPDX, "SPDX identifier"),
        ("Neodots - ", "'Neodots - <description>' line"),
        ("Copyright (C) 2026 kaayzouee", "copyright line"),
        ("GNU General Public License", "GPL notice"),
        ("WITHOUT ANY WARRANTY", "warranty disclaimer"),
    ]:
        if needle not in head:
            problems.append("missing " + label)
    return problems


def check():
    pats = reuse_skips()
    files = subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True).split()
    bad = 0
    for rel in files:
        if skipped(rel, pats) or kind(rel)[0] is None:
            if kind(rel)[0] is None and not skipped(rel, pats):
                print(f"UNCOVERED  {rel}: unknown file type; add it to REUSE.toml")
                bad += 1
            continue
        problems = check_text(rel, (ROOT / rel).read_text(errors="replace"))
        if problems:
            bad += 1
            print(f"FAIL  {rel}: {', '.join(problems)}")
    print(f"{len(files)} files checked, {bad} problem(s)")
    return 1 if bad else 0


def add(rel, desc):
    path = ROOT / rel
    lines = path.read_text().split("\n")
    shebang = [lines.pop(0)] if lines and lines[0].startswith("#!") else []
    # Drop a previous short header (SPDX / Copyright / Author lines).
    strip = lambda l: l.strip().removeprefix("<!--").removesuffix("-->").strip().lstrip("#/ ").strip()
    while lines and strip(lines[0]).startswith(("SPDX-License-Identifier", "Copyright (C)", "Author:")):
        lines.pop(0)
    while lines and not lines[0].strip():
        lines.pop(0)
    new = shebang + render(rel, desc) + [""] + lines
    path.write_text("\n".join(new))


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "add":
        add(sys.argv[2], sys.argv[3])
    elif len(sys.argv) == 1:
        sys.exit(check())
    else:
        sys.exit(__doc__)
