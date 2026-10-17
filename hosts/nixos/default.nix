# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Top-level NixOS module that imports the system modules and sets
#          Nix, time zone and session options.
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
  config,
  pkgs,
  waterfox,
  solaar-pr,
  ...
}:

let
  # Pull solaar from PR #574929's nixpkgs (mocks libnotify in tests).
  # Remove when the backport lands in nixos-26.05.
  solaarFromPr = solaar-pr.legacyPackages.${pkgs.stdenv.hostPlatform.system}.solaar;
in
{
  nixpkgs.overlays = [
    (final: prev: {
      solaar = solaarFromPr;
    })
  ];

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
    ../../modules/system/btrfs.nix
    ../../modules/system/vm.nix

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
