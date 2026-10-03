# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

# modules/desktop/desktop-xfce.nix
{ config, pkgs, ... }:

{
  # ─── XDG Portal ──────────────────────────────────────────────────────────
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  # ─── Flatpak ─────────────────────────────────────────────────────────────
  services.flatpak.enable = true;

  # ─── Exclude unwanted XFCE components ────────────────────────────────────
  # xfce4-panel: replaced by Polybar.
  # xfdesktop:   removed because it draws the wallpaper + icons synchronously
  #              on login and is the prime suspect for the multi-second
  #              freeze. We set the wallpaper with feh instead (see below).
  # xfce4-notifyd: replaced by dunst.
  environment.xfce.excludePackages = with pkgs; [
    xdg-desktop-portal-xapp
    xfce4-notifyd
    xfce4-panel
    xfdesktop
    xfce4-terminal
 ];

  # feh is the replacement wallpaper setter
  environment.systemPackages = with pkgs; [
    feh
  ];

  # ─── X server + Display Manager + Desktop ────────────────────────────────
  services.xserver = {
    enable = true;

    displayManager.lightdm.enable = true;

    desktopManager.xfce = {
      enable = true;
    };

    xkb.layout = "us";
  };

  # ─── LightDM PAM ─────────────────────────────────────────────────────────
  security.pam.services.lightdm.allowNullPassword = true;

  # ─── Power management ────────────────────────────────────────────────────
  services.logind.settings.Login = {
    HandleLidSwitch = "lock";
    HandleLidSwitchExternalPower = "lock";
  };
}
