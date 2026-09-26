{ pkgs, lib, ... }:
{
  services.polybar = {
    enable = true;
    package = pkgs.polybar.override { pulseSupport = true; };
    config = ../../config/polybar/config.ini;
    script = "polybar main &";
  };

  # Force the service to be pulled in by the real graphical session target,
  # and strip whatever Condition the HM module added that's failing
  systemd.user.services.polybar = {
    Unit = {
      Description = lib.mkForce "Polybar status bar";
      After = lib.mkForce [ "graphical-session.target" ];
      PartOf = lib.mkForce [ "graphical-session.target" ];
      # Clear inherited conditions:
      ConditionPathExists = lib.mkForce [];
      ConditionEnvironment = lib.mkForce [];
      AssertPathExists = lib.mkForce [];
    };
    Install.WantedBy = lib.mkForce [ "graphical-session.target" ];
  };
}
