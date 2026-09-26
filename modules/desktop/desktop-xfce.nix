# modules/desktop-xfce.nix
# modules/desktop-xfce.nix
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
  # Prevents xfce4-panel and friends from being installed at all, so
  # xfce4-session never tries to restore a panel that doesn't exist
  environment.xfce.excludePackages = with pkgs; [
    xdg-desktop-portal-xapp
    xfce4-notifyd
    xfce4-panel
  ];

  # ─── X server + Display Manager + Desktop ────────────────────────────────
  services.xserver = {
    enable = true;

    displayManager.lightdm.enable = true;

    desktopManager.xfce = {
      enable = true;
      # Tell the XFCE module not to install the default desktop shell.
      # This complements excludePackages above and is the most direct way
      # to say "I only want the WM + settings daemons, no panel/desktop."
      # Uncomment the next line if you also want to drop xfdesktop and
      # the default XFCE background/session stack:
      # noDesktop = true;
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
