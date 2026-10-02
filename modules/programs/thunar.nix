# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ pkgs, config, ... }:

{
  programs.thunar.plugins = with pkgs; [
    thunar-archive-plugin
    thunar-volman
  ];
}
