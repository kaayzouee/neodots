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

    plugins = [
      {
        name = "bass";
        src = pkgs.fishPlugins.bass;
      }
    ];
  };
}
