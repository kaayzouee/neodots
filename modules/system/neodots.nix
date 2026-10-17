# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Declares the neodots.* options and their validation assertions.
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

    boot.configurationLimit = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8;
      description = ''
        Maximum number of generations kept in the systemd-boot menu. Every
        generation stores a kernel and initrd on the ESP, which is shared with
        Windows and can be small. Lower this if `df -h /boot` is nearly full.
      '';
    };

    vm = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Set when this system is installed inside a virtual machine. Installs
          the guest tools, applies software-rendering fallbacks for River and
          skips laptop-specific kernel modules.
        '';
      };

      platform = lib.mkOption {
        type = lib.types.enum [
          "vmware"
          "qemu"
        ];
        default = "vmware";
        description = "Hypervisor the guest runs on: VMware Workstation or QEMU/KVM.";
      };
    };

    btrfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable Btrfs tuning (zstd compression, noatime, scheduled scrub).
          Requires a Btrfs root filesystem and a regenerated
          hardware-configuration.nix; evaluation fails otherwise.
        '';
      };

      mountPoints = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "/" ];
        example = [
          "/"
          "/home"
          "/nix"
        ];
        description = ''
          Btrfs mount points that receive the compression and noatime options.
          Every entry must already be declared in hardware-configuration.nix
          with fsType = "btrfs" (one entry per subvolume mount).
        '';
      };
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
      assertion = config.neodots.username != "river";
      message = "The Neodots primary user cannot be named river (reserved for the River session user).";
    }
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
