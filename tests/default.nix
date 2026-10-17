# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Evaluation-time invariants for the NixOS configuration. Details:
#          docs/comments/tests-default.txt.
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

# Details: docs/comments/tests-default.txt.

{ lib, base }:

let
  cfg = base.config;

  users = cfg.users.users;
  username = cfg.neodots.username;

  normalUsers = lib.filterAttrs (_: u: u.isNormalUser) users;

  privilegedGroups = [
    "wheel"
    "networkmanager"
    "libvirtd"
    "docker"
    "kvm"
    "disk"
    "uinput"
    "root"
  ];

  emptyPasswordUsers = lib.attrNames (
    lib.filterAttrs (_: u: u.hashedPassword == "" || u.password == "") normalUsers
  );

  hmHome = name: cfg.home-manager.users.${name}.home.homeDirectory;

  resolvConf = cfg.environment.etc."resolv.conf".text or "";

  providesSession =
    name:
    lib.any (p: lib.elem name (p.providedSessions or [ ])) cfg.services.displayManager.sessionPackages;

  # A test that throws (missing option, failed assertion) counts as failed
  # and is reported by name instead of aborting the whole evaluation.
  safe =
    e:
    let
      r = builtins.tryEval e;
    in
    r.success && r.value;

  failedTagged =
    tag: variant:
    builtins.filter (
      a:
      !a.assertion
      && (
        let
          r = builtins.tryEval (lib.hasInfix tag a.message);
        in
        r.success && r.value
      )
    ) variant.config.assertions;

  vmVariant = cfg.virtualisation.vmVariant;

  # Inside a VM (installed guest).
  vmGuest = base.extendModules {
    modules = [ { neodots.vm.enable = lib.mkForce true; } ];
  };

  # Btrfs tuning requested while the root is still ext4: must be rejected.
  btrfsOnExt4 = base.extendModules {
    modules = [
      {
        neodots.btrfs.enable = lib.mkForce true;
        fileSystems."/".fsType = lib.mkForce "ext4";
      }
    ];
  };

  btrfsOnBtrfs = base.extendModules {
    modules = [
      {
        neodots.btrfs.enable = lib.mkForce true;
        fileSystems."/".fsType = lib.mkForce "btrfs";
      }
    ];
  };

  # Raw /dev/nvmeXnYpZ names change when partitions are added or removed.
  isRawNvmePath = d: d != null && builtins.match "/dev/nvme[0-9]+n[0-9]+p[0-9]+" d != null;

  # Variants of the same system with persistence switched on.
  persistenceWithoutFs = base.extendModules {
    modules = [ { neodots.persistence.enable = lib.mkForce true; } ];
  };

  persistenceWithFs = base.extendModules {
    modules = [
      {
        neodots.persistence.enable = lib.mkForce true;
        fileSystems."/persist" = {
          device = "/dev/disk/by-label/persist";
          fsType = "ext4";
          neededForBoot = true;
        };
      }
    ];
  };

  failedPersistenceAssertions = failedTagged "[persistence]";

  tests = [
    # -- guest account ---------------------------------------------------
    {
      name = "guest exists and is a normal user";
      ok = users ? guest && users.guest.isNormalUser;
    }
    {
      name = "guest is in no privileged group";
      ok = lib.intersectLists privilegedGroups users.guest.extraGroups == [ ];
    }
    {
      name = "guest is the only account with an empty password";
      ok = emptyPasswordUsers == [ "guest" ];
    }
    {
      name = "guest home is wiped on every boot";
      ok = lib.any (r: lib.hasPrefix "D! /home/guest " r) cfg.systemd.tmpfiles.rules;
    }
    {
      name = "guest Home Manager home matches the system user's home";
      ok = hmHome "guest" == users.guest.home;
    }
    {
      name = "primary user cannot be named guest or river";
      ok = username != "guest" && username != "river";
    }

    # -- river user ------------------------------------------------------
    {
      name = "river has no declared password";
      ok = users.river.hashedPassword == null && users.river.password == null;
    }
    {
      name = "river Home Manager home matches the system user's home";
      ok = hmHome "river" == users.river.home;
    }
    {
      name = "river session is registered with the display manager";
      ok = providesSession "river";
    }
    {
      name = "quickshell watcher is skipped when the live checkout is missing";
      ok =
        (cfg.home-manager.users.river.systemd.user.services.neodots-quickshell-watch.Unit.ConditionPathExists
          or null
        ) != null;
    }

    # -- sudo ------------------------------------------------------------
    {
      name = "sudo is wheel-only and always asks for a password";
      ok = cfg.security.sudo.execWheelOnly && cfg.security.sudo.wheelNeedsPassword;
    }

    # -- boot ------------------------------------------------------------
    {
      name = "root and /boot are declared";
      ok = cfg.fileSystems ? "/" && cfg.fileSystems ? "/boot";
    }
    {
      name = "systemd-boot generation count is bounded (shared ESP)";
      ok = cfg.boot.loader.systemd-boot.configurationLimit != null;
    }
    {
      name = "systemd-boot command-line editor is disabled";
      ok = cfg.boot.loader.systemd-boot.editor == false;
    }
    {
      name = "automatic GC is never enabled without a bounded boot menu";
      ok = !cfg.nix.gc.automatic || cfg.boot.loader.systemd-boot.configurationLimit != null;
    }
    {
      name = "persistence without a neededForBoot filesystem is rejected";
      ok = failedPersistenceAssertions persistenceWithoutFs != [ ];
    }
    {
      name = "persistence with a neededForBoot filesystem is accepted";
      ok = failedPersistenceAssertions persistenceWithFs == [ ];
    }

    {
      name = "boot menu limit comes from neodots.boot.configurationLimit";
      ok =
        cfg.boot.loader.systemd-boot.configurationLimit == cfg.neodots.boot.configurationLimit
        && cfg.neodots.boot.configurationLimit >= 1;
    }
    {
      name = "no filesystem or swap device uses a raw /dev/nvmeXnYpZ path";
      ok =
        !(lib.any (fs: isRawNvmePath (fs.device or null)) (lib.attrValues cfg.fileSystems))
        && !(lib.any (s: isRawNvmePath (s.device or null)) cfg.swapDevices);
    }

    # -- btrfs -----------------------------------------------------------
    {
      name = "btrfs tuning on an ext4 root is rejected at evaluation time";
      ok = failedTagged "[btrfs]" btrfsOnExt4 != [ ];
    }
    {
      name = "btrfs tuning on a btrfs root is accepted and scrubs /";
      ok =
        failedTagged "[btrfs]" btrfsOnBtrfs == [ ]
        && btrfsOnBtrfs.config.services.btrfs.autoScrub.enable
        && lib.elem "compress=zstd:3" btrfsOnBtrfs.config.fileSystems."/".options;
    }
    {
      name = "btrfs tuning is only enabled on a btrfs root";
      ok = !cfg.neodots.btrfs.enable || cfg.fileSystems."/".fsType == "btrfs";
    }

    # -- virtual machines ------------------------------------------------
    {
      name = "laptop-only kernel module is skipped inside a VM";
      ok = !(lib.elem "asus-nb-wmi" vmGuest.config.boot.kernelModules);
    }
    {
      name = "VMware guest tools are enabled when neodots.vm targets VMware";
      ok =
        (vmGuest.config.neodots.vm.platform != "vmware")
        || vmGuest.config.virtualisation.vmware.guest.enable;
    }
    {
      name = "River gets software-rendering fallbacks inside a VM";
      ok = vmGuest.config.environment.sessionVariables.WLR_RENDERER_ALLOW_SOFTWARE == "1";
    }
    {
      name = "build-vm variant has no SOPS, persistence or btrfs requirements";
      ok =
        vmVariant.neodots.vm.enable
        && !vmVariant.neodots.personal.enable
        && !vmVariant.neodots.persistence.enable
        && !vmVariant.neodots.btrfs.enable;
    }
    {
      name = "build-vm variant gives the primary user a login";
      ok = vmVariant.users.users.${username}.initialPassword != null;
    }

    # -- networking ------------------------------------------------------
    {
      name = "static resolv.conf pointing at localhost requires stubby";
      ok = !(lib.hasInfix "127.0.0.1" resolvConf) || cfg.services.stubby.enable;
    }
    {
      name = "stubby listens on 127.0.0.1:53";
      ok = lib.elem "127.0.0.1@53" cfg.services.stubby.settings.listen_addresses;
    }
    {
      name = "only NetworkManager runs a DHCP client";
      ok =
        !cfg.networking.useDHCP && !cfg.networking.dhcpcd.enable && cfg.networking.networkmanager.enable;
    }

    # -- input method ----------------------------------------------------
    {
      name = "fcitx5-lotus is enabled for the primary user";
      ok = lib.elem username cfg.services.fcitx5-lotus.users;
    }
  ];

  failed = builtins.filter (t: !(safe t.ok)) tests;
in
{
  inherit tests failed;

  failureMessage =
    "neodots config invariants failed:\n" + lib.concatMapStringsSep "\n" (t: "  - ${t.name}") failed;
}
