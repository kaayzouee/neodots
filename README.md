<h1 style="text-align:center;"> NixOS dotfiles</h1>

[![Stars](https://img.shields.io/github/stars/kaayzouee/neodots?style=for-the-badge&logo=macys&label=Stars&color=2d2d2d&labelColor=1a1a1a&logoColor=66ccff)](https://github.com/kaayzouee/neodots/stargazers)
[![Forks](https://img.shields.io/github/forks/kaayzouee/neodots?style=for-the-badge&logo=git&label=Forks&color=2d2d2d&labelColor=1a1a1a&logoColor=66ccff)](https://github.com/kaayzouee/neodots/network/members)
[![Issues](https://img.shields.io/github/issues/kaayzouee/neodots?style=for-the-badge&logo=gitbook&label=Issues&color=2d2d2d&labelColor=1a1a1a&logoColor=66ccff)](https://github.com/kaayzouee/neodots/issues)
[![License](https://img.shields.io/github/license/kaayzouee/neodots?style=for-the-badge&logo=nextdns&label=License&color=2d2d2d&labelColor=1a1a1a&logoColor=66ccff)](https://github.com/kaayzouee/neodots/blob/main/LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/kaayzouee/neodots?style=for-the-badge&logo=git&label=Last%20Commit&color=2d2d2d&labelColor=1a1a1a&logoColor=66ccff)](https://github.com/kaayzouee/neodots/commits)
[![Made with Nix](https://img.shields.io/badge/Made%20with-Nix-2d2d2d?style=for-the-badge&logo=nixos&logoColor=66ccff&labelColor=1a1a1a)](https://nixos.org/)

# Compatibility
- **x86_64 only!**

##  Updates
- Improved KVM config significantly
- Better wifi speed yay
- Catppuccin theme

## Features
- Flake
- Home manager
- Modules
- Pack
- Host
- `.gitignore` for hardware + nix config file

## To build
### Requirements:
- git
- sudo
- zip / unzip / libzip (if using the alternative way)

### Recommended:
- Using build script below.
> **Why?** Because git doesn't play nice with sudo. Unless you setup your
git account in root, I highly recommend deleting `.git` so you can actua-
lly build the file

- If not, you can setup git for your root.

### Install script:
```bash
git clone https://github.com/kaayzouee/nix-dotfiles-2.git /tmp/nix-dotfiles-2
rm -rf /tmp/nix-dotfiles-2/.git
sudo cp -a /tmp/nix-dotfiles-2/. /etc/nixos/
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```
