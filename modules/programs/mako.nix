# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ ... }:

{
  services.mako = {
    enable = true;

    settings = {
      anchor = "top-right";

      width = 420;
      height = 120;

      margin = 12;
      padding = 12;

      border-size = 2;
      border-radius = 8;

      default-timeout = 5000;
      ignore-timeout = false;

      icons = true;
      markup = true;

      max-visible = 5;

      font = "Sans 11";
    };
  };
}
