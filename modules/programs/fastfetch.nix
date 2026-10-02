# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ pkgs, ... }:

{
  programs.fastfetch.enable = true;

  home.file.".config/fastfetch/config.jsonc".source =
    ../../config/fastfetch/config.jsonc;
}
