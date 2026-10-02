<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 kaayzouee -->
<!-- Author: https://github.com/kaayzouee -->

<h1 style="text-align:center;">Neodots — NixOS configuration</h1>

[![Stars](https://img.shields.io/github/stars/kaayzouee/neodots?style=for-the-badge&logo=macys&label=Stars&color=2d2d2d&labelColor=1a1a1a&logoColor=66ccff)](https://github.com/kaayzouee/neodots/stargazers)
[![Forks](https://img.shields.io/github/forks/kaayzouee/neodots?style=for-the-badge&logo=git&label=Forks&color=2d2d2d&labelColor=1a1a1a&logoColor=66ccff)](https://github.com/kaayzouee/neodots/network/members)
[![Issues](https://img.shields.io/github/issues/kaayzouee/neodots?style=for-the-badge&logo=gitbook&label=Issues&color=2d2d2d&labelColor=1a1a1a&logoColor=66ccff)](https://github.com/kaayzouee/neodots/issues)
[![License](https://img.shields.io/github/license/kaayzouee/neodots?style=for-the-badge&logo=nextdns&label=License&color=2d2d2d&labelColor=1a1a1a&logoColor=66ccff)](https://github.com/kaayzouee/neodots/blob/main/LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/kaayzouee/neodots?style=for-the-badge&logo=git&label=Last%20Commit&color=2d2d2d&labelColor=1a1a1a&logoColor=66ccff)](https://github.com/kaayzouee/neodots/commits)
[![Made with Nix](https://img.shields.io/badge/Made%20with-Nix-2d2d2d?style=for-the-badge&logo=nixos&logoColor=66ccff&labelColor=1a1a1a)](https://nixos.org/)

Neodots is a NixOS configuration built around flakes, Home Manager, and reusable Nix modules.

The repository is currently tailored to an x86_64 NixOS setup. Machine-specific files such as the generated hardware configuration are intentionally not tracked.

## Compatibility

- **x86_64 Linux**
- NixOS with flakes enabled

## Features

- Nix flakes
- Home Manager
- Reusable system and Home Manager modules
- Host configuration
- Package configuration
- Git-ignored machine-specific hardware configuration

## Current status

The repository is being reworked around a machine-aware installer so it can be used without manually editing user-specific paths.

The planned installer will handle:

- username and hostname
- hardware configuration
- impermanence and persistence
- passwordless-user validation
- wallpaper selection
- machine-specific configuration generation
- configuration validation before rebuilding

Wallpaper assets are planned to live in a separate repository so the Nix configuration does not depend on a specific wallpaper filename or the original `kay` home directory.

See [Issue #2](https://github.com/kaayzouee/neodots/issues/2) and [`docs/INSTALLER-PLAN.md`](docs/INSTALLER-PLAN.md) for the implementation plan.

## Installation

The installer is still under development. Until it is ready, the configuration can be installed manually on an existing NixOS system.

### Requirements

- git
- sudo
- NixOS with flakes enabled

### Manual installation

Clone the repository into a temporary directory, remove its Git metadata, then copy the configuration into `/etc/nixos`:

```bash
git clone https://github.com/kaayzouee/neodots.git /tmp/neodots
rm -rf /tmp/neodots/.git
sudo cp -a /tmp/neodots/. /etc/nixos/
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

### Hardware configuration

`hardware-configuration.nix` is machine-specific and is not tracked in the repository.

For an existing NixOS installation, keep the generated file at:

```text
/etc/nixos/hardware-configuration.nix
```

The host configuration imports that file when building the `nixos` configuration.

## Development roadmap

The main installer work is tracked in [Issue #2](https://github.com/kaayzouee/neodots/issues/2).

The roadmap covers:

1. Removing hard-coded user and wallpaper paths.
2. Integrating impermanence cleanly.
3. Creating a separate wallpaper repository and manifest.
4. Building a TUI installer.
5. Testing persistence, rebuild failures, and non-`kay` users.
6. Updating documentation and recovery procedures.

## Contributing

Changes should keep the configuration declarative and avoid introducing machine-specific paths into reusable modules.

When adding a machine-specific value, prefer making it explicit in generated host configuration or installer input instead of hard-coding it into a shared module.
