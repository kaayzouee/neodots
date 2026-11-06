# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Disposable River/KWM/Quickshell session integration test.
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

{ pkgs, home-manager }:

# No host hardware, personal modules, GDM or credentials are imported. The real
# compositor uses wlroots' headless backend and the real shell uses Qt software
# rendering; this checks session plumbing, not physical GPU or GDM selection.
pkgs.testers.runNixOSTest {
  name = "neodots-river-session";

  nodes.machine = { pkgs, ... }: {
    imports = [
      home-manager.nixosModules.home-manager
      ../modules/system/neodots.nix
      ../modules/desktop/river
    ];

    neodots = {
      username = "administrator";
      hostname = "river-test";
      desktop.river.user = "ci";
    };
    users.users.ci = {
      uid = 1000;
      initialPassword = "river-test-password";
    };
    users.groups = {
      networkmanager = { };
      libvirtd = { };
      uinput = { };
    };
    programs.fish = {
      enable = true;
      generateCompletions = false;
    };
    services.upower.enable = true;
    fonts.packages = [ pkgs.dejavu_fonts ];
    environment.systemPackages = [
      pkgs.foot
      pkgs.wlrctl
      pkgs.pamtester
    ];

    home-manager.useGlobalPkgs = true;
    home-manager.users.ci = {
      imports = [ ../modules/desktop/river/home.nix ];
      home.stateVersion = "26.11";
    };

    systemd.user.services.river-ci = {
      description = "Disposable headless River session";
      environment = {
        WLR_BACKENDS = "headless";
        WLR_HEADLESS_OUTPUTS = "1";
        WLR_RENDERER = "pixman";
        WLR_LIBINPUT_NO_DEVICES = "1";
        XDG_CURRENT_DESKTOP = "river";
        XDG_SESSION_DESKTOP = "river";
        XDG_SESSION_TYPE = "wayland";
        QT_QPA_PLATFORM = "wayland";
        QT_QUICK_BACKEND = "software";
      };
      serviceConfig = {
        ExecStart = "${pkgs.callPackage ../packages/river { }}/bin/river";
        # Preserve River's init helper so its exit trap can stop the session.
        KillMode = "process";
        TimeoutStopSec = 15;
      };
    };

    # The user manager launches Quickshell separately from the compositor. Qt's
    # backend setting must reach that manager too, not just River's own unit.
    systemd.user.settings.Manager.DefaultEnvironment =
      "QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software";
    virtualisation.memorySize = 2048;
  };

  testScript = ''
    import shlex

    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("home-manager-ci.service")
    machine.succeed("loginctl enable-linger ci")
    machine.wait_for_unit("user@1000.service")

    wayland = ""

    def user(command):
        environment = "export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; "
        if wayland:
            environment += "export WAYLAND_DISPLAY=" + shlex.quote(wayland) + "; "
        return "su - ci -s /bin/sh -c " + shlex.quote(environment + command)

    def pid(unit):
        return machine.succeed(user("systemctl --user show --property=MainPID --value " + unit)).strip()

    with subtest("real River starts KWM and the supervised Quickshell"):
        machine.succeed(user("systemctl --user start river-ci.service"))
        machine.wait_until_succeeds(user("systemctl --user is-active --quiet neodots-quickshell.service"), timeout=90)
        manager_environment = machine.succeed(user("systemctl --user show-environment"))
        wayland = next(line.split("=", 1)[1] for line in manager_environment.splitlines() if line.startswith("WAYLAND_DISPLAY="))
        machine.succeed("test -S /run/user/1000/" + shlex.quote(wayland))
        machine.wait_until_succeeds("pgrep -u ci -x kwm", timeout=90)
        machine.wait_until_succeeds(user("wlr-randr | grep HEADLESS"), timeout=90)
        # A stable process alone is insufficient: require QML to load both panels.
        machine.wait_until_succeeds(user("journalctl --user -u neodots-quickshell.service --no-pager | grep 'Configuration Loaded'"), timeout=90)
        kwm_pid = machine.succeed("pgrep -u ci -x kwm").strip()
        init_pid = machine.succeed("pgrep -u ci -f '[n]eodots-river-session'").strip()
        assert init_pid.isdecimal(), init_pid
        shell_pid = pid("neodots-quickshell.service")
        assert int(shell_pid) > 0

    with subtest("a real client is managed by the River session"):
        machine.succeed(user("systemd-run --user --unit=river-ci-client foot --app-id=river-ci-client sleep infinity"))
        machine.wait_until_succeeds(user("wlrctl toplevel list | grep river-ci-client"), timeout=90)
        client_pid = pid("river-ci-client.service")
        assert int(client_pid) > 0

    with subtest("Quickshell crash recovery preserves KWM and the client"):
        machine.succeed(user("systemctl --user kill --signal=KILL neodots-quickshell.service"))
        machine.wait_until_succeeds(user("test $(systemctl --user show --property=MainPID --value neodots-quickshell.service) -gt 0 && test $(systemctl --user show --property=MainPID --value neodots-quickshell.service) != " + shell_pid), timeout=60)
        machine.wait_until_succeeds(user("test $(journalctl --user -u neodots-quickshell.service --no-pager | grep -c 'Configuration Loaded') -ge 2"), timeout=60)
        machine.succeed(user("systemctl --user is-active --quiet neodots-quickshell.service"))
        assert machine.succeed("pgrep -u ci -x kwm").strip() == kwm_pid
        assert pid("river-ci-client.service") == client_pid
        machine.succeed(user("wlrctl toplevel list | grep river-ci-client"))

    with subtest("swaylock PAM rejects a wrong password and accepts the disposable password"):
        machine.succeed("test -f /etc/pam.d/swaylock")
        machine.fail("printf '%s\\n' wrong-password | pamtester swaylock ci authenticate")
        machine.succeed("printf '%s\\n' river-test-password | pamtester swaylock ci authenticate")

    with subtest("compositor shutdown stops the shell despite a lingering user manager"):
        machine.succeed(user("systemctl --user stop river-ci.service"))
        machine.wait_until_succeeds("test ! -e /proc/" + init_pid, timeout=30)
        machine.wait_until_succeeds(user("! systemctl --user is-active --quiet neodots-river-session.target"), timeout=30)
        machine.wait_until_succeeds(user("! systemctl --user is-active --quiet neodots-quickshell.service"), timeout=30)
        machine.wait_until_succeeds(user("! systemctl --user is-active --quiet river-ci-client.service"), timeout=30)
        machine.fail("pgrep -u ci -x kwm")
        machine.succeed("systemctl is-active --quiet user@1000.service")
  '';
}
