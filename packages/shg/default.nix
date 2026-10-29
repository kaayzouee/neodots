# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Nix package for shg.
#
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.

{
  lib,
  stdenv,
  fetchFromGitHub,
  linkFarm,
  fetchzip,
  fetchgit,
  zig_0_16,
}:

let
  zigDeps = import ./shg-deps.nix {
    inherit linkFarm fetchzip fetchgit;
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "shg";
  version = "0.2.6";

  src = fetchFromGitHub {
    owner = "vrypan";
    repo = "shg";
    rev = "b70c44bab87ab78477b3112d9097beb1c8be9968";
    sha256 = "10vw2lvhbnin0hfxyfsrq2j0yr0sqgpv54nblm7xd2dbvsvwk16f";
  };

  # shg 0.2.6 uses std.Build.args, which is incompatible with Zig 0.17.
  nativeBuildInputs = [ zig_0_16 ];

  strictDeps = true;

  # Zig 0.16 expects a writable global cache; sandbox blocks the default
  env.ZIG_GLOBAL_CACHE_DIR = "$TMPDIR/zig-cache";

  # Make the pre-fetched dependency store available to Zig
  postPatch = ''
    ln -s ${zigDeps} zig-pkg
  '';

  buildPhase = ''
    runHook preBuild
    zig build --release=safe
    runHook postBuild
  '';

  # Remove these two if the upstream repo has no test step in build.zig
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    zig build test
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp zig-out/bin/shg zig-out/bin/shg-config $out/bin/
    runHook postInstall
  '';

  meta = {
    description = "Scan shell history files for accidentally persisted secrets";
    longDescription = ''
      shg scans shell history files, environment variables, and AI agent
      transcripts for accidentally persisted secrets such as API tokens,
      passwords, private keys, and connection strings. Detection rules are
      user-customizable and the tool is designed to run locally and offline.
    '';
    homepage = "https://github.com/vrypan/shg";
    changelog = "https://github.com/vrypan/shg/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "shg";
  };
})
