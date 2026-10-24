<!--
SPDX-License-Identifier: GPL-3.0-only

Neodots - GNOME/Wayland migration map, compatibility audit and references.

Copyright (C) 2026 kaayzouee
Author: https://github.com/kaayzouee

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, version 3 of the License.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>.
-->

# GNOME on Wayland migration

## Scope and policy

The primary NixOS session is GNOME on Wayland. GDM is the login manager. XWayland is explicitly disabled, so an X11-only application is expected to fail to launch rather than silently create an X11 compatibility session. River remains available as an optional, separate Wayland session through the existing session package.

“Zero X11 leftovers” here means no X11 desktop/session manager, no XFCE session configuration, no X11-only compositor/panel/wallpaper utility, no XWayland server, and no application intentionally configured to select the X11 backend. Some cross-platform applications may still have optional X11-related code or shared libraries in their upstream build; removing every such library would require replacing many unrelated applications and is not the same as running an X11 session.

## Configuration change map

| File or area | Before | Migration |
|---|---|---|
| flake.nix | Pins Nixpkgs to 26.05 | Tracks NixOS unstable; Home Manager and Catppuccin stay on their 26.05 release branches and follow the same Nixpkgs input; adds Spicetify-Nix |
| hosts/nixos/default.nix | Imports desktop-xfce.nix | Imports desktop-gnome.nix; River session registration remains |
| modules/desktop/desktop-gnome.nix | No GNOME module | Enables GNOME, GDM, default GNOME session, portals and strict Wayland environment; disables XWayland |
| hosts/nixos/home.nix | Home Manager X session, XFCE xfconf, Polybar/Picom imports | Removes X session and XFCE settings; uses Home Manager dconf for keyboard shortcuts and US keyboard layout |
| hosts/nixos/guest-home.nix | Polybar, Picom, feh and XFCE app finder | Removes these imports/packages; guest uses GNOME through GDM |
| modules/theming/wallpaper.nix | feh sets X11 root-window background | Picks a random picture and updates GNOME background preferences with gsettings |
| modules/system/packages.nix | Picom, NetworkManager applet, Dunst and a standalone Spotify package | Removes desktop tools GNOME replaces; keeps Wine's Wayland-only variant. Spotify is installed once through Spicetify-Nix in the primary user's Home Manager configuration |
| packages/river/default.nix | Optional XWayland/X11 build path | Removes xwayland, libx11 and xwaylandSupport from the River recipe |
| .github/workflows/evaluate.yml | Nix evaluation/build checks | Adds a fast source-level regression test to reject old desktop components |
| tests/default.nix | Existing NixOS account/system invariants | Adds GNOME/GDM/default-session, disabled-XWayland and legacy-package assertions |
| Removed files | XFCE module, Home Manager X session module, Polybar module/config/helper, Picom module and obsolete XFCE comment | Deleted instead of leaving dormant imports/files |

GNOME's Mutter compositor replaces Picom. GNOME Shell provides the panel, workspace overview, app launcher, network Quick Settings and notification centre that Polybar, xfce4-appfinder, networkmanagerapplet and Dunst were providing. GNOME's background preferences replace feh.

The existing Catppuccin Home Manager theme, Waterfox profile customizations, Alacritty, Fish, tmux, Thunar and the native Wayland River setup are retained. Thunar is GTK-based and is not inherently an X11-only application; Nautilus is the GNOME-native alternative if tighter desktop integration is preferred.

## Unstable Fish compatibility

The locked unstable Fish package is 4.9.3, but the NixOS and Home Manager completion generators still call `share/fish/tools/create_manpage_completions.py`, removed upstream in Fish 4.8.0. This breaks package builds such as Alacritty's generated Fish completions even though the configuration evaluates.

The workaround sets `programs.fish.generateCompletions = false` for both NixOS and the relevant Home Manager users. This disables only the automatic generation of completions from man pages; Fish's built-in completions and completions shipped directly by packages remain available. Revisit this override after Nixpkgs updates its completion generator. See [Nixpkgs issue #535122](https://github.com/NixOS/nixpkgs/issues/535122).

## Application/backend audit

The desktop sets GDK_BACKEND=wayland, QT_QPA_PLATFORM=wayland, MOZ_ENABLE_WAYLAND=1, NIXOS_OZONE_WL=1 and SDL_VIDEODRIVER=wayland. These request native Wayland backends for the relevant GTK, Qt, Mozilla, Chromium/Electron and SDL applications. GNOME is the default GDM session, and XWayland itself is force-disabled.

| Application or component | Assessment / action |
|---|---|
| Alacritty, Fish, tmux | Keep; Alacritty supports native Wayland and CLI tools do not need a display server |
| Waterfox | Keep; MOZ_ENABLE_WAYLAND=1 requests Wayland; verify about:support after login |
| VS Code, Vesktop | Keep provisionally; both are Electron applications and NIXOS_OZONE_WL=1 requests Ozone Wayland. Runtime-check windowing, screen sharing and input methods |
| GIMP, Thunar, virt-manager, File Roller | GTK-based applications expected to use Wayland; test important dialogs, drag-and-drop and file pickers |
| pdf4qt and other Qt applications | Force the Qt Wayland platform; an app missing a Wayland platform plugin will fail rather than intentionally fall back to X11 |
| Wine | Replaced with wineWow64Packages.waylandFull, a Nixpkgs Wine build with X11 support disabled. Individual Windows apps may still rely on features or behaviour that do not work under Wine's Wayland driver |
| Polybar | X11-oriented panel; removed. Use GNOME Shell panel, Activities and Quick Settings |
| Picom | X11 compositor; removed. Mutter is the GNOME compositor |
| feh wallpaper setter | Uses an X11 root-window API; removed. GNOME's background schema replaces it |
| XFCE app finder and xfconf | Removed; use GNOME Activities overview and Settings/dconf |
| NetworkManager applet and Dunst | Removed; GNOME Quick Settings and notification centre provide those functions |
| Spotify (Nixpkgs, wrapped by Spicetify-Nix) | Use the Nixpkgs unstable Spotify package with programs.spicetify.wayland = true; upstream fixed the wrapper to clear DISPLAY when NIXOS_OZONE_WL=1. Verify successful launch with XWayland disabled |

### Spotify with Spicetify-Nix

The flake follows the NixOS unstable channel and includes github:Gerg-L/spicetify-nix. The primary user imports Spicetify-Nix through Home Manager, which installs its wrapped Nixpkgs Spotify package; do not add pkgs.spotify separately to environment.systemPackages or home.packages. The configuration explicitly sets spotifyPackage = pkgs.spotify, wayland = true, and the Catppuccin Mocha theme, plus the adblockify, hidePodcasts, and shuffle extensions.

Nixpkgs fixed the Spotify Wayland regression in PR #533561, merged to Nixpkgs master on June 20, 2026. The patch unsets DISPLAY when NIXOS_OZONE_WL=1, enabling the wrapper to request native Wayland. Pinning to unstable is needed for the fix to be present in the locked package set. Spicetify-Nix also exposes a wayland option; it is set to true here rather than relying on the ambient environment variable alone.

Spicetify-Nix makes customization declarative, but its Spotify UI modifications may need upstream updates when Spotify changes. On a fresh user profile, launch Spotify and sign in first so it can create its user configuration. Then verify the UI, theme, extensions and playback. With XWayland disabled, a Spotify launch failure is a release blocker for this strict Wayland profile.
## Input method caveat

This host uses Fcitx 5 and the custom fcitx5-lotus integration. Fcitx's Wayland guide specifically notes that GNOME talks to input methods through the IBus D-Bus protocol, so the IBus frontend must be available/started. Candidate-window behaviour over GNOME Shell UI is also limited. This is a runtime acceptance item, not something Nix evaluation can prove. Verify Vietnamese input in GTK, Qt and Electron apps after switching. Do not globally force GTK_IM_MODULE=fcitx without testing; Fcitx's documentation warns about GTK candidate-window issues when forcing the frontend globally.

## Validation and rollout

CI source/evaluation checks are added, but they cannot prove that the session renders correctly on a physical GPU or that each GUI application chooses the desired backend. On the target machine:

1. Review the proposed system generation:
   ~~~bash
   sudo nixos-rebuild dry-build --flake /etc/nixos#nixos
   ~~~
2. Apply the generation and reboot or log out:
   ~~~bash
   sudo nixos-rebuild switch --flake /etc/nixos#nixos
   ~~~
3. At GDM, select GNOME. Check session type and compositor:
   ~~~bash
   echo "$XDG_SESSION_TYPE"            # expected: wayland
   loginctl show-session "$XDG_SESSION_ID" -p Type -p Desktop
   pgrep -a Xwayland                    # expected: no process
   ~~~
4. Check wallpaper, Ctrl+Alt+T (Alacritty), Ctrl+Shift+T (Thunar), theme/cursor, lid/suspend, Flatpak portals, audio, networking, multi-monitor/scaling and clipboard.
5. Verify major applications individually:
   - Waterfox: about:support → Window Protocol should be wayland.
   - Electron apps: inspect their diagnostic page / Chromium GPU information and test screen sharing.
   - Spotify: check that the Spicetify-wrapped client opens and plays audio, and that the Catppuccin theme/extensions load after first login.
   - Qt apps: confirm they start without an XCB/X11 fallback.
   - Input method: type Vietnamese in GTK, Qt and Electron text fields.
6. Inspect warning logs:
   ~~~bash
   journalctl --user -b -p warning
   journalctl -b -u gdm -p warning
   ~~~

Run the static guard locally with:
~~~bash
bash tests/check-wayland-migration.sh
~~~

The existing workflows also run nix flake check --all-systems --no-build, evaluate the NixOS derivation and build the system. GUI testing still requires a real login or a VM with appropriate graphics/input support.

## Automated runtime checks

The Evaluate workflow runs `tests/wayland-client-smoke.nix` as a build-time test. It starts Weston with its headless backend and no X server, then builds and launches tiny GTK 4, Qt 6, SDL 2, and Electron clients with the corresponding native Wayland backend forced. GTK, Qt, and SDL also have to produce Wayland protocol traffic. This catches missing Wayland plugins, broken platform selection, and clients that exit/crash during initial window creation; it is a backend smoke test, not a substitute for testing each application feature.

The flake also defines `checks.x86_64-linux.gnome-wayland-vm` in `tests/gnome-wayland-vm.nix`. It follows the upstream Nixpkgs GNOME integration-test pattern: start GDM, autologin a disposable test user, wait for the Wayland socket, verify GNOME Shell finishes startup, launch GNOME Console, assert XWayland is absent, reboot, and repeat startup assertions. The workflow executes this VM test only when `/dev/kvm` is readable and writable; ordinary GitHub-hosted runners do not consistently expose nested virtualization, so a skipped VM test is reported as a notice rather than a pass.

The existing `nixos-build` job still builds the actual Neodots system closure, and the Evaluate job still evaluates the actual flake and system derivation. Those checks catch missing package outputs and build-time regressions in the configured package set.

Automated CI cannot prove behavior that depends on physical GPU/driver combinations, Vietnamese composition in each real application, screen sharing and portal permissions, a real Spotify login/playback session, or suspend/resume behavior on the target laptop. These remain explicit manual acceptance tests. The GNOME VM test is based on [the Nixpkgs GNOME test](https://github.com/NixOS/nixpkgs/blob/master/nixos/tests/gnome.nix) and [the NixOS test-driver documentation](https://nixos.org/manual/nixos/unstable/#sec-running-nixos-tests).

## Useful references

- **NixOS GNOME desktop setup** — exact GNOME/GDM module options and warning about mixing desktop managers: https://wiki.nixos.org/wiki/GNOME
- **Nixpkgs Fish completion regression #535122** — Fish 4.8+ removed the man-page completion script; disabling auto-generation is the workaround: https://github.com/NixOS/nixpkgs/issues/535122
- **NixOS Wayland guidance** — Ozone Wayland environment variable and application compatibility: https://wiki.nixos.org/wiki/Wayland
- **NixOS manual** — module and system configuration reference: https://nixos.org/manual/nixos/stable/
- **Wine on NixOS** — package variants and Wayland-only Wine builds: https://wiki.nixos.org/wiki/Wine
- **Fcitx 5 on Wayland** — toolkit configuration, GNOME/IBus frontend requirement and caveats: https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland/en
- **Nixpkgs Spotify fix #533561** — merged wrapper change unsets DISPLAY when NIXOS_OZONE_WL=1: https://github.com/NixOS/nixpkgs/pull/533561
- **Spicetify-Nix usage/options** — declarative Home Manager integration and native-Wayland option: https://gerg-l.github.io/spicetify-nix/usage.html and https://gerg-l.github.io/spicetify-nix/options.html
- **GNOME release notes** — distinguishes a native Wayland session from XWayland compatibility: https://release.gnome.org/49/developers/

References checked on 2026-10-22. The pinned inputs in flake.lock remain the source of truth for exact option availability.
