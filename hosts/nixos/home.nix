# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Home Manager configuration for the primary user.
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
  config,
  lib,
  neodots,
  pkgs,
  ...
}:

{
  home.stateVersion = "26.05";

  catppuccin = {
    enable = true;
    flavor = "mocha";
    accent = "mauve";
  };

  # Polybar already has an explicit repo-local configuration. Disable the
  # optional Catppuccin Polybar integration so evaluation does not force its
  # generated theme source.
  catppuccin.polybar.enable = false;

  imports = [
    ../../modules/theming/cursor.nix
    ../../modules/theming/wallpaper.nix
    ../../modules/programs/waterfox.nix
    ../../modules/programs/alacritty.nix
    ../../modules/programs/picom.nix
    ../../modules/programs/tmux.nix
    ../../modules/programs/nano.nix
    ../../modules/programs/fastfetch.nix
    ../../modules/programs/polybar.nix
    ../../modules/system/xsession.nix
  ]
  ++ lib.optional neodots.personal.enable ../../modules/personal/git.nix;

  home.username = neodots.username;
  home.homeDirectory = neodots.homeDirectory;

  sops.age.keyFile = lib.mkIf neodots.personal.enable (
    "${config.home.homeDirectory}/.config/sops/age/keys.txt"
  );

  programs.home-manager.enable = true;

  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set -g fish_greeting 'Hello, world! ♡'

      if not set -q TMUX
        exec tmux new-session -A -s main
      end
    '';

    plugins = [
      {
        name = "bass";
        src = pkgs.fishPlugins.bass;
      }
    ];
  };

  xfconf.enable = true;
  # XFCE session behaviour; see docs/comments/home.txt.
  xfconf.settings."xfce4-session" = {
    "general/SaveOnExit" = false;
    "sessions/Failsafe/Client2_Command" = [ "true" ];
  };

  xfconf.settings."xfwm4" = {
    "general/use_compositing" = false;
  };

  xfconf.settings."xfce4-keyboard-shortcuts" = {
    "commands/custom/override" = true;
    "commands/custom/<Primary><Alt>t" = "alacritty";
    "commands/custom/<Primary><Shift>t" = "thunar";
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
