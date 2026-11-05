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

The primary Home Manager user receives the locally built DSH package from
[`packages/deepseek-harness/default.nix`](../packages/deepseek-harness/default.nix),
rather than `pkgs.deepseek-harness`. The recipe pins the exact security-patched
[`kaayzouee/deepseek-harness`](https://github.com/kaayzouee/deepseek-harness)
commit `5679627ac8f9c5a0c695416c0e1cbf1ea937941d` and uses the
same Node 24/pnpm 11 build and loader patch as the referenced nixpkgs package.
Its local package label is `0.2.2-rc.1-zod.1`; the fork has **not yet
published** this as an upstream/npm release. CI must verify both fixed source
and pnpm dependency hashes before this package is deployed. Neither `river`
nor `guest` receives DSH or the SIWC plugin.

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

- **Nix package:** reproducible after CI validates the fixed hashes in the
  local derivation. The source is pinned by full fork commit, and the build's
  `fetchPnpmDeps` output must also have a verified immutable hash; nixpkgs
  supplies only the build tools, not the DSH package definition.
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

The fork security patch updates DSH's own Zod declarations and frozen pnpm
lockfile to patched `4.6.7` (see
[DSH fork PR #1](https://github.com/kaayzouee/deepseek-harness/pull/1)).
This is a separate issue from the plugin-only security workflow: use
`nix build .#deepseek-harness` and `nix build .#checks.x86_64-linux.dsh-local-web-boot`
to test the real packaged host. The upstream release tag and npm publication
must follow successful build and release-family verification.

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
are pinned to reviewed commit IDs. It audits fresh dependency resolutions for
the six exact pinned plugin sources with `npm audit --audit-level=high`,
excluding development dependencies but retaining optional runtime dependencies.
For npm plugins and Git plugin manifests, it uses `--legacy-peer-deps` when
constructing the temporary npm lockfile. This matches the pinned DSH host's
`pnpm-workspace.yaml` setting `autoInstallPeers: false`: the profile does not
automatically install peers, which instead come from the DSH host installation.
GitHub sources are retrieved by verified commit SHA without invoking their
lifecycle scripts.

**Scope limit:** these plugin audits are **not** a scan of the pinned DSH host's
transitive dependency closure or the actual installed profile lockfile. Nor do
they establish the versions or exploitability of host-supplied peers. Resolved
optional dependencies can differ from the running host. Scheduled jobs require
the workflow to be on the default branch; GitHub Actions scheduling can be delayed.
The workflow warns about the known Java LSP compatibility mismatch.

On 2026-11-05, npm's *default* automatic peer resolution failed the SIWC
audit: it auto-installed DSH host peers whose exact Zod `4.4.3` pin is
affected by [GHSA-mrhx-c7xc-m3w5](https://github.com/advisories/GHSA-mrhx-c7xc-m3w5)
(fixed in `4.6.6`). npm reported six high-severity dependent entries,
**not six independent vulnerabilities**. Those peers are not installed by
the profile's plugin installer, so the plugin-only audit no longer
auto-installs them. **This does not fix the DSH host vulnerability**:
the locked DSH `0.2.1-rc.3` host may still contain vulnerable Zod, and
the compatibility job emits a warning until it is patched. Track the
[upstream DSH dependency report](https://github.com/deepseek-ai/deepseek-harness/discussions/10847).
An independent audit of the Nix-built host closure is still needed.

This is a dependency-advisory check, **not a full malware/security scan**.
It does not exercise runtime code, prove absence of credential exfiltration,
or automatically assess new upstream versions. Findings within its
plugin dependency scope fail GitHub Actions jobs. Do not enable arbitrary
build scripts to fix Git-source installation failures without reviewing them.

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
