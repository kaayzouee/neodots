{ pkgs, ... }:

{
  # ---------------------------------------------------------------------------
  # Fcitx5
  # ---------------------------------------------------------------------------

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
  };

  # ---------------------------------------------------------------------------
  # Linux uinput
  # ---------------------------------------------------------------------------
  #
  # fcitx5-lotus-server creates/uses a virtual input device through uinput.
  #
  # NixOS creates the uinput device/group when this option is enabled.
  #

  hardware.uinput.enable = true;

  # ---------------------------------------------------------------------------
  # Lotus
  # ---------------------------------------------------------------------------

  services.fcitx5-lotus = {
    enable = true;
    users = [ "kay" ];
  };
}
