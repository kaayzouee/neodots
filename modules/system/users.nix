{ pkgs, ... }:

{
  programs.fish.enable = true;

  users.users.kay = {
    isNormalUser = true;
    description = "kay";
    shell = pkgs.fish;
    extraGroups = [
	"wheel"
	"networkmanager"
	"libvirtd" 
    ];
  };

  users.users.guest = {
    isNormalUser = true;
    description = "Friend Guest";
    hashedPassword = "";
    shell = "/run/current-system/sw/bin/bash";
    home = "/home/guest";
    createHome = true;
  };

  systemd.tmpfiles.rules = [
    "D! /home/guest 0700 guest users" # Wipes and recreates /home/guest on boot
  ];
}
