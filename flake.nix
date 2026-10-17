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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Temporary workaround for solaar test failure (PR #574929 backport).
    # Remove once merged into nixos-26.05.
    solaar-pr.url = "github:NixOS/nixpkgs/pull/574929/head";

    catppuccin = {
      url = "github:catppuccin/nix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
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
      waterfox,
      sops-nix,
      impermanence,
      solaar-pr,
    }:

    let
      machine = import ./hosts/nixos/machine.nix;
    in
    {
      nixosConfigurations.${machine.neodots.hostname} = nixpkgs.lib.nixosSystem {
        system = machine.system;

        specialArgs = {
          inherit waterfox solaar-pr;
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
                inherit waterfox;
                neodots = config.neodots;
              };

              home-manager.sharedModules = [
                sops-nix.homeManagerModules.sops
              ];

              home-manager.users.${config.neodots.username} = {
                imports = [
                  ./hosts/nixos/home.nix
                  catppuccin.homeModules.catppuccin
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

      formatter.${machine.system} = nixpkgs.legacyPackages.${machine.system}.nixfmt-tree;

      # Evaluation-time invariants (see tests/default.nix). A failure throws
      # during evaluation so `nix flake check --no-build` catches it.
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
    };
}
