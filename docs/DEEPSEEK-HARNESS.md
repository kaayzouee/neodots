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
published** this as an upstream/npm release. Its Nix source and dependency
hashes were verified by the neodots NixOS build at this commit, but every
subsequent fork release commit requires freshly verified hashes. Neither `river`
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
to test the real packaged host. After the security fork PR passes its independent CI and merges, run the
fork's manual **Prepare or tag DSH release** workflow on `master` with
`operation=prepare` and a new semver. That workflow runs the repository's
`release:dsh` script to update all family manifests and the lockfile, then
opens a release-bump PR. Merge it only after its CI and packed-install checks
pass. Run the same workflow with `operation=tag` on the validated `master`
commit to create `dsh-v<version>` and a GitHub release. npm publication
remains a separate protected manual workflow. Finally repin this Nix
derivation to that exact release commit, update its `version`, recalculate
both fixed-output hashes, and rerun the neodots CI checks.

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
`0.2.0`. It **has not been validated** with the locally built, patched
DSH fork. Its published compatibility declaration does not include this
release candidate. Its build may require an allowed Git dependency
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

**Scope limit:** the six plugin audits do **not** scan the pinned DSH host
or the actual installed profile lockfile. The separate, blocking
`host-dependency-audit` job fetches the exact fork commit in the Nix recipe,
checks its Zod resolution, and runs `pnpm audit --prod --audit-level high`
against the host's locked production graph. This is not an audit of the
Nix-provided Node runtime, profile-local mutable dependencies, or the runtime
compatibility/exploitability of host-supplied peers. Advisory results depend
on the registry's current database. Scheduled jobs require this workflow on
the default branch and may be delayed. The Java LSP incompatibility warning
is retained.

On 2026-11-05, npm's *default* automatic SIWC peer resolution selected
historical DSH peer packages containing vulnerable Zod `4.4.3`, affected
by [GHSA-mrhx-c7xc-m3w5](https://github.com/advisories/GHSA-mrhx-c7xc-m3w5)
(fixed in `4.6.6`). The six high-severity entries represented one advisory
and propagated dependency findings, not six independent vulnerabilities.
The Web profile does not auto-install those peers. The proposed local fork
instead pins patched Zod `4.6.7`; the Nix install check verifies its pnpm
store and the host-dependency-audit CI job checks additional locked host
dependencies. Passing CI would support the patched dependency claim, not
prove that all runtime inputs are safe or that optional plugins are compatible.
See [host audit issue #12](https://github.com/kaayzouee/neodots/issues/12)
for tracking and the
[upstream DSH dependency report](https://github.com/deepseek-ai/deepseek-harness/discussions/10847)
for background.

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
