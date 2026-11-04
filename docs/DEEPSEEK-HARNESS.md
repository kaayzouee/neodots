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
into the `web` profile when their installed name/version or declared source differs.
For npm packages it checks the exact saved version; for Git packages it checks the
full commit source. The installer uses the DSH plugin manager, disables npm install
scripts, and checks the resulting package version. It runs independently of the
NixOS rebuild so a network outage cannot fail a system activation.

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

[The security workflow](../.github/workflows/dsh-plugin-security.yml) runs daily
at **03:17 UTC** and on manual dispatch or relevant pull requests. Its Actions
are pinned to reviewed commit IDs. It audits fresh dependency resolutions of the
six exact pinned package sources with `npm audit --audit-level=high`, excluding
development dependencies but retaining optional and peer dependency declarations.
GitHub sources are retrieved by verified commit SHA without invoking their
lifecycle scripts. This is **not** an audit of the installed profile lockfile;
resolved peers can differ from those supplied by the running DSH host.
It reports the known Java compatibility mismatch as a warning, not a failing gate.
Scheduled jobs require the workflow to be on the repository's default branch;
GitHub Actions scheduling can be delayed.

The 2026-11-03 UTC audit of SIWC's fresh peer graph selected DSH peer packages
`0.2.1-rc.5` and Zod `4.4.3`. It failed with six high-severity dependency entries
from [GHSA-mrhx-c7xc-m3w5](https://github.com/advisories/GHSA-mrhx-c7xc-m3w5)
(Zod memory exhaustion; fixed in `4.6.6`), including propagated dependents—not six
independent vulnerabilities. The other five source audits passed. This does not
establish the versions or exploitability of the pinned DSH runtime closure.
Keep the failure visible; review upstream constraints before changing pins or
adding overrides. Ignoring peer dependencies hides this finding rather than fixing it.

This is a dependency-advisory check, **not a full malware/security scan**.
It does not exercise runtime code, prove absence of credential exfiltration,
or automatically assess new upstream versions. Findings are visible as
failed GitHub Actions jobs. Do not enable arbitrary build scripts to fix
Git-source installation failures without reviewing them.

The Java LSP package remains excluded after DSH rejected it at runtime. Its
exact-version compatibility exemption is intentionally **not** enabled. Other
plugins, including `dsh-github-ci`, are still provisioned. Do not start a second
web server on a port already used by DSH.

## Offline installer regression check

```sh
python3 tests/check-dsh-installer.py
```

[The check](../tests/check-dsh-installer.py) evaluates the module's installer text
using a stub `writeShellApplication`, then runs it with a mock `dsh` and temporary
`HOME`/`DSH_HOME`. It covers fresh installation, repeat-run idempotence, scoped npm
and Git pins, name/version/source mismatches, missing manifests, and the default
`HOME/.dsh` path. It requires Nix, Python 3, Bash and Node, but no network,
credentials, real profile access, or activation. A pre-evaluated installer text
file can be passed as its sole argument for sandboxed checks.
