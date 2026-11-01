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

The `neodots-dsh-siwc` user service provisions
`dsh-plugin-chatgpt-siwc@0.9.7` into the `web` profile when its installed
version is missing or different. The installer uses the DSH plugin manager,
disables npm install scripts, and checks the resulting package version. It
runs independently of the NixOS rebuild so a network outage cannot fail a
system activation.

To provision it again or inspect its failure:

```sh
systemctl --user start neodots-dsh-siwc.service
systemctl --user status neodots-dsh-siwc.service
journalctl --user -u neodots-dsh-siwc.service
```

Start the app with `dsh web`, enable the SIWC bundle if the plugin manager
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
