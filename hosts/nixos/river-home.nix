{ pkgs, ... }:

let
  neodotsQuickshellWatch = pkgs.writeShellScript "neodots-quickshell-watch" ''
    while true; do
      ${pkgs.inotify-tools}/bin/inotifywait \
        --recursive \
        --exclude '(^|/)[.]git(/|$)' \
        --event close_write,create,delete,move \
        --format '%w%f' \
        /home/river/neodots/config/quickshell/neodots >/dev/null 2>&1 || true

      # Editors commonly emit several filesystem events for one save.
      sleep 0.15

      systemctl --user reset-failed neodots-quickshell.service || true
      systemctl --user restart neodots-quickshell.service || true
    done
  '';
in

{
  home.stateVersion = "26.05";

  home.username = "river";
  home.homeDirectory = "/home/river";

  programs.home-manager.enable = true;

  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set -g fish_greeting 'Hello, world! ♡'

      if not set -q TMUX
        exec tmux new-session -A -s main
      end
    '';
  };

  imports = [
    ../../modules/programs/mako.nix
    ../../modules/theming/wallpaper-swaybg.nix
    ../../modules/programs/tmux.nix
    ../../modules/programs/alacritty.nix
    ../../modules/programs/fish.nix
  ];

  home.packages = with pkgs; [
    alacritty
    quickshell
    fuzzel
    libnotify
    wl-clipboard
    swaylock
    thunar
    wlr-randr
  ];

  # Install the Quickshell project into the user's config tree. Recursive
  # linking keeps QML files declarative while preserving the repo layout.
  home.file.".config/quickshell/neodots" = {
    source = ../../config/quickshell/neodots;
    recursive = true;
  };

  # Keep Quickshell under user-systemd supervision so it can restart without
  # affecting KWM or River when the shell process exits.
  systemd.user.services.neodots-quickshell = {
    Unit = {
      Description = "Neodots Quickshell shell";
      # Never suppress recovery because of repeated QML startup failures.
      StartLimitIntervalSec = "0s";
    };

    Service = {
      ExecStart = "${pkgs.quickshell}/bin/qs -c neodots";
      Restart = "on-failure";
      RestartSec = "1s";
    };
  };

  # Reload Quickshell automatically whenever the live repository is saved.
  systemd.user.services.neodots-quickshell-watch = {
    Unit = {
      Description = "Watch Neodots Quickshell sources";
      After = [ "neodots-quickshell.service" ];
      StartLimitIntervalSec = "0s";
    };

    Service = {
      ExecStart = "${neodotsQuickshellWatch}";
      Restart = "always";
      RestartSec = "1s";
    };
  };

  # River 0.4+ starts the configured window manager after the Wayland socket
  # is ready. Import the live Wayland/session variables into the user systemd
  # manager before starting the supervised Quickshell service.
  home.file.".config/river/init" = {
    text = ''
      exec sh -c '
        # Set every connected River output to 175% before shell geometry is read.
        ${pkgs.wlr-randr}/bin/wlr-randr 2>/dev/null |
          while IFS= read -r output_line; do
            case "$output_line" in
              ""|[[:space:]]*) continue ;;
            esac

            output_name=''${output_line%% *}
            [ -n "$output_name" ] || continue
            ${pkgs.wlr-randr}/bin/wlr-randr --output "$output_name" --scale 1.75 || true
          done

        systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE
        systemctl --user restart neodots-quickshell-watch.service
        systemctl --user reset-failed neodots-quickshell.service
        systemctl --user restart neodots-quickshell.service
        exec kwm
      '
    '';
    executable = true;
  };

  home.file.".config/kwm/config.zon".source = ../../config/kwm/config.zon;

}
