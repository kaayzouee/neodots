{
  lib,
  stdenv,
  callPackage,
  fetchFromGitHub,
  fcft,
  libxkbcommon,
  pkg-config,
  pixman,
  wayland,
  wayland-protocols,
  wayland-scanner,
  zig_0_16,
  withBar ? true,
  withCustomConfig ? false,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "kwm";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "kewuaa";
    repo = "kwm";
    tag = "v${finalAttrs.version}";
    hash = "sha256-hX76wTHPTgg5RAHILfd3CjRKPlgAwGSK3lG82IFoUUs=";
  };

  patches = [
    ./set-floating-action.patch
  ];

  deps = callPackage ./kwm-build.zig.zon.nix { };

  nativeBuildInputs = [
    zig_0_16
    wayland-scanner
    pkg-config
  ];

  buildInputs = [
    wayland
    wayland-protocols
    pixman
    fcft
    libxkbcommon
  ];

  zigBuildFlags = [
    "--system"
    "${finalAttrs.deps}"
    "-Doptimize=ReleaseSafe"
  ]
  ++ lib.optional withBar "-Dbar"
  ++ lib.optional withCustomConfig "-Dconfig";

  meta = {
    homepage = "https://github.com/kewuaa/kwm";
    description = "DWM-like dynamic tiling window manager for River";
    longDescription = ''
      kwm is a DWM-like dynamic tiling window manager implementing the
      river-window-management-v1 protocol used by River 0.4 and newer.
    '';
    license = lib.licenses.gpl3Only;
    mainProgram = "kwm";
    platforms = lib.platforms.linux;
  };
})
