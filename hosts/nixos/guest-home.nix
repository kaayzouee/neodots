# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ pkgs, waterfox, ... }:

{
  home.stateVersion = "26.05";

  home.username = "guest";
  home.homeDirectory = "/home/guest";

  imports = [
    ../../modules/programs/polybar.nix
    ../../modules/programs/alacritty.nix
    ../../modules/programs/picom.nix
  ];

  # ---------------------------------------------------------------------------
  # Guest applications
  # ---------------------------------------------------------------------------
  #
  # This is intentionally small.

  home.packages = [
    pkgs.git
    pkgs.feh
    pkgs.xfce4-appfinder

    waterfox.packages.${pkgs.stdenv.hostPlatform.system}.waterfox-bin
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
  #
  # Do NOT import your personal modules/programs/git.nix here because that
  # module pulls credentials from SOPS.
  #
  # The guest gets a completely independent identity.
  #

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
