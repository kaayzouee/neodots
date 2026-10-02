{
  description = "Kay's NixOS flake";

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
    }:

    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit waterfox;
        };

        modules = [
          ./hosts/nixos

          catppuccin.nixosModules.catppuccin
          home-manager.nixosModules.home-manager
          fcitx5-lotus.nixosModules.fcitx5-lotus
          sops-nix.nixosModules.sops

          {
            home-manager.useGlobalPkgs = true;

            home-manager.backupFileExtension = "backup";

            home-manager.extraSpecialArgs = {
              inherit waterfox;
            };

            home-manager.sharedModules = [
              sops-nix.homeManagerModules.sops
            ];

            # -----------------------------------------------------------------
            # Personal user
            # -----------------------------------------------------------------

            home-manager.users.kay = {
              imports = [
                ./hosts/nixos/home.nix
                catppuccin.homeModules.catppuccin
              ];
            };

            # -----------------------------------------------------------------
            # Disposable guest user
            # -----------------------------------------------------------------

            home-manager.users.guest = {
              imports = [
                ./hosts/nixos/guest-home.nix
              ];
            };
          }
        ];
      };
    };
}
