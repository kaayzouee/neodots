# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ pkgs, ... }:

[
  pkgs.alacritty        # terminal emulator
  pkgs.fzf              # fuzzy finder
  pkgs.jq               # JSON processor
  pkgs.stow             # symlink manager
  pkgs.picom            # blurry background for terminal
  pkgs.fishPlugins.bass # bash support for fish
]
