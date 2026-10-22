#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Regression checks for the GNOME/Wayland-only desktop migration.
#
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, version 3 of the License.

set -euo pipefail
cd "$(dirname "$0")/.."

forbidden='xfce|xfconf|lightdm|xsession|feh|picom|polybar|networkmanagerapplet|xfce4-appfinder'
active_paths=(
  hosts/nixos/default.nix
  hosts/nixos/home.nix
  hosts/nixos/guest-home.nix
  modules/desktop
  modules/programs
  modules/system/packages.nix
  modules/theming/wallpaper.nix
)

if grep -nEi "$forbidden" "${active_paths[@]}"; then
  echo "Found an XFCE/X11 desktop component in active GNOME configuration." >&2
  exit 1
fi

if grep -nEi 'xwayland|libx11|xwaylandSupport' packages/river/default.nix; then
  echo "River package still exposes optional XWayland/X11 build support." >&2
  exit 1
fi

grep -Fq 'services.desktopManager.gnome.enable = true;' modules/desktop/desktop-gnome.nix
grep -Fq 'services.displayManager.gdm.enable = true;' modules/desktop/desktop-gnome.nix
grep -Fq 'programs.xwayland.enable = lib.mkForce false;' modules/desktop/desktop-gnome.nix
grep -Fq 'NIXOS_OZONE_WL = "1";' modules/desktop/desktop-gnome.nix
grep -Fq 'QT_QPA_PLATFORM = "wayland";' modules/desktop/desktop-gnome.nix

grep -Fq 'nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";' flake.nix
grep -Fq 'url = "github:Gerg-L/spicetify-nix";' flake.nix
grep -Fq 'spicetify-nix.homeManagerModules.spicetify' flake.nix
grep -Fq 'spotifyPackage = pkgs.spotify;' hosts/nixos/home.nix
grep -Fq 'wayland = true;' hosts/nixos/home.nix
if grep -nF 'pkgs.spotify' modules/system/packages.nix; then
  echo "Spotify must be installed through the Spicetify-Nix Home Manager module." >&2
  exit 1
fi

echo "GNOME/Wayland migration source checks passed."
