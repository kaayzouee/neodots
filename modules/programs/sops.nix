# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ pkgs, ... }:

{
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
}
