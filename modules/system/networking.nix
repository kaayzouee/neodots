# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - NetworkManager with a local DNS-over-TLS resolver (stubby) and
#          firewall.
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


{ pkgs, ... }:

{
  networking.networkmanager = {
    enable = true;
    dns = "none";
    wifi.powersave = false;
  };

  networking.useDHCP = false;
  networking.dhcpcd.enable = false;

  networking.resolvconf.enable = false;
  services.resolved.enable = false;

  # Restore the DNS configuration that previously worked.
  services.stubby.enable = false;

  environment.etc."resolv.conf".text = ''
    nameserver 1.1.1.1
    nameserver 8.8.8.8
  '';

  networking.firewall.enable = true;

  boot.extraModprobeConfig = ''
    options mt7921e disable_aspm=1
  '';
}
