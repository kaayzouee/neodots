# SPDX-License-Identifier: GPL-3.0-only
#
# Disable XWayland support in Mutter itself. The NixOS
# programs.xwayland.enable option alone does not prevent Mutter from starting
# XWayland directly when the compositor was built with that feature enabled.

final: prev: {
  mutter = prev.mutter.overrideAttrs (old: {
    mesonFlags =
      (builtins.filter (flag: !(prev.lib.hasPrefix "-Dxwayland=" flag)) (old.mesonFlags or [ ]))
      ++ [ "-Dxwayland=false" ];
  });
}
