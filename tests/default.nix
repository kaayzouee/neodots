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
  riverUser = cfg.neodots.desktop.river.user;
  riverHome = cfg.home-manager.users.${riverUser};

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
      ok = users.${riverUser}.hashedPassword == null && users.${riverUser}.password == null;
    }
    {
      name = "river Home Manager home matches the system user's home";
      ok = hmHome riverUser == users.${riverUser}.home;
    }
    {
      name = "river session is registered with the display manager";
      ok = providesSession "river";
    }
    {
      name = "production Quickshell deploys immutable sources without a live checkout watcher";
      ok =
        riverHome.neodots.quickshell.developmentSource == null
        && riverHome.xdg.configFile."quickshell/neodots".source != null
        && !(riverHome.systemd.user.services ? neodots-quickshell-watch);
    }
    {
      name = "Quickshell is supervised and bound to the River session";
      ok =
        riverHome.systemd.user.services.neodots-quickshell.Service.Restart == "on-failure"
        && lib.elem "neodots-river-session.target" riverHome.systemd.user.services.neodots-quickshell.Unit.PartOf
        && lib.elem "graphical-session.target" riverHome.systemd.user.targets.neodots-river-session.Unit.PartOf;
    }
    {
      name = "primary and River retain intentional administrative capabilities by default";
      ok =
        lib.all
          (
            name:
            lib.all (g: lib.elem g users.${name}.extraGroups) [
              "wheel"
              "networkmanager"
              "libvirtd"
              "uinput"
            ]
          )
          [
            username
            riverUser
          ];
    }
    {
      name = "River capabilities can be independently disabled without affecting the primary";
      ok =
        let
          restricted = base.extendModules {
            modules = [
              {
                neodots.desktop.river.permissions = {
                  admin = false;
                  virtualization = false;
                  input = false;
                  networkManagement = false;
                };
              }
            ];
          };
        in
        restricted.config.users.users.${riverUser}.extraGroups == [ ]
        && restricted.config.users.users.${username}.extraGroups == users.${username}.extraGroups;
    }
    {
      name = "River account can be renamed consistently across NixOS and Home Manager";
      ok =
        let
          renamed = base.extendModules { modules = [ { neodots.desktop.river.user = "desktop-test"; } ]; };
        in
        renamed.config.users.users.desktop-test.home == "/home/desktop-test"
        && renamed.config.home-manager.users.desktop-test.home.username == "desktop-test"
        && !(renamed.config.users.users ? river);
    }
    {
      name = "disabling River removes its account and Home Manager profile, not GNOME";
      ok =
        let
          disabled = base.extendModules { modules = [ { neodots.desktop.river.enable = false; } ]; };
        in
        !(disabled.config.users.users ? ${riverUser})
        && !(disabled.config.home-manager.users ? ${riverUser})
        && disabled.config.services.desktopManager.gnome.enable;
    }
    {
      name = "invalid Quickshell development paths are rejected";
      ok =
        let
          invalid = base.extendModules {
            modules = [
              {
                home-manager.users.${riverUser}.neodots.quickshell.developmentSource = "relative/path";
              }
            ];
          };
        in
        lib.any (
          a: !a.assertion && lib.hasInfix "developmentSource" a.message
        ) invalid.config.home-manager.users.${riverUser}.assertions;
    }
    {
      name = "swaylock has password-authentication PAM integration";
      ok =
        cfg.security.pam.services ? swaylock
        && lib.hasInfix "pam_unix.so" cfg.security.pam.services.swaylock.text;
    }

    # -- GNOME / Wayland --------------------------------------------------
    {
      name = "GNOME is enabled and GDM selects its Wayland session";
      ok =
        cfg.services.desktopManager.gnome.enable
        && cfg.services.displayManager.gdm.enable
        && cfg.services.displayManager.defaultSession == "gnome";
    }
    {
      name = "XWayland is disabled";
      ok = cfg.programs.xwayland.enable == false;
    }
    {
      name = "Fish man-page completion generation is disabled for Fish 4.8+ compatibility";
      ok =
        cfg.programs.fish.generateCompletions == false
        && cfg.home-manager.users.${username}.programs.fish.generateCompletions == false
        && cfg.home-manager.users.${riverUser}.programs.fish.generateCompletions == false;
    }
    {
      name = "XFCE and LightDM are not enabled";
      ok =
        !(cfg.services.desktopManager.xfce.enable or false)
        && !(cfg.services.displayManager.lightdm.enable or false);
    }
    {
      name = "Spotify uses Nixpkgs Spotify through Spicetify-Nix with native Wayland enabled";
      ok =
        let
          spicetify = cfg.home-manager.users.${username}.programs.spicetify;
        in
        spicetify.enable && spicetify.wayland && lib.getName spicetify.spotifyPackage == "spotify";
    }

    {
      name = "legacy X11 UI packages are absent from system and primary-user package lists";
      ok =
        let
          forbidden = [
            "feh"
            "picom"
            "polybar"
            "networkmanagerapplet"
            "xfce4-appfinder"
          ];
          hasForbidden = package: lib.elem (lib.getName package) forbidden;
        in
        !(lib.any hasForbidden cfg.environment.systemPackages)
        && !(lib.any hasForbidden cfg.home-manager.users.${username}.home.packages);
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

    {
      name = "incorrect EFI filesystem and raw NVMe devices are rejected";
      ok =
        let
          invalid = base.extendModules {
            modules = [
              {
                fileSystems."/boot".fsType = lib.mkForce "ext4";
                fileSystems."/".device = lib.mkForce "/dev/nvme0n1p8";
              }
            ];
          };
        in
        builtins.length (failedTagged "[hardware]" invalid) >= 2;
    }
    {
      name = "missing explicit root device is rejected";
      ok =
        failedTagged "[hardware]" (
          base.extendModules {
            modules = [
              {
                fileSystems."/".device = lib.mkForce null;
              }
            ];
          }
        ) != [ ];
    }
    {
      name = "volatile persistence backing filesystems are rejected";
      ok =
        failedPersistenceAssertions (
          persistenceWithFs.extendModules {
            modules = [
              {
                fileSystems."/persist".fsType = lib.mkForce "tmpfs";
              }
            ];
          }
        ) != [ ];
    }

    {
      name = "synthetic hardware cannot pass production/non-VM assertions";
      ok =
        failedTagged "[hardware-fixture]" (
          base.extendModules {
            modules = [
              {
                neodots.vm.enable = lib.mkOverride 40 false;
              }
            ];
          }
        ) != [ ];
    }
    {
      name = "only the primary and configured River accounts receive privileged memberships";
      ok = lib.all (
        name:
        lib.elem name [
          username
          riverUser
        ]
        || lib.intersectLists privilegedGroups normalUsers.${name}.extraGroups == [ ]
      ) (lib.attrNames normalUsers);
    }

    # -- secret recovery -------------------------------------------------
    {
      name = "personal persistence preserves the Home Manager age key directory privately";
      ok =
        let
          personalPersistent = persistenceWithFs.extendModules {
            modules = [ { neodots.personal.enable = lib.mkOverride 40 true; } ];
          };
          directories =
            personalPersistent.config.environment.persistence."/persist".users.${username}.directories;
        in
        lib.any (d: d.directory == ".config/sops/age" && d.mode == "0700") directories;
    }
    {
      name = "nonpersonal primary Home Manager has no secrets or age key";
      ok =
        let
          nonpersonal = base.extendModules {
            modules = [ { neodots.personal.enable = lib.mkForce false; } ];
          };
          hm = nonpersonal.config.home-manager.users.${username};
        in
        hm.sops.secrets == { } && hm.sops.templates == { } && hm.sops.age.keyFile == null;
    }
    {
      name = "normal host has no VM-only initial passwords";
      ok = users.${username}.initialPassword == null && users.${riverUser}.initialPassword == null;
    }
    {
      name = "firewall is enabled and SSH is not exposed";
      ok = cfg.networking.firewall.enable && !cfg.services.openssh.enable;
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
      name = "resolv.conf contains exactly the static public DNS policy";
      ok = resolvConf == "nameserver 1.1.1.1\nnameserver 8.8.8.8\n";
    }
    {
      name = "Stubby, systemd-resolved and resolvconf are disabled";
      ok =
        !cfg.services.stubby.enable && !cfg.services.resolved.enable && !cfg.networking.resolvconf.enable;
    }
    {
      name = "NetworkManager leaves the static resolv.conf untouched";
      ok =
        cfg.networking.networkmanager.enable
        && cfg.networking.networkmanager.dns == "none"
        && (cfg.networking.networkmanager.settings.main.dns or "none") == "none"
        && (cfg.networking.networkmanager.settings.main."rc-manager" or "unmanaged") == "unmanaged";
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
