# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ pkgs }:
[
  pkgs.cargo
  pkgs.go
  pkgs.nodejs
  pkgs.python313
  pkgs.python313Packages.pynvim
  pkgs.python313Packages.pip
  pkgs.lua51Packages.lua
]
