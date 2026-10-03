# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ pkgs, ... }:
{
  services.picom = {
    enable = true;

    settings = {
      backend = "glx";
      vsync = true;

      blur = {
        method = "dual_kawase";
        strength = 5;
      };

      blur-background = true;

    # Keep Polybar/wallpaper/etc. sharp
      blur-background-exclude = [
        "window_type = 'dock'"
        "window_type = 'desktop'"
        "_GTK_FRAME_EXTENTS@:c"
      ];
    };
  };
}
