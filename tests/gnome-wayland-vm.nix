# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - GNOME Wayland login and display-manager recovery test.
#
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.

{ pkgs }:

# Follow the upstream Nixpkgs GNOME test pattern: autologin under GDM, wait for
# the user's Wayland socket and GNOME Shell to finish starting, then launch a
# real desktop application. Run this check only on builders with KVM support.
pkgs.testers.runNixOSTest {
  name = "neodots-gnome-wayland";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ ../modules/desktop/desktop-gnome.nix ];

      services.displayManager.autoLogin = {
        enable = true;
        user = "ci";
      };

      services.displayManager.gdm.debug = true;
      services.desktopManager.gnome.debug = true;

      users.users.ci = {
        isNormalUser = true;
        uid = 1000;
        initialPassword = "ci";
      };

      environment.systemPackages = [ pkgs.gnome-console ];

      # Match the upstream Nixpkgs GNOME test workaround so the Shell Eval
      # D-Bus API can report when startup has completed.
      systemd.user.services."org.gnome.Shell@" = {
        serviceConfig.ExecStart = [
          ""
          "${pkgs.gnome-shell}/bin/gnome-shell --unsafe-mode"
        ];
      };
    };

  testScript =
    { ... }:
    let
      userName = "ci";
      uid = "1000";
      bus = "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus";
      run = command: "su - ${userName} -c '${bus} ${command}'";
      eval =
        command:
        run "gdbus call --session -d org.gnome.Shell -o /org/gnome/Shell -m org.gnome.Shell.Eval ${command}";
      startingUp = eval "Main.layoutManager._startingUp";
      launchConsole = run "gapplication launch org.gnome.Console";
      wmClass = eval "global.display.focus_window.wm_class";
    in
    ''
      start_all()

      with subtest("GDM starts and creates a Wayland user session"):
          machine.wait_for_unit("display-manager.service")
          machine.wait_until_succeeds("test -S /run/user/${uid}/wayland-0", timeout=120)
          machine.wait_for_unit("default.target", "${userName}")
          machine.succeed("systemctl is-active --quiet display-manager.service")
          machine.succeed("pgrep -u ${uid} -f '[g]nome-shell'")
          machine.succeed("test -S /run/user/${uid}/wayland-0")

      with subtest("GNOME Shell completes startup without a black-screen crash"):
          machine.wait_until_succeeds("${startingUp} | grep -q 'true,..false'", timeout=120)
          machine.succeed("grep -zq 'GDK_BACKEND=wayland' /proc/$(pgrep -o -u ${uid} -f '[g]nome-shell')/environ")
          machine.succeed("grep -zq 'NIXOS_OZONE_WL=1' /proc/$(pgrep -o -u ${uid} -f '[g]nome-shell')/environ")
          # Check after Shell startup: Mutter normally starts XWayland lazily,
          # so checking immediately after the Wayland socket appears is racy.
          machine.fail("pgrep -x Xwayland")

      with subtest("A desktop application opens in the GNOME session"):
          machine.send_key("esc")
          machine.succeed("${launchConsole}")
          machine.wait_until_succeeds("${wmClass} | grep -q 'true,...org.gnome.Console'", timeout=120)

      with subtest("The login session starts again after GDM restarts"):
          # A full VM reboot can strand the NixOS test driver's control shell
          # on hosted QEMU runners. Restart GDM to exercise session teardown
          # and autologin recovery while keeping the test harness connected.
          machine.succeed("systemctl restart display-manager.service")
          machine.wait_until_succeeds("test -S /run/user/${uid}/wayland-0", timeout=120)
          machine.wait_until_succeeds("pgrep -u ${uid} -f '[g]nome-shell'", timeout=120)
          machine.wait_until_succeeds("${startingUp} | grep -q 'true,..false'", timeout=120)
          machine.fail("pgrep -x Xwayland")
    '';
}
