{ pkgs, waterfox, ... }:

{
  home.stateVersion = "26.05";

  home.username = "guest";
  home.homeDirectory = "/home/guest";

  imports = [
    # Gives the guest the same Polybar infrastructure,
    # but none of your personal Home Manager modules.
    ../../modules/programs/polybar.nix
  ];

  # ---------------------------------------------------------------------------
  # Guest applications
  # ---------------------------------------------------------------------------
  #
  # This is intentionally small.
  #
  # The system still contains your normal system-wide packages, so this is
  # NOT a hard security allowlist. It defines the software intentionally
  # exposed through the guest's own Home Manager environment.
  #
  home.packages = [
    pkgs.git
    pkgs.feh
    pkgs.xfce4-terminal
    pkgs.xfce4-appfinder

    waterfox.packages.${pkgs.stdenv.hostPlatform.system}.waterfox-bin
  ];

  # ---------------------------------------------------------------------------
  # VS Code
  # ---------------------------------------------------------------------------

  programs.vscode = {
    enable = true;

    profiles.default.extensions = with pkgs.vscode-extensions; [
      # LLDB debugger / CodeLLDB
      vadimcn.vscode-lldb
    ];
  };

  # ---------------------------------------------------------------------------
  # Git
  # ---------------------------------------------------------------------------
  #
  # Do NOT import your personal modules/programs/git.nix here because that
  # module pulls credentials from SOPS.
  #
  # The guest gets a completely independent identity.
  #

  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "Guest";
        email = "guest@localhost";
      };

      init.defaultBranch = "main";

      # Do not use your personal credential helper configuration.
      credential.helper = "";
    };
  };

  # ---------------------------------------------------------------------------
  # Browser
  # ---------------------------------------------------------------------------

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

  home.sessionVariables = {
    BROWSER = "waterfox";
    EDITOR = "code";
    VISUAL = "code";
  };

  # Keep Home Manager usable from the guest account if necessary.
  programs.home-manager.enable = true;
}
