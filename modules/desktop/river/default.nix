# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - River system integration and explicit account permissions.
#
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.neodots.desktop.river;
  river = pkgs.callPackage ../../../packages/river { };
  kwm = pkgs.callPackage ../../../packages/kwm { };
in
{
  options.neodots.desktop.river = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the River 0.4/KWM session and its separate user.";
    };
    user = lib.mkOption {
      type = lib.types.strMatching "[a-z_][a-z0-9_-]*";
      default = "river";
      description = "Separate account for the River desktop.";
    };
    permissions = {
      admin = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Grant wheel membership (password-authenticated sudo).";
      };
      virtualization = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Grant libvirtd membership (privileged VM management).";
      };
      input = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Grant uinput membership (input injection).";
      };
      networkManagement = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Grant networkmanager membership.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.user != config.neodots.username && cfg.user != "guest" && cfg.user != "root";
        message = "The River account must be separate from the primary, guest and root accounts.";
      }
    ];
    environment.systemPackages = [
      river
      kwm
    ];
    services.displayManager.sessionPackages = [ river ];
    security.pam.services.swaylock = { };

    users.users.${cfg.user} = {
      isNormalUser = true;
      description = "River Wayland User";
      shell = pkgs.fish;
      home = "/home/${cfg.user}";
      createHome = true;
      homeMode = "0700";
      extraGroups =
        lib.optional cfg.permissions.admin "wheel"
        ++ lib.optional cfg.permissions.networkManagement "networkmanager"
        ++ lib.optional cfg.permissions.virtualization "libvirtd"
        ++ lib.optional cfg.permissions.input "uinput";
    };

    home-manager.users.${cfg.user} = {
      home.username = cfg.user;
      home.homeDirectory = config.users.users.${cfg.user}.home;
      _module.args.riverKwmPackage = kwm;
    };
  };
}
