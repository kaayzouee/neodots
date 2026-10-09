# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ pkgs, ... }:
{
  programs.alacritty = {
    enable = true;
    package = null;

    settings = {
      font = {
        size = 11.25;
      };

      window = {
        opacity = 0.88;
      };
      keyboard.bindings = [

        {
          key = "T";
          mods = "Super";
          chars = "\\u0002c";
        }

        {
          key = "Q";
          mods = "Super";
          chars = "\\u0002p";
        }

        {
          key = "E";
          mods = "Super";
          chars = "\\u0002n";
        }

        {
          key = "D";
          mods = "Super";
          chars = "\\u0002&";
        }
      ];
    };
  };
}
