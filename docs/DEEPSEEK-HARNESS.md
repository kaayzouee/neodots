<!--
SPDX-License-Identifier: GPL-3.0-only

Neodots - Deepseek Harness setup documentation.

Copyright (C) 2026 kaayzouee
Author: https://github.com/kaayzouee

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, version 3 of the License.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>.
-->
# DeepSeek Harness + ChatGPT SIWC

The primary Home Manager user receives `pkgs.deepseek-harness` from the
already-pinned `nixpkgs` flake input. The package is currently DSH
`0.2.1-rc.3` at the locked nixpkgs revision. Neither `river` nor
`guest` receives the package or the SIWC plugin.

The `neodots-dsh-plugins` user service provisions five compatible pinned DSH plugins
into the `web` profile when their installed version is missing or different. The installer uses the DSH plugin manager,
disables npm install scripts, and checks the resulting package version. It
runs independently of the NixOS rebuild so a network outage cannot fail a
system activation.

To provision it again or inspect its failure:

```sh
systemctl --user start neodots-dsh-plugins.service
systemctl --user status neodots-dsh-plugins.service
journalctl --user -u neodots-dsh-plugins.service
```

Start the app with `dsh --profile web`, enable the SIWC bundle if the plugin manager
requires it, and authorize your ChatGPT account through the official OAuth
flow. Do not store ChatGPT tokens or DSH profile state in Git.

## Reproducibility boundary

- **Nix package:** reproducible, because `flake.lock` pins nixpkgs, the
  DSH source and its pnpm dependency hashes are defined by the nixpkgs
  derivation.
- **SIWC version:** exactly pinned to `0.9.7`, with a startup check; it
  will not silently switch to npm's `latest` tag.
- **SIWC dependency graph:** **not yet fully reproducible**. The DSH plugin
  manager mutates the Web profile and writes a profile-local pnpm lockfile.
  Because that lockfile and the npm tarball's integrity hash are not tracked
  by this repository, reinstalling a clean profile can select different
  transitive dependencies. Full Nix reproducibility requires packaging the
  plugin as a fixed-output Nix derivation with a verified upstream archive
  hash and an independently locked npm dependency closure, then loading that
  immutable build into the DSH profile.

The plugin itself permits independent/background calls by default. Review
its settings, restrict authorization as appropriate, and never share a DSH
profile containing personal ChatGPT credentials with other users.

## Pinned plugin inventory

| Name | Pin |
| --- | --- |
| dsh-plugin-chatgpt-siwc | npm 0.9.7 |
| @wenaixi/dsh-ponytail | npm 5.6.2 |
| dsh-ghidra | npm 0.11.4 |
| dsh-nix-dev-shell | running-grass/dsh-nix-dev-shell at `90d39a724613d151838faac7972e3a06693df56a` |
| @dsh-lsp-packs/dsh-lsp-java | **Quarantined: not provisioned.** CI still monitors commit `258bb6409c504fa1eed20b6f70d13009522ca0ce`. |
| dsh-github-ci | npm 1.0.0 |

The Java LSP package declares an upstream DSH compatibility range below
`0.2.0`. It **has not been validated** with the nixpkgs DSH
`0.2.1-rc.3` package. Its build may require an allowed Git dependency
prepare script; the installer deliberately uses `--ignore-scripts` and
does not grant build-script permission automatically. In particular, the
Java LSP plugin also requires `jdtls` and a compatible DSH LSP base.

Git plugin dependencies are identified by exact SHA and subdirectory.
However, like the npm plugins, the resolution of their transitive
dependencies still happens in mutable DSH profile state; this is not a
reproducible Nix derivation.

## Daily security check

`.github/workflows/dsh-plugin-security.yml` runs daily at **03:17 UTC**
and on manual dispatch or relevant pull requests. It audits the six exact
pinned package sources with `npm audit --audit-level=high`, excluding
development dependencies, and retrieves GitHub sources by verified commit SHA
without invoking their lifecycle scripts. It reports a known Java plugin
compatibility mismatch. Scheduled workflow jobs require the workflow to be
on the repository's default branch; GitHub Actions scheduling can be delayed.

This is a dependency-advisory check, **not a full malware/security scan**.
It does not exercise runtime code, prove absence of credential exfiltration,
or automatically assess new upstream versions. Findings are visible as
failed GitHub Actions jobs. Do not enable arbitrary build scripts to fix
Git-source installation failures without reviewing them.

The Java LSP package is excluded from automatic installation after DSH rejected it at runtime. Its exact-version compatibility exemption is intentionally **not** enabled. Provisioning now continues to `dsh-github-ci`; GitHub CI still audits the Java LSP dependency declaration for security visibility. The web interface at port 3080 was already running on the user's machine, so another `dsh --profile web --no-open` process would fail with `EADDRINUSE`.
