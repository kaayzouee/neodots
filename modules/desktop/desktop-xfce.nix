# modules/desktop-xfce.nix
{ config, pkgs, ... }:

{
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  services.flatpak.enable = true;

  environment.xfce.excludePackages = with pkgs; [
    xdg-desktop-portal-xapp
    xfce4-notifyd
  ];

  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = true;
    desktopManager.xfce.enable = true;
    xkb.layout = "us";
  };

  security.pam.services.lightdm.allowNullPassword = true;

  services.logind.settings.Login = {
  HandleLidSwitch = "lock";
  HandleLidSwitchExternalPower = "lock";
};
}
