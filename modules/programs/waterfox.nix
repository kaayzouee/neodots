# SPDX-License-Identifier: GPL-3.0-only

{ lib, pkgs, ... }:

{
  home.file.".config/neodots/waterfox/user.js".source = ../../config/waterfox/user.js;

  home.activation.neodotsWaterfoxPrefs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.python3}/bin/python3 - <<'PY'
    import configparser
    import os
    import re
    from pathlib import Path

    home = Path(os.environ["HOME"])
    managed_file = home / ".config/neodots/waterfox/user.js"

    if not managed_file.is_file():
        raise SystemExit(0)

    managed_text = managed_file.read_text(encoding="utf-8").strip()

    begin = "// BEGIN NEODOTS WATERFOX PREFERENCES"
    end = "// END NEODOTS WATERFOX PREFERENCES"

    pref_re = re.compile(
        r"""^\s*user_pref\(\s*["']([^"']+)["']\s*,"""
    )

    managed_names = {
        match.group(1)
        for line in managed_text.splitlines()
        if (match := pref_re.match(line))
    }

    managed_block = (
        begin + "\n"
        + managed_text + "\n"
        + end
    )

    roots = [
        home / ".waterfox",
        home / ".var/app/net.waterfox.waterfox/.waterfox",
    ]

    installed = 0

    for root in roots:
        profiles_ini = root / "profiles.ini"

        if not profiles_ini.is_file():
            continue

        parser = configparser.ConfigParser(interpolation=None)
        parser.read(profiles_ini, encoding="utf-8")

        profiles = []

        for section in parser.sections():
            if not section.startswith("Profile"):
                continue

            path_text = parser.get(section, "Path", fallback="")
            if not path_text:
                continue

            path = Path(path_text).expanduser()

            if parser.getboolean(
                section, "IsRelative", fallback=True
            ):
                path = root / path

            if path.is_dir() and path not in profiles:
                profiles.append(path)

        for profile in profiles:
            target = profile / "user.js"
            existing = (
                target.read_text(encoding="utf-8")
                if target.is_file()
                else ""
            )

            # Remove the previous Neodots-managed section.
            while begin in existing and end in existing:
                before, remainder = existing.split(begin, 1)
                _, after = remainder.split(end, 1)
                existing = before + after

            # Remove old duplicate definitions of preferences that
            # are now centrally managed by the repository.
            preserved = []

            for line in existing.splitlines():
                match = pref_re.match(line)

                if match and match.group(1) in managed_names:
                    continue

                preserved.append(line)

            existing = "\n".join(preserved).strip()

            result = (
                existing + "\n\n" if existing else ""
            ) + managed_block + "\n"

            target.write_text(result, encoding="utf-8")
            installed += 1

    if installed:
        print(
            "Neodots: managed Waterfox preferences installed in "
            + str(installed) + " profile(s)."
        )
    else:
        print(
            "Neodots: no existing Waterfox profiles found; "
            "start Waterfox once and run Home Manager activation again."
        )
    PY
  '';
}
