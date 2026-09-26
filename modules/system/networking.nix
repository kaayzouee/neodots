#{
#  networking.networkmanager.enable = true;
#  networking.networkmanager.dns = "none";

#  networking.resolvconf.enable = false;
#  services.resolved.enable = false;

#  environment.etc."resolv.conf".text = ''
#    nameserver 1.1.1.1
#    nameserver 8.8.8.8
#  '';

#  networking.firewall.enable = true;
#}

# modules/system/networking.nix
{ pkgs, ... }:

{
  # ─── Stubby: DNS-over-TLS resolver on localhost:53 ───────────────────────
  services.stubby = {
    enable = true;

    settings = {
      resolution_type = "GETDNS_RESOLUTION_STUB";
      dns_transport_list = [ "GETDNS_TRANSPORT_TLS" ];

      listen_addresses = [
        "127.0.0.1@53"
        "0::1@53"
      ];

      upstream_recursive_servers = [
        {
          address_data = "1.1.1.1";
          tls_auth_name = "cloudflare-dns.com";
        }
        {
          address_data = "1.0.0.1";
          tls_auth_name = "cloudflare-dns.com";
        }
        {
          address_data = "8.8.8.8";
          tls_auth_name = "dns.google";
        }
        {
          address_data = "8.8.4.4";
          tls_auth_name = "dns.google";
        }
      ];
    };
  };

  # ─── NetworkManager ──────────────────────────────────────────────────────
  networking.networkmanager = {
    enable = true;
    dns = "none";              # stubby owns /etc/resolv.conf, not NM
    wifi.powersave = false;
  };

  # NetworkManager handles DHCP for wlp98s0 itself; do NOT declare it here,
  # or NixOS will also spawn dhcpcd for the interface and the two will fight
  # over the same UDP sockets (dhcp6_openudp: Address already in use).
  #
  # REMOVED: networking.interfaces."wlp98s0".useDHCP = true;

  # ─── Disable every other DHCP client ─────────────────────────────────────
  networking.useDHCP = false;
  networking.dhcpcd.enable = false;

  # ─── resolv.conf: hand-written, points at stubby ─────────────────────────
  networking.resolvconf.enable = false;
  services.resolved.enable = false;

  environment.etc."resolv.conf".text = ''
    nameserver 127.0.0.1
  '';

  networking.firewall.enable = true;

  # ─── MediaTek MT7921e Wi-Fi quirk ────────────────────────────────────────
  boot.extraModprobeConfig = ''
    options mt7921e disable_aspm=1
  '';
}
