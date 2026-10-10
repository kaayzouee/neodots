# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{
  config,
  pkgs,
  waterfox,
  ...
}:

{
  imports = [
    # Machine-specific generated hardware configuration.
    ../../hardware-configuration.nix

    # -------------------------------------------------------------------------
    # Desktop
    # -------------------------------------------------------------------------

    ../../modules/desktop/desktop-xfce.nix

    # -------------------------------------------------------------------------
    # Hardware
    # -------------------------------------------------------------------------

    ../../modules/hardware/fonts.nix
    ../../modules/hardware/fcitx5-lotus.nix
    ../../modules/hardware/inputmethod.nix
    ../../modules/hardware/mice.nix

    # -------------------------------------------------------------------------
    # System
    # -------------------------------------------------------------------------

    ../../modules/system/neodots.nix
    ../../modules/system/packages.nix
    ../../modules/system/networking.nix
    ../../modules/system/boot.nix
    ../../modules/system/sound.nix
    ../../modules/system/users.nix
    ../../modules/system/virtualization.nix
    ../../modules/system/bluetooth.nix
    ../../modules/system/persistence.nix

    # -------------------------------------------------------------------------
    # Programs
    # -------------------------------------------------------------------------

    # NOTE:
    # The old modules/programs/vscode.nix is intentionally NOT imported.
    # VS Code is configured through Home Manager instead.

    ../../modules/programs/pcscd.nix
    ../../modules/programs/thunar.nix
    ../../modules/programs/fish.nix
  ];

  networking.hostName = config.neodots.hostname;

  # Include River in the generated display-manager session directory.
  # Installing a compositor in environment.systemPackages alone does not
  # register its .desktop file with LightDM's session chooser.
  services.displayManager.sessionPackages = [
    (pkgs.callPackage ../../packages/river { })
  ];

  # ---------------------------------------------------------------------------
  # Nix
  # ---------------------------------------------------------------------------

  nix = {
    package = pkgs.nixVersions.stable;

    extraOptions = ''
      experimental-features = nix-command flakes
    '';

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    settings.auto-optimise-store = true;
  };

  nixpkgs.config.allowUnfree = true;

  # ---------------------------------------------------------------------------
  # System
  # ---------------------------------------------------------------------------

  time.timeZone = "Asia/Bangkok";

  # ---------------------------------------------------------------------------
  # System-wide packages
  # ---------------------------------------------------------------------------

  environment.systemPackages = [
    waterfox.packages.${pkgs.stdenv.hostPlatform.system}.waterfox-bin
  ];

  system.stateVersion = "26.05";
}
