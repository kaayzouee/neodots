# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ config, ... }:

{
  home.stateVersion = "26.05";

  catppuccin = {
    enable = true;
    flavor = "mocha";
    accent = "mauve";
  };

  imports = [
    ../../modules/theming/cursor.nix
    ../../modules/theming/wallpaper.nix
    ../../modules/programs/tmux.nix
    ../../modules/programs/fastfetch.nix
    ../../modules/programs/git.nix
    ../../modules/programs/polybar.nix
    ../../modules/system/xsession.nix
  ];

  home.username = "kay";
  home.homeDirectory = "/home/kay";

  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  catppuccin.xfce4-terminal.enable = true;

  programs.home-manager.enable = true;

  # XFCE session behaviour.
  #
  # SaveOnExit = false stops XFCE from writing a new saved session on logout.
  #
  # The Failsafe session is what xfce4-session launches on a *fresh* login
  # (no saved session yet). It hardcodes Client2 = xfce4-panel, which no
  # longer exists on this system. Every login it tries to launch it, fails,
  # logs an error, and stalls for ~2s. We replace it with `true` (the
  # /bin/true binary) so the slot still exists but does nothing.
  xfconf.settings."xfce4-session" = {
    "general/SaveOnExit" = false;
    "sessions/Failsafe/Client2_Command" = [ "true" ];
  };

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
}
