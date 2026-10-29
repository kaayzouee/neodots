# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Home Manager configuration for the unprivileged guest user (GNOME
#          Wayland session).
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

{
  lib,
  pkgs,
  waterfox,
  ...
}:

{
  home.stateVersion = "26.05";

  home.username = "guest";
  home.homeDirectory = "/home/guest";

  imports = [
    ../../modules/programs/alacritty.nix
  ];

  # The shared Alacritty module sends tmux prefix sequences (Super+T/Q/E/D).
  # The guest shell is plain bash without tmux, so those keys would type
  # control characters into the prompt.
  programs.alacritty.settings.keyboard.bindings = lib.mkForce [ ];

  # ---------------------------------------------------------------------------
  # Guest applications
  # ---------------------------------------------------------------------------
  #
  # This is intentionally small.

  home.packages = [
    pkgs.git

    waterfox.legacyPackages.${pkgs.stdenv.hostPlatform.system}.waterfox-bin
  ];

  # ---------------------------------------------------------------------------
  # VS Code
  # ---------------------------------------------------------------------------

  programs.vscode = {
    enable = true;

    profiles.default.extensions = with pkgs.vscode-extensions; [
      # LLDB debugger / CodeLLDB
      vadimcn.vscode-lldb
    ];
  };

  # ---------------------------------------------------------------------------
  # Git
  # ---------------------------------------------------------------------------
  # Independent identity from the personal git module; see docs/comments/guest-home.txt.

  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "Guest";
        email = "guest@localhost";
      };

      init.defaultBranch = "main";

      # Do not use your personal credential helper configuration.
      credential.helper = "";
    };
  };

  # ---------------------------------------------------------------------------
  # Browser
  # ---------------------------------------------------------------------------

  xdg.mimeApps = {
    enable = true;

    defaultApplications = {
      "text/html" = "waterfox.desktop";
      "text/xml" = "waterfox.desktop";
      "application/xhtml+xml" = "waterfox.desktop";

      "x-scheme-handler/http" = "waterfox.desktop";
      "x-scheme-handler/https" = "waterfox.desktop";
      "x-scheme-handler/about" = "waterfox.desktop";
      "x-scheme-handler/unknown" = "waterfox.desktop";
    };
  };

  home.sessionVariables = {
    BROWSER = "waterfox";
    EDITOR = "code";
    VISUAL = "code";
  };

  # Keep Home Manager usable from the guest account if necessary.
  programs.home-manager.enable = true;
}
