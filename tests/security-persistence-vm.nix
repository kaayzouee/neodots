# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Isolated PAM, Home Manager SOPS and persistent-key reboot tests.
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

{
  pkgs,
  home-manager,
  sops-nix,
  impermanence,
}:
pkgs.testers.runNixOSTest {
  name = "neodots-security-persistence";
  nodes.machine = { config, lib, ... }: {
    imports = [
      ../modules/system/neodots.nix
      ../modules/system/users.nix
      ../modules/system/persistence.nix
      home-manager.nixosModules.home-manager
      impermanence.nixosModules.impermanence
    ];
    neodots = {
      username = "tester";
      hostname = "security-test";
      personal.enable = true;
      persistence.enable = true;
    };
    # Keep runtime nix-env derivations with the VM's persistent Nix DB on reboot.
    # The test driver's tmpfs store upper layer would otherwise disappear.
    virtualisation.writableStoreUseTmpfs = false;
    virtualisation.emptyDiskImages = [ 512 ];
    virtualisation.fileSystems."/persist" = {
      device = "/dev/vdb";
      fsType = "ext4";
      autoFormat = true;
      neededForBoot = true;
    };
    programs.fish.generateCompletions = false;
    users.users.tester.uid = 1000;
    users.users.guest.uid = 1001;
    security.pam.services.gdm-password.allowNullPassword = true;
    environment.systemPackages = [
      pkgs.age
      pkgs.sops
      pkgs.pamtester
      pkgs.python3
    ];
    home-manager = {
      useGlobalPkgs = true;
      users.tester = { config, ... }: {
        imports = [
          sops-nix.homeManagerModules.sops
          ../modules/personal/git.nix
        ];
        home = {
          username = "tester";
          homeDirectory = "/home/tester";
          stateVersion = "26.11";
        };
        sops = {
          defaultSopsFile = lib.mkForce "/var/lib/synthetic-secrets.json";
          defaultSopsFormat = "json";
          validateSopsFiles = false;
          age = {
            keyFile = "/home/tester/.config/sops/age/keys.txt";
            generateKey = false;
          };
          log = [ ];
        };
        systemd.user.services.sops-nix.Service.ExecStartPre =
          let
            checker = pkgs.writeShellApplication {
              name = "check-sops-age-key";
              runtimeInputs = [ pkgs.coreutils ];
              text = builtins.readFile ../modules/personal/check-age-key.sh;
            };
          in
          "${checker}/bin/check-sops-age-key ${config.sops.age.keyFile}";
      };
    };
    system.stateVersion = "26.11";
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("home-manager-tester.service")
    machine.succeed("mountpoint -q /home/tester/.config/sops/age")
    machine.succeed("test $(stat -c %a /home/tester/.config/sops/age) = 700")
    machine.succeed("test $(stat -c %U /home/tester/.config/sops/age) = tester")
    machine.succeed("pamtester gdm-password guest authenticate acct_mgmt </dev/null")
    machine.fail("runuser -u guest -- sudo -n true")
    machine.fail("runuser -u guest -- test -r /home/tester")
    machine.fail("runuser -u tester -- sudo -n true")

    # Everything below is generated inside the disposable guest; no host keys.
    machine.succeed("install -d -m 700 /run/test-backup; runuser -u tester -- age-keygen -o /home/tester/.config/sops/age/keys.txt >/dev/null 2>&1")
    machine.succeed("cp /home/tester/.config/sops/age/keys.txt /run/test-backup/key; chmod 600 /run/test-backup/key")
    machine.succeed("python3 - <<'PY'\nimport json, secrets, subprocess\nfrom pathlib import Path\nsentinel = secrets.token_hex(32)\nPath('/run/sentinel').write_text(sentinel)\nPath('/run/sentinel').chmod(0o600)\npublic = subprocess.check_output(['age-keygen', '-y', '/home/tester/.config/sops/age/keys.txt'], text=True).strip()\npayload = json.dumps({'git': dict.fromkeys(['name','email','smtp-user','smtp-pass','signingkey'], sentinel)})\nr = subprocess.run(['sops','encrypt','--age',public,'--input-type','json','--output-type','json','/dev/stdin'],input=payload.encode(),capture_output=True)\nassert r.returncode == 0, 'synthetic encryption failed'\nPath('/var/lib/synthetic-secrets.json').write_bytes(r.stdout)\nPath('/var/lib/synthetic-secrets.json').chmod(0o644)\n# The password is runtime-generated, never a test log or process argument.\npassword = secrets.token_urlsafe(24)\nPath('/run/test-password').write_text(password + '\\n')\nPath('/run/test-password').chmod(0o600)\nr = subprocess.run(['chpasswd'],input=('tester:' + password + '\\n').encode(),capture_output=True)\nassert r.returncode == 0, 'synthetic password setup failed'\nPY")
    machine.succeed("pamtester sudo tester authenticate </run/test-password >/dev/null 2>&1")
    machine.succeed("loginctl enable-linger tester")
    machine.wait_for_unit("user@1000.service")
    userctl = "runuser -u tester -- env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus systemctl --user "
    machine.succeed(userctl + "restart sops-nix.service")
    machine.succeed("test $(stat -Lc %a /home/tester/.config/sops-nix/secrets/rendered/git-identity.conf) = 400")
    machine.succeed("python3 - <<'PY'\nfrom pathlib import Path\ns = Path('/run/sentinel').read_bytes()\nrendered = Path('/home/tester/.config/sops-nix/secrets/rendered/git-identity.conf')\nassert s in rendered.read_bytes(), 'runtime template missing synthetic value'\n# Check actual evaluated HM artifacts and derivations without printing content.\nfor p in Path('/nix/store').iterdir():\n if p.is_dir() and (p.name.endswith('-home-manager-files') or p.name.endswith('-home-manager-generation')):\n  for q in p.rglob('*'):\n   if q.is_file():\n    assert s not in q.read_bytes(), 'plaintext in generated Home Manager artifact'\n if p.is_file() and p.suffix == '.drv':\n  assert s not in p.read_bytes(), 'plaintext in evaluated derivation'\nPY")
    machine.fail("runuser -u guest -- test -r /home/tester/.config/sops-nix/secrets/rendered/git-identity.conf")
    machine.succeed("sha256sum /var/lib/synthetic-secrets.json >/run/cipher-before")
    machine.succeed("rm -- /home/tester/.config/sops/age/keys.txt")
    machine.fail(userctl + "restart sops-nix.service")
    machine.succeed("test ! -e /home/tester/.config/sops/age/keys.txt")
    machine.succeed("install -m 600 -o tester -g users /run/test-backup/key /home/tester/.config/sops/age/keys.txt")
    machine.succeed(userctl + "restart sops-nix.service")
    machine.succeed("sha256sum -c /run/cipher-before >/dev/null")

    # Test bind-mount ordering and survival across a real reboot. Root is not reset.
    machine.shutdown()
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("home-manager-tester.service")
    machine.wait_for_unit("user@1000.service")
    machine.succeed("mountpoint -q /home/tester/.config/sops/age")
    machine.succeed("test $(stat -Lc %a /home/tester/.config/sops/age/keys.txt) = 600")
    machine.succeed(userctl + "restart sops-nix.service")
    machine.succeed("test $(stat -Lc %a /home/tester/.config/sops-nix/secrets/rendered/git-identity.conf) = 400")
    print("PASS: guest/PAM isolation, runtime SOPS, key loss/restore, store boundary and persistent-key reboot")
  '';
}
