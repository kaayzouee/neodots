# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ pkgs, ... }:
{
  xsession.enable = true;
  xsession.windowManager.command = "startxfce4";
}
