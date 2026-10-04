# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ config, lib, ... }:

{
  options.neodots = {
    username = lib.mkOption {
      type = lib.types.str;
      description = "Primary interactive user's username.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      description = "NixOS hostname for the installed machine.";
    };

    homeDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/home/${config.neodots.username}";
      description = "Primary interactive user's home directory.";
    };

    personal.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Neodots personal configuration and credentials.";
    };

    persistence = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable persistent state through the configured persistence path.";
      };

      path = lib.mkOption {
        type = lib.types.str;
        default = "/persist";
        description = "Absolute path used for persistent state.";
      };
    };
  };

  config.assertions = [
    {
      assertion = config.neodots.username != "guest";
      message = "The Neodots primary user cannot be named guest.";
    }
    {
      assertion = builtins.match "^[a-z_][a-z0-9_-]*$" config.neodots.username != null;
      message = "Neodots username must start with a lowercase letter or underscore and contain only lowercase letters, digits, underscores, or hyphens.";
    }
    {
      assertion = builtins.match "^[A-Za-z0-9][A-Za-z0-9.-]*$" config.neodots.hostname != null;
      message = "Neodots hostname must start with an alphanumeric character and contain only alphanumerics, dots, or hyphens.";
    }
    {
      assertion = builtins.match "^/.*$" config.neodots.homeDirectory != null;
      message = "Neodots homeDirectory must be an absolute path.";
    }
    {
      assertion = builtins.match "^/.*$" config.neodots.persistence.path != null;
      message = "Neodots persistence.path must be an absolute path.";
    }
    {
      assertion = config.neodots.persistence.path != "/";
      message = "Neodots persistence.path cannot be the root filesystem.";
    }
  ];
}
