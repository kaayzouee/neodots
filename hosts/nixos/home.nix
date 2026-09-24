
{ config, ... }:

{
  home.stateVersion = "26.05";

  catppuccin = {
    enable = true;
    flavor = "mocha";
    accent = "mauve";
  };

  imports = [
    ../../modules/theming/cursor.nix
    ../../modules/programs/tmux.nix
    ../../modules/programs/fastfetch.nix
    ../../modules/programs/git.nix
  ];
  
  home.username = "kay";
  home.homeDirectory = "/home/kay";

  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  catppuccin.xfce4-terminal.enable = true;

  programs.home-manager.enable = true;

  xdg.mimeApps = {
    enable = true;

    defaultApplications = {
      "text/html" = "waterfox.desktop";
      "text/xml" = "waterfox.desktop";
      "application/xhtml+xml" = "waterfox.desktop";

      "x-scheme-handler/http" = "waterfox.desktop";
      "x-scheme-handler/https" = "waterfox.desktop";
      "x-scheme-handler/about" = "waterfox.desktop";
      "x-scheme-handler/unknown" = "waterfox.desktop";
    };
  };
}
