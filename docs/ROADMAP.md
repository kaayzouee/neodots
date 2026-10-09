# Neodots Package Structure Roadmap

## Goal

Make `packages/` behave like a small, repository-local nixpkgs tree:

- `packages/<name>/default.nix` defines one custom derivation.
- Generated dependency expressions belong beside the derivation they serve.
- System package selection belongs in NixOS modules, not in `packages/`.
- Home Manager package selection stays with the Home Manager configuration that owns it.
- Avoid separate `packages/home` and `packages/system` trees unless a real need appears.

## Phase 1 — Package taxonomy

- [x] Decide that `packages/` contains derivations, not installation lists.
- [x] Keep package selection in modules.
- [x] Keep Home Manager-only package selection in Home Manager modules/configuration.

## Phase 2 — Migrate custom derivations

The custom packages now use a nixpkgs-style layout:

```
packages/
├── river/
│   ├── default.nix
│   └── build.zig.zon.nix
├── kwm/
│   ├── default.nix
│   └── kwm-build.zig.zon.nix
├── fcitx5-lotus/
│   └── default.nix
└── shg/
    ├── default.nix
    └── shg-deps.nix
```

- [x] Remove the old flat derivation files after references were updated.
- [x] Preserve the existing package versions, source hashes, and build flags.

## Phase 3 — Move package selection into modules

Created:

```
modules/system/packages.nix
```

- [x] Move the existing system-wide package selections there without intentionally changing the selected package set.
- [x] Keep CLI grouping inside the module for readability.
- [x] Keep custom derivations referenced from the package module.
- [x] Remove the old `PKG-*.nix` and `packages/cli-tools/PKG-*.nix` selection files.

## Phase 4 — Configuration cleanup

- [x] Remove unused package-selection files.
- [x] Keep Home Manager-only selections out of the system package module.
- [x] Keep the NixOS host module focused on composing modules and host-specific settings.

## Phase 5 — Verification

Verified on the final branch head:

- [x] Nix formatting passed: Format workflow run #52.
- [x] `nix flake check --all-systems --no-build` passed as part of Evaluate workflow run #51.
- [x] NixOS system derivation evaluation passed in Evaluate workflow run #51.
- [x] NixOS system build passed: NixOS workflow run #60.
- [x] The NixOS build closure included River 0.4.8, KWM 0.3.0, Fcitx5 Lotus 4.0.1, and shg 0.2.6.
- [x] The tracked `hardware-configuration.nix` remained byte-for-byte unchanged during the package-structure migration.

## Future, only when needed

Consider exporting custom packages through flake outputs (for example `packages.<system>.river`) if they become useful outside the NixOS configuration. Do not add an overlay or a package framework before there is a concrete consumer.
