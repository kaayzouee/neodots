{
  lib,
  stdenv,
  callPackage,
  fetchFromCodeberg,
  libGL,
  libevdev,
  libinput,
  libx11,
  libxkbcommon,
  pixman,
  pkg-config,
  scdoc,
  udev,
  versionCheckHook,
  wayland,
  wayland-protocols,
  wayland-scanner,
  wlroots_0_20,
  xwayland,
  zig_0_16,
  withManpages ? true,
  xwaylandSupport ? false,
}:

let
  zig = zig_0_16;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "river";
  version = "0.4.8";

  outputs = [ "out" ] ++ lib.optionals withManpages [ "man" ];

  src = fetchFromCodeberg {
    owner = "river";
    repo = "river";
    tag = "v${finalAttrs.version}";
    hash = "sha256-vqOGyd0sddjYZ47xPMFmfzDIg8mHfIBzAJQ2CcsMQ3Y=";
  };

  deps = callPackage ./build.zig.zon.nix { };

  strictDeps = true;

  nativeBuildInputs = [
    pkg-config
    wayland-scanner
    xwayland
    zig
  ]
  ++ lib.optional withManpages scdoc;

  buildInputs = [
    libGL
    libevdev
    libinput
    libxkbcommon
    pixman
    udev
    wayland
    wayland-protocols
    wayland-scanner
    wlroots_0_20
  ]
  ++ lib.optional xwaylandSupport libx11;

  zigBuildFlags = [
    "--system"
    "${finalAttrs.deps}"
    "-Doptimize=ReleaseSafe"
  ]
  ++ lib.optional withManpages "-Dman-pages"
  ++ lib.optional xwaylandSupport "-Dxwayland";

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "-version";

  postInstall = ''
    install contrib/river.desktop -Dt $out/share/wayland-sessions
  '';

  passthru = {
    providedSessions = [ "river" ];
  };

  meta = {
    description = "Non-monolithic Wayland compositor";
    homepage = "https://codeberg.org/river/river";
    changelog = "https://codeberg.org/river/river/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      gpl3Only
      mit
    ];
    mainProgram = "river";
    platforms = lib.platforms.linux;
  };
})
