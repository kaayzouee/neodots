# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{
  description = "Neodots NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    catppuccin = {
      url = "github:catppuccin/nix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fcitx5-lotus = {
      url = "github:LotusInputMethod/fcitx5-lotus";
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
      fcitx5-lotus,
      waterfox,
      sops-nix,
      impermanence,
    }:

    let
      machine = import ./hosts/nixos/machine.nix;
    in
    {
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
          fcitx5-lotus.nixosModules.fcitx5-lotus
          sops-nix.nixosModules.sops
          impermanence.nixosModules.impermanence

          ({ config, ... }:
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

              home-manager.users.guest = {
                imports = [
                  ./hosts/nixos/guest-home.nix
                ];
              };
            })
        ];
      };
    };
}
