# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Home Manager configuration for the river user (River, kwm and
#          Quickshell session).
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

{ lib, pkgs, ... }:

{
  home.stateVersion = "26.11";

  programs.home-manager.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    silent = true;
  };

  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set -g fish_greeting 'Hello, world! ♡'

      if not set -q TMUX
        exec tmux new-session -A -s main
      end
    '';
  };

  imports = [
    ../../modules/programs/waterfox.nix
    ../../modules/desktop/river/home.nix
    ../../modules/programs/tmux.nix
    ../../modules/programs/nano.nix
    ../../modules/programs/alacritty.nix
    ../../modules/programs/fish.nix
  ];

  programs.vscode = {
    enable = true;
    mutableExtensionsDir = false;

    profiles.default.extensions =
      (with pkgs.vscode-extensions; [
        # Nix
        jnoortheen.nix-ide
        arrterian.nix-env-selector

        # direnv
        mkhl.direnv

        # C / C++ / Qt
        llvm-vs-code-extensions.vscode-clangd
        ms-vscode.cpptools-extension-pack

        # Rust
        rust-lang.rust-analyzer
        tamasfe.even-better-toml

        # Python
        ms-python.python
        ms-python.vscode-pylance
      ])
      ++ [
        pkgs.vscode-extensions."13xforever"."language-x86-64-assembly"
      ]
      ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          name = "nix-extension-pack";
          publisher = "pinage404";
          version = "3.0.0";
          sha256 = "sha256-cWXd6AlyxBroZF+cXZzzWZbYPDuOqwCZIK67cEP5sNk=";
        }
      ];
  };

  home.packages = with pkgs; [
    nixd
    alacritty
  ];

  # Waterfox's own chrome hosts the traffic lights. Home Manager keeps the
  # stylesheet in the repo-managed config tree; activation merges it into each
  # existing Waterfox profile without replacing any personal userChrome rules.
  home.file.".config/neodots/waterfox/userChrome.css".source = ../../config/waterfox/userChrome.css;

  home.activation.neodotsWaterfoxChrome = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.python3}/bin/python3 - <<'PY'
    import configparser
    import os
    from pathlib import Path

    home = Path(os.environ["HOME"])
    managed_css = home / ".config/neodots/waterfox/userChrome.css"
    if not managed_css.is_file():
        raise SystemExit(0)

    begin = "/* BEGIN NEODOTS WATERFOX TRAFFIC LIGHTS */"
    end = "/* END NEODOTS WATERFOX TRAFFIC LIGHTS */"
    required_prefs = {
        "toolkit.legacyUserProfileCustomizations.stylesheets": "true",
        "browser.tabs.drawInTitlebar": "true",
        "widget.gtk.non-native-titlebar-buttons.enabled": "true",
    }

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
        parser.read(profiles_ini)

        profiles = []
        for section in parser.sections():
            if not section.startswith("Profile"):
                continue
            profile_path = parser.get(section, "Path", fallback="")
            if not profile_path:
                continue
            if parser.getboolean(section, "IsRelative", fallback=True):
                profile = root / profile_path
            else:
                profile = Path(profile_path).expanduser()
            if profile.is_dir() and profile not in profiles:
                profiles.append(profile)

        for profile in profiles:
            chrome_dir = profile / "chrome"
            chrome_dir.mkdir(parents=True, exist_ok=True)
            css_path = chrome_dir / "userChrome.css"
            existing_css = css_path.read_text() if css_path.is_file() else ""
            while begin in existing_css and end in existing_css:
                before, remainder = existing_css.split(begin, 1)
                _, after = remainder.split(end, 1)
                existing_css = before + after
            existing_css = existing_css.rstrip()
            managed_block = begin + "\n" + managed_css.read_text().rstrip() + "\n" + end
            merged_css = (existing_css + "\n\n" if existing_css else "")
            css_path.write_text(merged_css + managed_block + "\n")
            user_js = profile / "user.js"
            prefs_text = user_js.read_text() if user_js.is_file() else ""
            prefs_lines = prefs_text.splitlines()
            for name, value in required_prefs.items():
                prefix_double = 'user_pref("' + name + '"'
                prefix_single = "user_pref('" + name + "'"
                prefs_lines = [
                    line for line in prefs_lines
                    if not (
                        line.strip().startswith(prefix_double)
                        or line.strip().startswith(prefix_single)
                    )
                ]
                prefs_lines.append('user_pref("' + name + '", ' + value + ');')
            user_js.write_text("\n".join(prefs_lines) + "\n")
            installed += 1

    print("Neodots Waterfox chrome installed in " + str(installed) + " profile(s).")
    PY
  '';

}
