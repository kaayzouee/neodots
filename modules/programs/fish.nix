# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ pkgs, ... }:

{
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set -g fish_greeting 'Hello, world! ♡'
    '';

    if status is-interactive; and not set -q TMUX
      exec tmux new-session -A -s main
    end

    plugins = [
      {
        name = "bass";
        src = pkgs.fishPlugins.bass;
      }
    ];
  };
}
