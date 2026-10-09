# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee

{ pkgs, ... }:

let
  programmingLanguages = with pkgs; [
    cargo
    go
    nodejs
    python313
    python313Packages.pynvim
    python313Packages.pip
    lua51Packages.lua
  ];

  editors = with pkgs; [
    neovim
    vim-full
    vscode
  ];

  cli = with pkgs; [
    unzip
    zip
    file-roller

    broot
    lsd
    tree

    ast-grep
    fd
    ripgrep

    gh
    git
    lazygit
    sops

    bottom
    btop

    curl
    wget

    tmux
    zellij

    alacritty
    fzf
    jq
    stow
    picom
    fishPlugins.bass
  ];

  systemNetworking = with pkgs; [
    gcc
    networkmanagerapplet
    brightnessctl
    wl-clipboard
    cliphist
  ];

  vpn = with pkgs; [
    proton-vpn
  ];

  multimedia = with pkgs; [
    imagemagick
    gimp
    cava
    spotify
    pdf4qt
    vesktop
  ];

  windowManagement = with pkgs; [
    dunst
    thunar
  ];

  themes = with pkgs; [
    adwaita-icon-theme
    fuchsia-cursor
  ];

  virtualization = with pkgs; [
    virt-manager
    virt-viewer
    swtpm
    wine
    flatpak
  ];

  ricing = with pkgs; [
    fastfetch
    btop
    cmatrix
  ];

  keyManagement = with pkgs; [
    pinentry-curses
    gnupg
  ];

  custom = [
    (pkgs.callPackage ../../packages/shg { })
    (pkgs.callPackage ../../packages/river { })
    (pkgs.callPackage ../../packages/kwm { })
  ];
in
{
  environment.systemPackages =
    programmingLanguages
    ++ editors
    ++ cli
    ++ systemNetworking
    ++ vpn
    ++ multimedia
    ++ windowManagement
    ++ themes
    ++ virtualization
    ++ ricing
    ++ keyManagement
    ++ custom;
}
