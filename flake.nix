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
      url = "github:nix-community/home-manager";
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
      mutterNoXWaylandOverlay = import ./modules/desktop/mutter-no-xwayland-overlay.nix;
      mkHost =
        {
          hardwareModule,
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          system = machine.system;

          specialArgs = {
            inherit waterfox;
          };

          modules = [
            hardwareModule
            ./hosts/nixos

            {
              nixpkgs.hostPlatform = machine.system;
              nixpkgs.overlays = [ mutterNoXWaylandOverlay ];
            }

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

                home-manager.users = {
                  ${config.neodots.username} = {
                    imports = [
                      ./hosts/nixos/home.nix
                      catppuccin.homeModules.catppuccin
                      spicetify-nix.homeManagerModules.spicetify
                    ];
                  };
                  guest = {
                    imports = [ ./hosts/nixos/guest-home.nix ];
                  };
                }
                // nixpkgs.lib.optionalAttrs config.neodots.desktop.river.enable {
                  ${config.neodots.desktop.river.user} = {
                    imports = [
                      ./hosts/nixos/river-home.nix
                      catppuccin.homeModules.catppuccin
                    ];
                  };
                };
              }
            )
          ]
          ++ extraModules;
        };
    in
    {
      # Production hardware is selected explicitly; CI never overwrites it.
      nixosConfigurations = {
        ${machine.neodots.hostname} = mkHost {
          hardwareModule = machine.hardwareModule;
        };
        ci = mkHost {
          hardwareModule = ./tests/fixtures/hardware-configuration.nix;
          extraModules = [
            {
              neodots.personal.enable = nixpkgs.lib.mkForce false;
              neodots.hostname = nixpkgs.lib.mkForce "neodots-ci";
              neodots.vm = {
                enable = nixpkgs.lib.mkForce true;
                platform = nixpkgs.lib.mkForce "qemu";
              };
            }
          ];
        };
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

      # Explicit opt-in: this QEMU test is intentionally outside default checks.
      packages.${machine.system}.dns-qemu = import ./tests/dns-qemu.nix {
        pkgs = nixpkgs.legacyPackages.${machine.system};
      };

      # ─────────────────────────── Checks ───────────────────────────────
      checks.${machine.system} =
        let
          # Use the same Mutter build for the VM test as the installed system.
          pkgs = import nixpkgs {
            system = machine.system;
            overlays = [ mutterNoXWaylandOverlay ];
          };

          result = import ./tests {
            lib = nixpkgs.lib;
            base = self.nixosConfigurations.ci;
          };
        in
        {
          repository-policy =
            pkgs.runCommand "neodots-repository-policy"
              {
                nativeBuildInputs = [
                  pkgs.python3
                  pkgs.actionlint
                  pkgs.shellcheck
                ];
              }
              ''
                cp -r ${./.} source
                chmod -R u+w source
                cd source
                python3 tests/repository-policy.py
                actionlint .github/workflows/*.yml
                shellcheck -s bash tests/check-wayland-migration.sh modules/personal/check-age-key.sh modules/desktop/river/session.sh
                touch $out
              '';

          cpp-toolchain =
            pkgs.runCommand "neodots-cpp-toolchain"
              {
                nativeBuildInputs = self.devShells.${machine.system}.cpp.nativeBuildInputs;
              }
              ''
                ${self.devShells.${machine.system}.cpp.shellHook}
                printf '#include <iostream>\nint main() { std::cout << "toolchain-ok"; }\n' > main.cpp
                printf 'cmake_minimum_required(VERSION 3.20)\nproject(smoke LANGUAGES CXX)\nadd_executable(smoke main.cpp)\n' > CMakeLists.txt
                cmake -S . -B build
                cmake --build build
                test "$(build/smoke)" = toolchain-ok
                test -s build/compile_commands.json
                touch $out
              '';

          river-session =
            pkgs.runCommand "neodots-river-session"
              {
                nativeBuildInputs = [
                  pkgs.python3
                  pkgs.bash
                ];
              }
              ''
                mkdir -p modules/desktop/river tests
                cp ${./modules/desktop/river/session.sh} modules/desktop/river/session.sh
                cp ${./tests/river-session.py} tests/river-session.py
                python3 tests/river-session.py
                touch $out
              '';

          river-quickshell =
            pkgs.runCommand "neodots-river-quickshell"
              {
                nativeBuildInputs = [
                  pkgs.python3
                  pkgs.quickshell
                ];
              }
              ''
                python3 ${./tests/river-quickshell.py} ${pkgs.quickshell}/bin/qs
                touch $out
              '';

          dsh-installer =
            let
              installerText =
                builtins.elemAt
                  (import ./modules/programs/deepseek-harness.nix {
                    config.home.homeDirectory = "/unused";
                    pkgs = pkgs // {
                      writeShellApplication = args: args.text;
                    };
                  }).home.packages
                  1;
            in
            pkgs.runCommand "neodots-dsh-installer"
              {
                nativeBuildInputs = [
                  pkgs.python3
                  pkgs.nodejs_24
                  pkgs.bash
                ];
              }
              ''
                python3 ${./tests/check-dsh-installer.py} ${pkgs.writeText "dsh-installer.sh" installerText}
                touch $out
              '';

          sops-recovery =
            pkgs.runCommand "neodots-sops-recovery"
              {
                nativeBuildInputs = [
                  pkgs.python3
                  pkgs.age
                  pkgs.sops
                  (pkgs.writeShellApplication {
                    name = "check-sops-age-key";
                    runtimeInputs = [ pkgs.coreutils ];
                    text = builtins.readFile ./modules/personal/check-age-key.sh;
                  })
                  (pkgs.callPackage sops-nix { }).sops-install-secrets
                ];
              }
              ''
                python3 ${./tests/sops-recovery.py}
                touch $out
              '';

          config-invariants =
            if result.failed == [ ] then
              pkgs.runCommand "neodots-config-invariants" { } "touch $out"
            else
              throw result.failureMessage;

          river-vm = import ./tests/river-vm.nix {
            inherit pkgs home-manager;
          };

          security-persistence-vm = import ./tests/security-persistence-vm.nix {
            inherit
              pkgs
              home-manager
              sops-nix
              impermanence
              ;
          };

          # Exercise actual GUI clients against a headless Wayland compositor.
          # Unlike config evaluation, this launches GTK, Qt, SDL and Electron windows.
          wayland-client-smoke = import ./tests/wayland-client-smoke.nix {
            inherit pkgs;
          };

          # Upstream-style end-to-end test for GDM + GNOME Shell.
          # Executing the VM test requires KVM support on the builder.
          gnome-wayland-vm = import ./tests/gnome-wayland-vm.nix {
            inherit pkgs;
          };
        };
    };
}
