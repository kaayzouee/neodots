# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Isolated NetworkManager DHCP and DNS integration test.
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
pkgs.testers.runNixOSTest {
  name = "neodots-dns-dhcp";
  defaults = { lib, ... }: {
    # Remove QEMU's user-mode NIC entirely: VLAN 1 is a private test-driver switch.
    virtualisation.qemu.networkingOptions = lib.mkForce [ ];
    virtualisation.vlans = [ 1 ];
  };
  nodes = {
    server = { lib, ... }: {
      networking.firewall.enable = false;
      networking.useDHCP = false;
      networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
        {
          address = "198.51.100.1";
          prefixLength = 24;
        }
        {
          address = "198.51.100.2";
          prefixLength = 24;
        }
      ];
      services.dnsmasq = {
        enable = true;
        settings = {
          port = 0;
          interface = "eth1";
          bind-interfaces = true;
          dhcp-range = "198.51.100.100,198.51.100.150,255.255.255.0,1h";
          dhcp-option = [ "option:dns-server,198.51.100.1" ];
        };
      };
      systemd.services.fixture-dhcp-dns = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 ${./dns/fixtures/server.py} --bind 198.51.100.1 --port 53 --answer 192.0.2.41 --mode healthy --duration 600 --log /run/dhcp-dns.jsonl";
      };
      systemd.services.fixture-static-dns = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 ${./dns/fixtures/server.py} --bind 198.51.100.2 --port 53 --answer 192.0.2.42 --mode healthy --duration 600 --log /run/static-dns.jsonl";
      };
    };
    resolved = { lib, ... }: {
      networking.networkmanager.enable = true;
      services.resolved.enable = true;
      networking.useDHCP = false;
      networking.interfaces = lib.mkForce { };
      networking.networkmanager.ensureProfiles.profiles.test = {
        connection = {
          id = "test";
          type = "ethernet";
          interface-name = "eth1";
        };
        ipv4.method = "auto";
        ipv6.method = "disabled";
      };
      environment.systemPackages = [ pkgs.python3 ];
    };
    reconstructed = { lib, ... }: {
      networking.networkmanager.enable = true;
      networking.nameservers = [
        "1.1.1.1"
        "8.8.8.8"
      ];
      networking.useDHCP = false;
      networking.interfaces = lib.mkForce { };
      networking.networkmanager.ensureProfiles.profiles.test = {
        connection = {
          id = "test";
          type = "ethernet";
          interface-name = "eth1";
        };
        ipv4.method = "auto";
        ipv6.method = "disabled";
      };
    };
    baseline = { lib, ... }: {
      networking.networkmanager.enable = true;
      networking.useDHCP = false;
      networking.interfaces = lib.mkForce { };
      networking.networkmanager.ensureProfiles.profiles.test = {
        connection = {
          id = "test";
          type = "ethernet";
          interface-name = "eth1";
        };
        ipv4.method = "auto";
        ipv6.method = "disabled";
      };
      environment.systemPackages = [
        pkgs.bind.dnsutils
        pkgs.curl
      ];
    };
    client = { lib, ... }: {
      imports = [ ../modules/system/networking.nix ];
      # Preserve production DNS ownership but use a private synthetic endpoint.
      environment.etc."resolv.conf".text = lib.mkForce "nameserver 198.51.100.2\n";
      networking.interfaces = lib.mkForce { };
      networking.networkmanager.ensureProfiles.profiles.test = {
        connection = {
          id = "test";
          type = "ethernet";
          interface-name = "eth1";
        };
        ipv4.method = "auto";
        ipv6.method = "disabled";
      };
      environment.systemPackages = [ pkgs.bind.dnsutils ];
    };
  };
  testScript = ''
    import json
    server.start()
    server.wait_for_unit("dnsmasq.service")
    server.wait_for_unit("fixture-dhcp-dns.service")
    server.wait_for_unit("fixture-static-dns.service")
    client.start()
    client.wait_for_unit("NetworkManager.service")
    client.wait_until_succeeds("ip -4 addr show dev eth1 | grep -q '198.51.100.'")
    client.wait_until_succeeds("nmcli -g IP4.DNS device show eth1 | grep -qx 198.51.100.1")
    client.succeed("test \"$(cat /etc/resolv.conf)\" = 'nameserver 198.51.100.2'")
    client.succeed("test \"$(dig +short @198.51.100.1 dhcp.fixture.test A)\" = 192.0.2.41")
    client.succeed("getent ahostsv4 static.fixture.test | grep -q 192.0.2.42")
    server.succeed("grep -q 'static.fixture.test' /run/static-dns.jsonl")
    server.fail("grep -q 'static.fixture.test' /run/dhcp-dns.jsonl")
    baseline.start()
    baseline.wait_for_unit("NetworkManager.service")
    baseline.wait_until_succeeds("nmcli -g IP4.DNS device show eth1 | grep -qx 198.51.100.1")
    baseline.wait_until_succeeds("grep -q '^nameserver 198.51.100.1' /etc/resolv.conf")
    baseline.succeed("getent ahostsv4 baseline.fixture.test | grep -q 192.0.2.41")
    server.succeed("grep -q 'baseline.fixture.test' /run/dhcp-dns.jsonl")
    reconstructed.start()
    reconstructed.wait_for_unit("NetworkManager.service")
    reconstructed.wait_until_succeeds("nmcli -g IP4.DNS device show eth1 | grep -qx 198.51.100.1")
    baseline.succeed("grep -qx 'options edns0' /etc/resolv.conf")
    resolv = reconstructed.succeed("cat /etc/resolv.conf")
    print("reconstructed resolv.conf:", resolv)
    assert [line for line in resolv.splitlines() if line.startswith("nameserver ")] == ["nameserver 198.51.100.1", "nameserver 1.1.1.1", "nameserver 8.8.8.8"]
    reconstructed.succeed("getent ahostsv4 reconstruction.fixture.test | grep -q 192.0.2.41")
    rows = [json.loads(line) for line in server.succeed("cat /run/dhcp-dns.jsonl").splitlines()]
    rec_ip = reconstructed.succeed("ip -4 -o addr show dev eth1 | awk '{split($4,a,\"/\"); print a[1]}'").strip()
    assert any(r.get("name") == "reconstruction.fixture.test" and r.get("source_ip") == rec_ip and r.get("edns") and r.get("qtype") == 1 for r in rows), rows
    resolved.start()
    resolved.wait_for_unit("systemd-resolved.service")
    resolved.wait_for_unit("NetworkManager.service")
    resolved.wait_until_succeeds("nmcli -g IP4.DNS device show eth1 | grep -qx 198.51.100.1")
    resolved.succeed("grep -q '127.0.0.53' /etc/resolv.conf")
    resolved.wait_until_succeeds("python3 -c 'import socket; assert any(x[4][0] == \"192.0.2.41\" for x in socket.getaddrinfo(\"resolved.fixture.test\", 80))'")
    server.succeed("grep -q 'resolved.fixture.test' /run/dhcp-dns.jsonl")
    # Configure only the test guests; there is no route to the host or Internet.
    server.succeed("ip -6 addr add 2001:db8:50::1/64 dev eth1 nodad")
    baseline.succeed("sysctl -w net.ipv6.conf.eth1.disable_ipv6=0; ip -6 addr add 2001:db8:50::2/64 dev eth1 nodad")
    server.succeed("systemd-run --unit=fixture-ipv6 ${pkgs.python3}/bin/python3 ${./dns/fixtures/server.py} --bind 2001:db8:50::1 --port 5353 --duration 600 --log /run/ipv6.jsonl")
    server.wait_for_unit("fixture-ipv6.service")
    baseline.wait_until_succeeds("dig -6 +time=1 +tries=1 +short @2001:db8:50::1 -p 5353 ipv6.fixture.test AAAA | grep -qx '2001:db8::42'")
    baseline.succeed("dig -6 +time=1 +tries=1 +tcp +short @2001:db8:50::1 -p 5353 ipv6-tcp.fixture.test A | grep -qx '192.0.2.42'")
    ipv6_rows = [json.loads(line) for line in server.succeed("cat /run/ipv6.jsonl").splitlines()]
    assert any(r.get("name") == "ipv6.fixture.test" and r.get("source_ip") == "2001:db8:50::2" and r.get("protocol") == "udp" and r.get("qtype") == 28 for r in ipv6_rows), ipv6_rows
    assert any(r.get("name") == "ipv6-tcp.fixture.test" and r.get("source_ip") == "2001:db8:50::2" and r.get("protocol") == "tcp" for r in ipv6_rows), ipv6_rows
    # Switch only the synthetic DHCP resolver to EDNS-over-UDP loss.
    server.succeed("systemctl stop fixture-dhcp-dns")
    server.succeed("systemd-run --unit=broken-dns ${pkgs.python3}/bin/python3 ${./dns/fixtures/server.py} --bind 198.51.100.1 --port 53 --answer 192.0.2.41 --mode edns-drop --log /run/broken.jsonl")
    server.wait_for_unit("broken-dns.service")
    baseline.wait_until_succeeds("dig +short +noedns @198.51.100.1 ready.fixture.test A | grep -qx 192.0.2.41")
    baseline.fail("dig +time=1 +tries=1 +edns=0 @198.51.100.1 edns.fixture.test A")
    baseline.fail("dig +time=1 +tries=1 +nocookie +edns=0 @198.51.100.1 nocookie.fixture.test A")
    baseline.succeed("test \"$(dig +short +noedns @198.51.100.1 plain.fixture.test A)\" = 192.0.2.41")
    baseline.succeed("test \"$(dig +short +tcp +edns=0 @198.51.100.1 tcp.fixture.test A)\" = 192.0.2.41")
    resolved_status, resolved_output = resolved.execute("timeout 45s resolvectl query --type=A resolved-broken.fixture.test")
    print("resolved under EDNS-drop:", resolved_status, resolved_output)
    assert resolved_status != 124, (resolved_status, resolved_output)
    resolved_rows = [json.loads(line) for line in server.succeed("cat /run/broken.jsonl").splitlines()]
    resolved_ip = resolved.succeed("ip -4 -o addr show dev eth1 | awk '{split($4,a,\"/\"); print a[1]}'").strip()
    assert any(r.get("name") == "resolved-broken.fixture.test" and r.get("source_ip") == resolved_ip for r in resolved_rows), resolved_rows
    print("resolved EDNS-drop log:", [r for r in resolved_rows if r.get("name") == "resolved-broken.fixture.test"])
    status, output = baseline.execute("timeout 25s getent ahostsv4 nss.fixture.test")
    assert status not in (0, 124), (status, output)
    rows = [json.loads(line) for line in server.succeed("cat /run/broken.jsonl").splitlines()]
    print("EDNS-drop wire log:", rows)
    assert any(r.get("name") == "nocookie.fixture.test" and r.get("edns") and r.get("cookie") is None and r.get("dropped") for r in rows), rows
    baseline_ip = baseline.succeed("ip -4 -o addr show dev eth1 | awk '{split($4,a,\"/\"); print a[1]}'").strip()
    assert any(r.get("name") == "nss.fixture.test" and r.get("source_ip") == baseline_ip and r.get("qtype") == 1 and r.get("edns") and r.get("dropped") for r in rows), rows
    client.succeed("getent ahostsv4 static-broken.fixture.test | grep -q 192.0.2.42")
    server.succeed("grep -q 'static-broken.fixture.test' /run/static-dns.jsonl")
    # DNS outage does not imply IP connectivity loss.
    server.succeed("systemctl stop broken-dns")
    server.succeed("systemd-run --unit=fixture-http ${pkgs.python3}/bin/python3 -m http.server 8080 --bind 198.51.100.1 --directory /run")
    server.wait_for_unit("fixture-http.service")
    baseline.fail("dig +time=1 +tries=1 @198.51.100.1 down.fixture.test A")
    status, output = baseline.execute("timeout 25s getent ahostsv4 outage.fixture.test")
    assert status not in (0, 124), (status, output)
    baseline.fail("curl --noproxy '*' --max-time 3 -fsS http://outage-http.fixture.test:8080/ >/dev/null")
    client.succeed("getent ahostsv4 static-outage.fixture.test | grep -q 192.0.2.42")
    baseline.wait_until_succeeds("curl --noproxy '*' --max-time 2 -fsS http://198.51.100.1:8080/ >/dev/null")
    print("PASS: isolated DHCP/static and DHCP-managed DNS; EDNS loss breaks NSS, plain UDP and TCP succeed; outage leaves numeric HTTP working")
  '';
}
