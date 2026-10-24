# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Flake entry point: pins inputs and assembles the NixOS
#          configuration.
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
  description = "Neodots NixOS configuration";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

    catppuccin = {
      url = "github:catppuccin/nix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    waterfox = {
      url = "github:Hythera/nix-waterfox";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      catppuccin,
      home-manager,
      spicetify-nix,
      waterfox,
      sops-nix,
      impermanence,
    }:

    let
      machine = import ./hosts/nixos/machine.nix;
    in
    {
      # ─────────────────────────── NixOS host ───────────────────────────
      nixosConfigurations.${machine.neodots.hostname} = nixpkgs.lib.nixosSystem {
        system = machine.system;

        specialArgs = {
          inherit waterfox;
        };

        modules = [
          ./hosts/nixos

          {
            neodots = machine.neodots;
          }

          catppuccin.nixosModules.catppuccin
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          impermanence.nixosModules.impermanence

          (
            { config, ... }:
            {
              home-manager.useGlobalPkgs = true;

              home-manager.backupFileExtension = "backup";

              home-manager.extraSpecialArgs = {
                inherit waterfox spicetify-nix;
                neodots = config.neodots;
              };

              home-manager.sharedModules = [
                sops-nix.homeManagerModules.sops
              ];

              home-manager.users.${config.neodots.username} = {
                imports = [
                  ./hosts/nixos/home.nix
                  catppuccin.homeModules.catppuccin
                  spicetify-nix.homeManagerModules.spicetify
                ];
              };

              home-manager.users.river = {
                imports = [
                  ./hosts/nixos/river-home.nix
                  catppuccin.homeModules.catppuccin
                ];
              };

              home-manager.users.guest = {
                imports = [
                  ./hosts/nixos/guest-home.nix
                ];
              };
            }
          )
        ];
      };

      # ─────────────────────────── Dev shells ───────────────────────────
      devShells.${machine.system} =
        let
          pkgs = nixpkgs.legacyPackages.${machine.system};
        in
        {
          cpp = pkgs.mkShell {
            name = "cpp";
            packages = with pkgs; [
              clang
              clang-tools
              cmake
              gnumake
              gdb
              lldb
            ];
            shellHook = ''
              export CMAKE_EXPORT_COMPILE_COMMANDS=1
              export CC=clang
              export CXX=clang++
            '';
          };

          qt =
            let
              qtEnv =
                with pkgs.qt6;
                env "qt-custom-${qtbase.version}" [
                  qtbase
                  qtdeclarative
                  qttools
                  qt5compat
                  qtwayland
                ];
            in
            pkgs.mkShell {
              name = "qt";
              packages = [
                qtEnv
                pkgs.clang
                pkgs.clang-tools
                pkgs.cmake
                pkgs.gnumake
                pkgs.gdb
                pkgs.qtcreator
              ];
              shellHook = ''
                export CMAKE_EXPORT_COMPILE_COMMANDS=1
                export CC=clang
                export CXX=clang++
                export QT_PLUGIN_PATH="${qtEnv}/lib/qt-6/plugins"
                export QML_IMPORT_PATH="${qtEnv}/lib/qt-6/qml"
                export QT_QPA_PLATFORM_PLUGIN_PATH="${qtEnv}/lib/qt-6/plugins/platforms"
                export PKG_CONFIG_PATH="${qtEnv}/lib/pkgconfig:$PKG_CONFIG_PATH"
              '';
            };

          asm = pkgs.mkShell {
            name = "asm";
            packages = with pkgs; [
              nasm
              yasm
              binutils
              gdb
            ];
          };

          rust = pkgs.mkShell {
            name = "rust";
            packages = with pkgs; [
              rustc
              cargo
              rust-analyzer
              rustfmt
              clippy
            ];
          };

          python = pkgs.mkShell {
            name = "python";
            packages = with pkgs; [
              python3
              python3Packages.pip
              python3Packages.virtualenv
              ruff
              python3Packages.black
            ];
          };
        };

      # ─────────────────────────── Templates ────────────────────────────
      templates = {
        cpp = {
          description = "C/C++ dev shell";
          path = ./templates/cpp;
        };
        qt = {
          description = "Qt dev shell";
          path = ./templates/qt;
        };
        asm = {
          description = "Assembly dev shell";
          path = ./templates/asm;
        };
        rust = {
          description = "Rust dev shell";
          path = ./templates/rust;
        };
        python = {
          description = "Python dev shell";
          path = ./templates/python;
        };
      };

      # ─────────────────────────── Formatter ────────────────────────────
      formatter.${machine.system} = nixpkgs.legacyPackages.${machine.system}.nixfmt-tree;

      # ─────────────────────────── Checks ───────────────────────────────
      checks.${machine.system}.config-invariants =
        let
          result = import ./tests {
            lib = nixpkgs.lib;
            base = self.nixosConfigurations.${machine.neodots.hostname};
          };
        in
        if result.failed == [ ] then
          nixpkgs.legacyPackages.${machine.system}.runCommand "neodots-config-invariants" { } "touch $out"
        else
          throw result.failureMessage;

      # Exercise actual GUI clients against a headless Wayland compositor.
      # Unlike config evaluation, this launches GTK, Qt, SDL and Electron windows.
      checks.${machine.system}.wayland-client-smoke = import ./tests/wayland-client-smoke.nix {
        pkgs = nixpkgs.legacyPackages.${machine.system};
      };

      # Upstream-style end-to-end test for GDM + GNOME Shell. Building/running
      # this requires a KVM-enabled builder; CI skips only this one check otherwise.
      checks.${machine.system}.gnome-wayland-vm = import ./tests/gnome-wayland-vm.nix {
        pkgs = nixpkgs.legacyPackages.${machine.system};
      };
    };
}
