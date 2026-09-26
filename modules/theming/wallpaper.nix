# modules/theming/wallpaper.nix
{ pkgs, config, ... }:

let
  picturesDir = "${config.home.homeDirectory}/Pictures";

  pickWallpaper = pkgs.writeShellScript "pick-wallpaper" ''
    set -euo pipefail

    dir=${picturesDir}

    if [ ! -d "$dir" ]; then
      echo "wallpaper dir does not exist: $dir" >&2
      exit 1
    fi

    mapfile -d "" files < <(
      find "$dir" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
           -o -iname '*.webp' -o -iname '*.bmp' \) -print0
    )

    if [ "''${#files[@]}" -eq 0 ]; then
      echo "no images found in $dir" >&2
      exit 1
    fi

    choice=$(printf '%s\0' "''${files[@]}" | shuf -z -n1 | tr -d '\0')
    exec ${pkgs.feh}/bin/feh --bg-fill "$choice"
  '';
in
{
  systemd.user.services.feh-wallpaper = {
    Unit = {
      Description = "Set random desktop wallpaper with feh";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pickWallpaper}";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
