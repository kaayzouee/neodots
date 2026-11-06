# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Pinned, locally maintained DeepSeek Harness package.
#
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.
#
# Adapted from nixpkgs a464ea5962981fe9cea53ad9b046dc2d612d8c12.

{
  lib,
  stdenv,
  curl,
  fetchFromGitHub,
  fetchPnpmDeps,
  makeBinaryWrapper,
  nodejs_24,
  pnpm_11,
  pnpmBuildHook,
  pnpmConfigHook,
  runCommand,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "deepseek-harness";
  version = "0.2.2-rc.1-zod.1";

  strictDeps = true;
  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "kaayzouee";
    repo = "deepseek-harness";
    rev = "5679627ac8f9c5a0c695416c0e1cbf1ea937941d";
    hash = "sha256-iTYxHbYZ6aKLUrKGGdPF5keez78FMx+rN9pSpxlUlvI=";

    # Capture the commit hash at fetch time to avoid git build dependency
    leaveDotGit = true;
    postFetch = ''
      cd $out
      git rev-parse HEAD > .git-commit
      rm -rf .git
    '';
  };

  # internalModules() calls node-addon-require-builtin unconditionally, but
  # its binary scan does not recognize toolchain-built Node
  # (Unsupported/no-getter), breaking every `dsh --profile …` boot. Prefer a
  # plain require under --expose-internals (which the wrapper below passes).
  patches = [
    ./expose-internals-profile-resolution.patch
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-hUi2N9ymsTvLiZ6RdwSDvjGQr+qxzC7RQfpnM/y3thE=";
  };

  nativeBuildInputs = [
    nodejs_24
    pnpmConfigHook
    pnpmBuildHook
    pnpm_11
    makeBinaryWrapper
  ];

  preBuild = ''
    export DSH_CLIENT_COMMIT_HASH=$(cat $src/.git-commit)
    export DSH_CLIENT_BUILD_PROFILE="official";
  '';

  # The root 'build' script runs both 'build:lib' and 'build:web'
  # pnpmBuildHook runs 'pnpm run build' by default
  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/dsh
    cp -r . $out/libexec/dsh/

    # The .git-commit marker only feeds the build-time commit stamp.
    rm -f $out/libexec/dsh/.git-commit

    # Drop dangling symlinks from optional cross-platform packages.
    find $out/libexec/dsh/node_modules/.pnpm -type l ! -exec test -e {} \; -delete

    # Mirror workspace packages to the root node_modules so the loader's bare import() resolves.
    shopt -s nullglob
    store_scopes=("$out/libexec/dsh/node_modules/.pnpm/node_modules/"@*/)
    for scope in "''${store_scopes[@]}"; do
      scope_name=$(basename "$scope")
      mkdir -p "$out/libexec/dsh/node_modules/$scope_name"
      for pkg in "$scope"*; do
        # -n: do not dereference an existing symlink-to-dir
        ln -sfn "../.pnpm/node_modules/$scope_name/$(basename "$pkg")" \
          "$out/libexec/dsh/node_modules/$scope_name/$(basename "$pkg")"
      done
    done

    # --expose-internals is required by the HMR service and the loader's internal module loader
    makeBinaryWrapper ${nodejs_24}/bin/node $out/bin/dsh \
      --prefix PATH : ${lib.makeBinPath [ pnpm_11 ]} \
      --add-flags "--expose-internals $out/libexec/dsh/apps/cli/lib/bin.js"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    export HOME=$TMPDIR
    $out/bin/dsh --version

    # Reject stale Zod copies in the installed pnpm dependency closure.
    node - "$out/libexec/dsh/node_modules/.pnpm" <<'NODE'
    const fs = require('node:fs');
    const names = fs.readdirSync(process.argv[2]).filter(name => /^zod@/.test(name));
    if (names.length !== 1 || names[0] !== 'zod@4.6.7') {
      throw new Error('expected only patched zod@4.6.7; found: ' + names.join(', '));
    }
    NODE
  '';

  passthru = {
    tests = {
      web-boot =
        runCommand "deepseek-harness-web-boot"
          {
            nativeBuildInputs = [
              curl
              finalAttrs.finalPackage
            ];
          }
          ''
            export HOME=$TMPDIR
            dsh --profile web --no-open --port 0 >server.log 2>&1 &
            pid=$!
            trap 'kill $pid 2>/dev/null || true' EXIT
            for i in $(seq 1 30); do
              if launch_url=$(grep -o 'http://127.0.0.1:[0-9]\+/?token=[^[:space:]]*' server.log); then
                break
              fi
              sleep 1
            done
            if [ -z "''${launch_url:-}" ]; then
              echo "dsh web profile failed to print the authenticated launch URL" >&2
              cat server.log >&2
              exit 1
            fi
            echo "✓ Found launch URL on server logs ($launch_url)"
            curl --fail --silent --show-error --location -c cookies.txt "$launch_url" | grep -q '<!doctype html>'
            touch $out
          '';
    };
  };

  meta = {
    description = "AI agent harness with a plugin-based architecture";
    longDescription = ''
      DeepSeek Harness (dsh) is a self-hosted AI agent harness built around a
      plugin architecture — "Everything is a Plugin". It ships a CLI and a web
      UI and is extended through workspace plugins.
    '';
    homepage = "https://github.com/kaayzouee/deepseek-harness";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = [ ];
  };
})
