# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Systemd-boot loader, bounded generation list and kernel selection.
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
  config,
  lib,
  pkgs,
  ...
}:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Bounded because the ESP is shared with Windows. See docs/comments/boot.txt.
  boot.loader.systemd-boot.configurationLimit = config.neodots.boot.configurationLimit;

  # Disabled: the guest account is passwordless. See docs/comments/boot.txt.
  boot.loader.systemd-boot.editor = false;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Laptop-specific (ASUS WMI hotkeys); pointless inside a VM.
  boot.kernelModules = lib.optional (!config.neodots.vm.enable) "asus-nb-wmi";
}
