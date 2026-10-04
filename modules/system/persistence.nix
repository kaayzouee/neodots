# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

# Persistence contract for optional impermanent-root installations.

{ config, lib, ... }:

{
  config = lib.mkIf config.neodots.persistence.enable {
    environment.persistence.${config.neodots.persistence.path} = {
      hideMounts = true;

      directories = [
        "/etc/nixos"
        "/var/lib/nixos"
        "/var/log"
      ]
      ++ lib.optional config.neodots.personal.enable "/var/lib/sops-nix";

      users.${config.neodots.username}.directories = [
        "Pictures"
      ];
    };
  };
}
