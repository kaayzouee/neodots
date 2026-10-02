# Neodots Installer Plan

Tracking issue: #2

## Objective

Build a machine-aware TUI installer for neodots that can configure impermanence, handle machine/user-specific state, and optionally install a wallpaper from a separate wallpaper repository.

The installer should assemble a working configuration rather than relying on hard-coded paths or manual file edits.

## Architecture

- [ ] Keep wallpaper assets outside neodots in `kaayzouee/neodots-wallpapers`.
- [ ] Keep neodots declarative and independent of a specific username.
- [ ] Move machine-specific values behind installer-generated configuration.
- [ ] Make wallpaper selection an installer concern.
- [ ] Make `~/Pictures` persistence compatible with impermanence.
- [ ] Remove assumptions tied specifically to the `kay` account.

## Phase 1 — Configuration cleanup

- [ ] Find every hard-coded username, home path, hostname, wallpaper path, and machine-specific value.
- [ ] Introduce configurable username and hostname.
- [ ] Replace `/home/kay` references with values derived from the configured user.
- [ ] Remove hard-coded wallpaper filenames/paths.
- [ ] Make desktop wallpaper configuration consume a configurable path or wallpaper directory.
- [ ] Separate machine configuration from reusable modules.
- [ ] Ensure SOPS configuration does not assume the installer's personal identity.

## Phase 2 — Impermanence

- [ ] Integrate the selected impermanence fork.
- [ ] Define the persistent filesystem contract.
- [ ] Make persistent home data derive from the configured username.
- [ ] Persist `Pictures` or selected wallpaper assets.
- [ ] Verify wallpaper availability after a root filesystem reset.
- [ ] Verify the system remains bootable and usable after the reset lifecycle.
- [ ] Document required `/persist` layout and prerequisites.

## Phase 3 — Wallpaper repository

- [ ] Create `kaayzouee/neodots-wallpapers`.
- [ ] Organize assets by category.
- [ ] Add a machine-readable manifest.
- [ ] Give every asset a stable ID.
- [ ] Record licensing/attribution information.
- [ ] Define how the installer pins or identifies the wallpaper repository revision.
- [ ] Define a download mechanism that does not require cloning the whole wallpaper repository.

Suggested manifest shape:

```text
wallpaper ID
category
filename
download URL/path
license
attribution
```

## Phase 4 — Installer / TUI

- [ ] Detect that the machine is running NixOS.
- [ ] Detect the target username and home directory.
- [ ] Detect/preserve `hardware-configuration.nix`.
- [ ] Detect the persistence setup.
- [ ] Validate required permissions.
- [ ] Explicitly handle passwordless users.
- [ ] Show a pre-install summary.
- [ ] Let the user choose whether impermanence is enabled.
- [ ] Let the user choose a wallpaper.
- [ ] Support no wallpaper, a specific wallpaper, and random selection.
- [ ] Download only the selected asset.
- [ ] Generate machine-specific configuration.
- [ ] Validate the generated flake before replacing `/etc/nixos`.
- [ ] Run `nixos-rebuild switch` only after validation succeeds.
- [ ] Keep the previous configuration recoverable if installation fails.
- [ ] Report actionable errors instead of leaving a partially configured system.

Target flow:

```text
Preflight
  -> User
  -> Hostname
  -> Hardware
  -> Impermanence
  -> Persistence
  -> Wallpaper
  -> Review
  -> Generate
  -> Validate
  -> Rebuild
  -> Verify
```

## Phase 5 — Testing

- [ ] Fresh NixOS installation.
- [ ] Existing neodots installation.
- [ ] Username other than `kay`.
- [ ] Passwordless user.
- [ ] Impermanence disabled.
- [ ] Impermanence enabled.
- [ ] No wallpaper.
- [ ] Specific wallpaper.
- [ ] Random wallpaper.
- [ ] Wallpaper repository unavailable.
- [ ] Missing/invalid `/persist`.
- [ ] Failed configuration validation.
- [ ] Failed rebuild.
- [ ] Reboot after installation.
- [ ] Root filesystem reset followed by reboot.
- [ ] Confirm wallpaper remains available through persistence.
- [ ] Confirm generated configuration contains no stale `kay` paths.

## Phase 6 — Documentation

- [ ] Remove stale `nix-dotfiles-2` references from README.
- [ ] Document the installer.
- [ ] Document prerequisites.
- [ ] Document impermanence and persistence behavior.
- [ ] Document wallpaper selection.
- [ ] Document the wallpaper repository.
- [ ] Document how to add wallpapers.
- [ ] Document recovery if installation/rebuild fails.

## Definition of done

A new user can run the neodots installer and:

1. Select/configure their username and hostname.
2. Preserve or generate the correct hardware configuration.
3. Enable or disable impermanence.
4. Configure the persistence location.
5. Select no wallpaper, a specific wallpaper, or a random wallpaper.
6. Finish with a validated NixOS configuration.
7. Rebuild successfully without manually editing paths.
8. Reboot successfully.
9. Retain the selected wallpaper through the configured persistence lifecycle.

No part of the resulting configuration should require the username `kay` or a hard-coded personal wallpaper path.
