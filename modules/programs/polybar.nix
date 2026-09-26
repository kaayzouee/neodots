# modules/programs/polybar.nix
{ pkgs, lib, ... }:

{
  services.polybar = {
    enable = true;
    package = pkgs.polybar.override { pulseSupport = true; };
    config = ../../config/polybar/config.ini;
    script = "polybar main &";
  };

  # Home Manager's polybar module wires the unit to its own tray.target
  # and sets a minimal PATH that only contains polybar's own bin dir.
  # That breaks two things:
  #   1. tray.target is never activated under XFCE, so the service never starts
  #   2. format-tag commands (nmtui, pavucontrol, pactl, xfce4-terminal) are
  #      not found, so clicking bar items does nothing
  # mkForce is required because Home Manager defines these options too.
  systemd.user.services.polybar = {
    Unit = {
      Description = lib.mkForce "Polybar status bar";
      After = lib.mkForce [ "graphical-session.target" ];
      PartOf = lib.mkForce [ "graphical-session.target" ];
      ConditionPathExists = lib.mkForce [ ];
      ConditionEnvironment = lib.mkForce [ ];
      AssertPathExists = lib.mkForce [ ];
    };

    Service = {
      Environment = lib.mkForce [
        "PATH=/run/current-system/sw/bin:/run/wrappers/bin:${pkgs.polybar}/bin"
      ];
    };

    Install.WantedBy = lib.mkForce [ "graphical-session.target" ];
  };
}
