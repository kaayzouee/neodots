# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ pkgs, waterfox, ... }:

let
  PKG_prolangs =
    import ../../packages/PKG-prolangs.nix { inherit pkgs; };

  PKG_editors =
    import ../../packages/PKG-editors.nix { inherit pkgs; };

  PKG_systemnetworking =
    import ../../packages/PKG-systemnetworking.nix { inherit pkgs; };

  PKG_vpn =
    import ../../packages/PKG-vpn.nix { inherit pkgs; };

  PKG_multimedia =
    import ../../packages/PKG-multimedia.nix { inherit pkgs; };

  PKG_WMnoti =
    import ../../packages/PKG-WMnoti.nix { inherit pkgs; };

  PKG_themes =
    import ../../packages/PKG-themes.nix { inherit pkgs; };

  PKG_VM =
    import ../../packages/PKG-VM.nix { inherit pkgs; };

  PKG_ricing =
    import ../../packages/PKG-forricing.nix { inherit pkgs; };

  PKG_keygen =
    import ../../packages/PKG-keygen.nix { inherit pkgs; };

  PKG_cli_shg =
    import ../../packages/cli-tools/PKG-CLI-shg.nix { inherit pkgs; };

  # ---------------------------------------------------------------------------
  # CLI
  # ---------------------------------------------------------------------------

  PKG_cli_compression =
    import ../../packages/cli-tools/PKG-CLI-compression.nix { inherit pkgs; };

  PKG_cli_file_listing =
    import ../../packages/cli-tools/PKG-CLI-file-listing.nix { inherit pkgs; };

  PKG_cli_file_search =
    import ../../packages/cli-tools/PKG-CLI-file-search.nix { inherit pkgs; };

  PKG_cli_git =
    import ../../packages/cli-tools/PKG-CLI-git.nix { inherit pkgs; };

  PKG_cli_monitoring =
    import ../../packages/cli-tools/PKG-CLI-monitoring.nix { inherit pkgs; };

  PKG_cli_networking =
    import ../../packages/cli-tools/PKG-CLI-networking.nix { inherit pkgs; };

  PKG_cli_terminal_multiplexers =
    import ../../packages/cli-tools/PKG-CLI-terminal-multiplexers.nix { inherit pkgs; };

  PKG_cli_terminal_others =
    import ../../packages/cli-tools/PKG-CLI-terminal-others.nix { inherit pkgs; };

in
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
    ../../modules/hardware/inputmethod.nix
    ../../modules/hardware/mice.nix

    # -------------------------------------------------------------------------
    # System
    # -------------------------------------------------------------------------

    ../../modules/system/networking.nix
    ../../modules/system/boot.nix
    ../../modules/system/sound.nix
    ../../modules/system/users.nix
    ../../modules/system/virtualization.nix
    ../../modules/system/bluetooth.nix

    # -------------------------------------------------------------------------
    # Programs
    # -------------------------------------------------------------------------

    # NOTE:
    # The old modules/programs/vscode.nix is intentionally NOT imported.
    # VS Code is configured through Home Manager instead.

    ../../modules/programs/pcscd.nix
    ../../modules/programs/sops.nix
    ../../modules/programs/thunar.nix
  ];

  networking.hostName = "nixos";

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

  environment.systemPackages =
    PKG_prolangs
    ++ PKG_editors

    ++ PKG_cli_compression
    ++ PKG_cli_file_listing
    ++ PKG_cli_file_search
    ++ PKG_cli_git
    ++ PKG_cli_monitoring
    ++ PKG_cli_networking
    ++ PKG_cli_terminal_multiplexers
    ++ PKG_cli_terminal_others

    ++ PKG_systemnetworking
    ++ PKG_vpn
    ++ PKG_multimedia
    ++ PKG_WMnoti
    ++ PKG_themes
    ++ PKG_VM
    ++ PKG_ricing
    ++ PKG_keygen
    ++ PKG_cli_shg

    ++ [
      waterfox.packages.${pkgs.stdenv.hostPlatform.system}.waterfox-bin
    ];

  system.stateVersion = "26.05";
}
