# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

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
