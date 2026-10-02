# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ pkgs, ... }:

{
  home.pointerCursor = {
    enable = true;
    package = pkgs.catppuccin-cursors;
    name = "catppuccin-mocha-mauve-cursors";
    size = 24;

    gtk.enable = true;
  };
}
