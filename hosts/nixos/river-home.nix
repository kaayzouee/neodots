{ lib, pkgs, ... }:

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
    wtype
  ];

  # Install the Quickshell project into the user's config tree. Recursive
  # linking keeps QML files declarative while preserving the repo layout.
  home.file.".config/quickshell/neodots" = {
    source = ../../config/quickshell/neodots;
    recursive = true;
  };

  # Waterfox's own chrome hosts the traffic lights. Home Manager keeps the
  # stylesheet in the repo-managed config tree; activation merges it into each
  # existing Waterfox profile without replacing any personal userChrome rules.
  home.file.".config/neodots/waterfox/userChrome.css".source =
    ../../config/waterfox/userChrome.css;

  home.activation.neodotsWaterfoxChrome = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.python3}/bin/python3 - <<'PY'
    import configparser
    import os
    from pathlib import Path

    home = Path(os.environ["HOME"])
    managed_css = home / ".config/neodots/waterfox/userChrome.css"
    if not managed_css.is_file():
        raise SystemExit(0)

    begin = "/* BEGIN NEODOTS WATERFOX TRAFFIC LIGHTS */"
    end = "/* END NEODOTS WATERFOX TRAFFIC LIGHTS */"
    required_prefs = {
        "toolkit.legacyUserProfileCustomizations.stylesheets": "true",
        "browser.tabs.drawInTitlebar": "true",
    }

    roots = [
        home / ".waterfox",
        home / ".var/app/net.waterfox.waterfox/.waterfox",
    ]
    installed = 0

    for root in roots:
        profiles_ini = root / "profiles.ini"
        if not profiles_ini.is_file():
            continue

        parser = configparser.ConfigParser(interpolation=None)
        parser.read(profiles_ini)

        profiles = []
        for section in parser.sections():
            if not section.startswith("Profile"):
                continue
            profile_path = parser.get(section, "Path", fallback="")
            if not profile_path:
                continue
            if parser.getboolean(section, "IsRelative", fallback=True):
                profile = root / profile_path
            else:
                profile = Path(profile_path).expanduser()
            if profile.is_dir() and profile not in profiles:
                profiles.append(profile)

        for profile in profiles:
            chrome_dir = profile / "chrome"
            chrome_dir.mkdir(parents=True, exist_ok=True)
            css_path = chrome_dir / "userChrome.css"
            existing_css = css_path.read_text() if css_path.is_file() else ""
            while begin in existing_css and end in existing_css:
                before, remainder = existing_css.split(begin, 1)
                _, after = remainder.split(end, 1)
                existing_css = before + after
            existing_css = existing_css.rstrip()
            managed_block = begin + "\n" + managed_css.read_text().rstrip() + "\n" + end
            merged_css = (existing_css + "\n\n" if existing_css else "")
            css_path.write_text(merged_css + managed_block + "\n")
            user_js = profile / "user.js"
            prefs_text = user_js.read_text() if user_js.is_file() else ""
            prefs_lines = prefs_text.splitlines()
            for name, value in required_prefs.items():
                prefix_double = 'user_pref("' + name + '"'
                prefix_single = "user_pref('" + name + "'"
                prefs_lines = [
                    line for line in prefs_lines
                    if not (
                        line.strip().startswith(prefix_double)
                        or line.strip().startswith(prefix_single)
                    )
                ]
                prefs_lines.append('user_pref("' + name + '", ' + value + ');')
            user_js.write_text("\n".join(prefs_lines) + "\n")
            installed += 1

    print("Neodots Waterfox chrome installed in " + str(installed) + " profile(s).")
    PY
  '';

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
        # Set every connected River output to 150% before shell geometry is read.
        ${pkgs.wlr-randr}/bin/wlr-randr 2>/dev/null |
          while IFS= read -r output_line; do
            case "$output_line" in
              ""|[[:space:]]*) continue ;;
            esac

            output_name=''${output_line%% *}
            [ -n "$output_name" ] || continue
            ${pkgs.wlr-randr}/bin/wlr-randr --output "$output_name" --scale 1.5 || true
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
