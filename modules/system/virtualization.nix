# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Libvirt, QEMU and virt-manager for running virtual machines on
#          this host.
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
  virtualisation.libvirtd = {
    enable = true;

    qemu.runAsRoot = false;

    qemu.verbatimConfig = ''
      seccomp_sandbox = 1
    '';

    onBoot = "ignore";
  };

  programs.virt-manager.enable = true;

  security.apparmor.enable = true;
}
