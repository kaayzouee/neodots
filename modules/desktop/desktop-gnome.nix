# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - GNOME desktop on native Wayland, with XWayland disabled.
#
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.

{ lib, ... }:

{
  # Mutter's XWayland support is compiled out by the overlay in flake.nix.
  # This option also prevents NixOS from installing the standalone XWayland package.

  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;
  services.displayManager.defaultSession = "gnome";

  # Strict native-Wayland policy: legacy X11-only applications will not launch.
  # Remove XWayland itself instead of silently running such applications through it.
  programs.xwayland.enable = lib.mkForce false;

  xdg.portal.enable = true;
  services.flatpak.enable = true;

  # Preserve the existing local guest account's passwordless login behaviour.
  security.pam.services.gdm-password.allowNullPassword = true;

  # Keep the existing laptop lid policy.
  services.logind.settings.Login = {
    HandleLidSwitch = "lock";
    HandleLidSwitchExternalPower = "lock";
  };

  # Prefer native Wayland backends for GTK, Qt, browsers and Electron apps.
  environment.sessionVariables = {
    GDK_BACKEND = "wayland";
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
  };
}
