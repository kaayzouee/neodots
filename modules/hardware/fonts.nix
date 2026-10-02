# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ pkgs, ... }:

{
  fonts = {
    fontconfig.enable = true;
    packages = with pkgs; [
      nerd-fonts.meslo-lg
      nerd-fonts.fira-code
      noto-fonts
      noto-fonts-color-emoji
      fira-code
      fira
      font-awesome
    ];
  };
}
