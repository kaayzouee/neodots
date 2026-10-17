<!--
SPDX-License-Identifier: GPL-3.0-only

Neodots - Design notes and implementation record for the reproducible
          language toolchains, direnv activation, and VS Code integration.

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

# Neodots Reproducible Toolchains

## Status

This document is the persistent design memory and implementation record for the language toolchains that Neodots exposes through its flake, the direnv-based activation of those shells, and the VS Code configuration that consumes them.

Current state: five language devShells (`cpp`, `qt`, `rust`, `python`, `asm`), matching flake templates, direnv + nix-direnv activation, and the full VS Code extension set for those languages are all implemented and verified end-to-end on the reference machine. The C++ pipeline (`direnv` → `clang` → `cmake` → `compile_commands.json` → `clangd`) is verified with a working binary. Remaining work is limited to optional polish: additional language extensions, marketplace extensions for tools not packaged in nixpkgs, and a documented procedure for removing the temporary solaar workaround once its upstream PR lands.

## The problem this solves

Before this project, developing a compiled-language project on Neodots had three recurring sources of friction:

1. **Per-project toolchain drift.** Each project needed its own `shell.nix` (or `flake.nix`), and adding a package meant editing every project individually. Two C++ projects could silently use different clang versions.

2. **Manual VS Code JSON editing.** `tasks.json` and `c_cpp_properties.json` had to be hand-maintained per project, with absolute include paths and compiler paths that broke on every toolchain bump and every new machine.

3. **Direnv-less shells.** `nix-shell` and `nix develop` worked, but they were explicit actions the developer had to remember. Opening a project in VS Code without first activating the shell meant clangd had no toolchain and no `compile_commands.json`.

The target of this project is: **a new project should be functional in three commands, and updating the toolchain should be a one-file edit.**

## Design principles

### 1. The flake is the single source of truth

`flake.nix` is the only place a language toolchain is declared. No project carries its own `shell.nix`; no project hardcodes a compiler path. Adding a package to `devShells.<system>.cpp.packages` and running `direnv reload` propagates the change to every C++ project on the machine.

### 2. Direnv handles activation, not the developer

`nix-direnv` caches the evaluated shell to disk, so activation is fast enough to be invisible. The developer never needs to run `nix develop` manually for a project that has a `.envrc`.

### 3. Language servers consume the same toolchain as the compiler

clangd reads `compile_commands.json`, which CMake writes with the flags from the currently active compiler. rust-analyzer runs `cargo metadata`, which uses the `cargo` on `PATH`. Python tooling uses the `python3` on `PATH`. In every case, the language server and the build tool see the **same** binaries because both derive from the same `devShell`.

The `CC=clang` / `CXX=clang++` override in the `cpp` and `qt` shells exists specifically to keep this alignment exact: CMake otherwise picks `g++` from `stdenv`, and while clangd can parse g++-generated databases, the diagnostic wording (and clang-specific extensions) diverge.

### 4. Templates scaffold, they do not live in the project

Templates in `templates/` are minimal: `.envrc` and, for C/C++/Qt, `.clangd`. `nix flake init -t ~/neodots#cpp` copies them into the target directory. There is no `shell.nix` to copy, no per-project toolchain declaration, and no generated file that should be committed beyond those two tiny ones.

### 5. No per-project boilerplate survives a toolchain change

If clang is bumped in `flake.nix`, no project needs a commit. `direnv reload` picks up the new shell; `cmake -B build` re-runs and regenerates `compile_commands.json` against the new compiler. This is the test for any future addition to the system.

## Architecture

```
~/neodots/
├── flake.nix
│    ├── devShells.<system>.cpp     ← clang, clangd, cmake, gnumake, gdb, lldb
│    ├── devShells.<system>.qt      ← qtEnv + clang toolchain + qtcreator
│    ├── devShells.<system>.rust    ← rustc, cargo, rust-analyzer, rustfmt, clippy
│    ├── devShells.<system>.python  ← python3, pip, virtualenv, ruff, black
│    ├── devShells.<system>.asm     ← nasm, yasm, binutils, gdb
│    └── templates.<lang>.path      ← ./templates/<lang>
│
├── templates/
│    ├── cpp/{.envrc,.clangd}
│    ├── qt/{.envrc,.clangd}
│    ├── rust/{.envrc}
│    ├── python/{.envrc}
│    └── asm/{.envrc}
│
└── hosts/nixos/
     ├── home.nix          ← programs.direnv, xfconf Ctrl+Alt+T
     └── river-home.nix    ← programs.direnv, programs.vscode extensions
```

Every `.envrc` contains exactly one line:

```
use flake ~/neodots#<lang>
```

Every `.clangd` contains exactly:

```
CompileFlags:
  CompilationDatabase: build
```

These are the only per-project files that need to exist for the workflow to function.

## DevShell reference

### `cpp`

```nix
packages = with pkgs; [
  clang          # compiler
  clang-tools    # clangd, clang-format, clang-tidy
  cmake
  gnumake        # provides `make` (package name ≠ binary name)
  gdb            # debugger
  lldb           # debugger (LLVM)
];
shellHook = ''
  export CMAKE_EXPORT_COMPILE_COMMANDS=1
  export CC=clang
  export CXX=clang++
'';
```

`CMAKE_EXPORT_COMPILE_COMMANDS=1` is what causes `cmake -B build -S .` to write `build/compile_commands.json` without any explicit flag. Without it, clangd has no compilation database and falls back to guessing flags from file extensions.

`CC` and `CXX` are what pin CMake to clang. CMake's default is `cc`/`c++`, which in `mkShell`'s environment resolve to `stdenv`'s `gcc`. Overriding them keeps the compiler, clangd's parse, and any diagnostics in agreement.

### `qt`

```nix
let
  qtEnv = with pkgs.qt6; env "qt-custom-${qtbase.version}" [
    qtbase qtdeclarative qttools qt5compat qtwayland
  ];
in
pkgs.mkShell {
  packages = [ qtEnv pkgs.clang pkgs.clang-tools pkgs.cmake pkgs.gnumake pkgs.gdb pkgs.qtcreator ];
  shellHook = ''
    export CMAKE_EXPORT_COMPILE_COMMANDS=1
    export CC=clang
    export CXX=clang++
    export QT_PLUGIN_PATH="${qtEnv}/lib/qt-6/plugins"
    export QML_IMPORT_PATH="${qtEnv}/lib/qt-6/qml"
    export QT_QPA_PLATFORM_PLUGIN_PATH="${qtEnv}/lib/qt-6/plugins/platforms"
    export PKG_CONFIG_PATH="${qtEnv}/lib/pkgconfig:$PKG_CONFIG_PATH"
  '';
}
```

`pkgs.qt6.full` was removed from nixpkgs around 25.11. The replacement is `qt6.env "name" [modules…]`, which builds a merged prefix from an explicit module list. The `QT_*` exports point qmake, CMake, and Qt's runtime plugin loader at the merged prefix so no environment discovery is required.

`qtcreator` is included in `packages` for developers who prefer the Qt IDE; it inherits the same shell environment as everything else.

### `rust`

```nix
packages = with pkgs; [ rustc cargo rust-analyzer rustfmt clippy ];
```

No `shellHook` is necessary: rust-analyzer runs `cargo metadata` itself, so it discovers the toolchain from `PATH`. `rustfmt` and `clippy` are included because rust-analyzer invokes them for formatting and lint integration.

### `python`

```nix
packages = with pkgs; [
  python3
  python3Packages.pip
  python3Packages.virtualenv
  ruff
  python3Packages.black
];
```

No pinned interpreter packages are declared. Projects that need pinned dependencies should either use a `pyproject.toml` + `venv` inside the shell (standard Python practice) or add a `python.withPackages` shell to `flake.nix` for the specific project. The default shell is deliberately generic.

### `asm`

```nix
packages = with pkgs; [ nasm yasm binutils gdb ];
```

`binutils` provides `ld`, `objdump`, `as`, and the other assembly tooling; `gdb` is for debugging flat binaries. No C compiler is included; assembly-only projects do not need one. If a project mixes C and assembly, use the `cpp` shell instead.

## Templates and their scaffolding

`templates/<lang>/.envrc` contains a single line pointing back at the flake. `templates/cpp/.clangd` and `templates/qt/.clangd` point clangd at `build/compile_commands.json`.

The templates are intentionally minimal. Adding more files (a `Makefile`, a stub `CMakeLists.txt`, a `.gitignore`) makes the template opinionated and reduces its applicability. The three-command setup (`nix flake init`, `direnv allow`, `cmake -B build`) is short enough that pre-populated project files are unnecessary.

Usage:

```
mkdir ~/code/my-project && cd ~/code/my-project
nix flake init -t ~/neodots#cpp
direnv allow
# press Enter (fish prompt hook fires on next prompt, not current)
```

## Direnv integration

`programs.direnv` is enabled in both `home.nix` and `river-home.nix`:

```nix
programs.direnv = {
  enable = true;
  nix-direnv.enable = true;
  silent = true;
};
```

`nix-direnv` is what makes activation fast enough to be unnoticeable: without it, `direnv allow` on the `qt` shell rebuilds Qt every time you `cd` into the project. With it, the shell is cached in `~/.cache/nix-direnv/` and reused until `flake.lock` changes.

### The fish prompt-hook caveat

Direnv's fish hook fires on the `fish_prompt` event — after the current command finishes, before the next prompt is drawn. When several commands are pasted together, they run in **one** prompt cycle, so the environment from `.envrc` is not yet applied to any of them. The user-visible symptom is:

```
direnv allow
which clang          ← "no clang" because env not yet loaded
                     ← prompt redraws → hook fires → env loaded
```

The fix is not a code change; it is a rule of thumb:

- After `direnv allow` or `direnv reload`, **press Enter once** before checking the environment, or run `direnv reload` explicitly, or `cd .` to force a prompt redraw.

This behavior is intrinsic to fish's event model, not to direnv or Neodots. Bash and zsh hooks fire on `PROMPT_COMMAND` / `precmd`, which is the same after-command timing.

## VS Code integration

### `mutableExtensionsDir = false`

Home Manager's `programs.vscode` module creates the extensions directory (`~/.vscode/extensions`) as a set of symlinks into the Nix store. If the directory remains mutable, VS Code's own extension manager sometimes tries to rewrite or replace those symlinks, producing errors like:

```
Unable to read file '~/.vscode/extensions/pinage404.nix-extension-pack/package.json'
(Error: Unable to resolve nonexistent file ...)
```

Setting `mutableExtensionsDir = false;` tells HM to keep the directory strictly under its control. This was the actual fix for the original extension-pack error; it is not a packaging defect in the extension itself.

### `profiles.default.extensions` vs `extensions`

The `extensions` list must be assigned under a profile in current Home Manager:

```nix
profiles.default.extensions = [ ... ];
```

Writing `profiles.default = { };` (with an empty attrset and no dot chain) followed by a separate `extensions = [ … ];` line is a common mistake: the empty attrset is closed, so `extensions` becomes a sibling of `profiles` and the module evaluator either ignores it or reports a duplicate.

The dotted form avoids this class of mistake.

### Quoted attribute access for marketplace-only extensions

`pkgs.vscode-extensions` exposes extensions as nested attributes: `rust-lang.rust-analyzer` is `pkgs.vscode-extensions.rust-lang.rust-analyzer`. Within a `with pkgs.vscode-extensions; [ … ]` block, bare identifiers work **only** for publishers whose names are valid Nix identifiers (letters/digits/underscores/dashes, not starting with a digit).

For publishers that start with a digit, or for any extension that is not packaged in nixpkgs, explicit quoted access is required:

```nix
pkgs.vscode-extensions."13xforever"."language-x86-64-assembly"
```

Writing this inside a `with` block fails at evaluation with `expected a set but found a string` because Nix parses `"13xforever".language` as a property access on a string literal (i.e., string subtraction in the arithmetic sense), not as identifier resolution.

The current config sidesteps this by pulling the assembly extension out of the `with` block into its own explicit list:

```nix
((with pkgs.vscode-extensions; [ … ])
 ++ [ pkgs.vscode-extensions."13xforever"."language-x86-64-assembly" ])
++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [ … ]
```

### Extensions and the language servers they use

The current extension set is:

| Extension | Purpose | Language server |
|---|---|---|
| `jnoortheen.nix-ide` | Nix editing | `nixd` (already in `home.packages`) |
| `arrterian.nix-env-selector` | nix-shell selection | — |
| `mkhl.direnv` | Auto-load `.envrc` | — |
| `llvm-vs-code-extensions.vscode-clangd` | C / C++ / Qt | `clangd` (from devShell) |
| `ms-vscode.cpptools-extension-pack` | Build / debug tasks | — |
| `"13xforever".language-x86-64-assembly` | Assembly syntax | — |
| `rust-lang.rust-analyzer` | Rust | `rust-analyzer` (from devShell) |
| `tamasfe.even-better-toml` | `Cargo.toml`, `flake.lock` | — |
| `ms-python.python` | Python runtime integration | — |
| `ms-python.vscode-pylance` | Python analysis | `pyright` (bundled) |
| `pinage404.nix-extension-pack` | Meta pack | — |

`mkhl.direnv` is what makes the `.envrc`-activated toolchain available **inside** VS Code, not just in the terminal. Without it, opening a project in VS Code without first activating the shell from a terminal leaves clangd and rust-analyzer with no toolchain to invoke.

`llvm-vs-code-extensions.vscode-clangd` should be installed **instead of** `ms-vscode.cpptools`'s own IntelliSense engine. `cpptools-extension-pack` is kept for build/debug task integration only; its `C_Cpp.intelliSenseEngine` setting should be set to `"disabled"` in workspace settings if both are installed, to avoid two language servers fighting over the same files. This is a per-workspace choice; the current config leaves it unset (VS Code prompts on first open).

## The clangd pipeline

The path from source to language server is:

```
flake.nix (clang, clangd, cmake)
   ↓ direnv activate
$PATH: clang, cmake, clangd
   ↓ export CXX=clang++
cmake -B build -S .
   ↓ CMAKE_EXPORT_COMPILE_COMMANDS=1
build/compile_commands.json
   ↓ .clangd (CompilationDatabase: build)
clangd reads the database
   ↓
completions, diagnostics, goto-definition, refactors
```

Every step is driven by a single environment variable or a single file. No component of the pipeline requires manual JSON editing.

The one irreducible manual step is running `cmake -B build` **once** per project. Nothing can know a project's include paths or compile flags before its build system has been configured; that is a property of CMake (and any build system), not of Nix or of Neodots.

For projects that use a build system other than CMake, clangd supports `compile_commands.json` generated by `bear -- make` (for Makefile projects) or `compiledb` (for arbitrary build commands). The `.clangd` file can be edited to point at a different database directory; the shell does not need to change.

## Daily workflow

### Start a new project

```
mkdir ~/code/my-project && cd ~/code/my-project
nix flake init -t ~/neodots#<lang>
direnv allow
# press Enter once
code .
```

For C / C++ / Qt, also run once inside the project (from VS Code's integrated terminal):

```
cmake -B build -S .
```

### Open an existing project

```
cd ~/code/my-project
code .
```

The `mkhl.direnv` extension loads the shell as soon as VS Code opens the folder; clangd and rust-analyzer start immediately with the correct toolchain.

### Add a tool to a shell

Edit `flake.nix` → `devShells.<system>.<lang>.packages`, add the package, then in each project that uses that shell:

```
direnv reload
```

### Update a toolchain

```
cd ~/neodots
nix flake update
```

Then in each active project:

```
direnv reload
```

### Use a shell without a project file

```
nix develop ~/neodots#cpp -c code .
```

Useful for one-off projects or scratch work where the developer does not want to leave a `.envrc` behind.

## Related fixes made in the same session

These are not part of the toolchain system itself but were resolved alongside it and are recorded here so future-you has the full picture:

### nano configuration

`modules/programs/nano.nix` enables nano with `set mouse` in `nanorc`, which makes nano advertise mouse reporting to the terminal. This is what allows the tmux wheel binding (which checks `#{mouse_any_flag}` before forwarding the wheel) to work inside nano. Without `set mouse`, tmux swallows the wheel and nano never sees it.

### tmux pane navigation override

The `vim-tmux-navigator` plugin, loaded in `modules/programs/tmux.nix`, installs its own `C-h/j/k/l` bindings via `run-shell`. Because Home Manager places plugin `run-shell` lines *after* `extraConfig`, any `bind-key` in `extraConfig` for the same keys is silently overwritten at plugin load time. The plugin's regex also omits `nano`, so `C-k` inside nano switched panes instead of cutting the line.

The fix is two-part:

1. Remove `vim-tmux-navigator` from `programs.tmux.plugins`.
2. Add the standard `alternate_on`-based navigation binds in `extraConfig`:

   ```nix
   bind -n C-h if-shell -F "#{alternate_on}" "send-keys C-h" "select-pane -L"
   bind -n C-j if-shell -F "#{alternate_on}" "send-keys C-j" "select-pane -D"
   bind -n C-k if-shell -F "#{alternate_on}" "send-keys C-k" "select-pane -U"
   bind -n C-l if-shell -F "#{alternate_on}" "send-keys C-l" "select-pane -R"
   ```

   `alternate_on` is true for any full-screen application (vim, nano, less, fzf), so the same rule works for all of them without maintaining an editor whitelist.

### Ctrl+Alt+T on XFCE

`desktop-xfce.nix` excludes `xfce4-terminal` from the XFCE package set, but the default Ctrl+Alt+T shortcut still tries to launch it via `exo-open`. The binding is redirected to `alacritty` in `home.nix`:

```nix
xfconf.settings."xfce4-keyboard-shortcuts" = {
  "commands/custom/override" = true;
  "commands/custom/<Primary><Alt>t" = "alacritty";
};
```

Note: `Ctrl+Alt+T` is an XFCE shortcut, and the primary desktop session on the reference machine is River (Wayland). This fix applies only to XFCE sessions started from LightDM. On River, terminals are launched from the dock, fuzzel, or a direct `alacritty` invocation.

## Temporary workarounds

### solaar test failure (PR #574929)

Building the system on nixpkgs `26f4107e47e3ad0ffd0db220469ba83b6f6d96e8` fails because Solaar 1.1.19's test suite spawns a D-Bus notification without a session bus or `/etc/machine-id`. The failure cascades through `hwdb.bin` → `udev-rules` → `etc` and blocks the whole `nixos-system` closure.

Solaar 1.1.20 mocks libnotify in its tests, which resolves this. The backport to `nixos-26.05` is tracked in PR [NixOS/nixpkgs#574929](https://github.com/NixOS/nixpkgs/pull/574929).

Until the PR is merged and nixpkgs is updated, the flake pins a second nixpkgs input at the PR's head and overlays `solaar` from it:

**`flake.nix`:**

```nix
inputs.solaar-pr.url = "github:NixOS/nixpkgs/pull/574929/head";

outputs =
  { …, solaar-pr, }:
  let machine = import ./hosts/nixos/machine.nix; in
  {
    nixosConfigurations.${machine.neodots.hostname} = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit waterfox solaar-pr; };
      # …
    };
  };
```

**`hosts/nixos/default.nix`:**

```nix
{ config, pkgs, waterfox, solaar-pr, ... }:

let
  solaarFromPr = solaar-pr.legacyPackages.${pkgs.stdenv.hostPlatform.system}.solaar;
in
{
  nixpkgs.overlays = [
    (final: prev: { solaar = solaarFromPr; })
  ];
  # …
}
```

### Removal procedure (run when PR #574929 merges)

1. Delete `solaar-pr.url = "github:NixOS/nixpkgs/pull/574929/head";` from `inputs`.
2. Remove `solaar-pr,` from the `outputs` argument list.
3. In `specialArgs`, change `inherit waterfox solaar-pr;` to `inherit waterfox;`.
4. In `hosts/nixos/default.nix`, remove:
   - `solaar-pr` from the module's destructured argument list;
   - the entire `let solaarFromPr = …; in` block;
   - the entire `nixpkgs.overlays = [ … ];` block.
5. Re-lock and rebuild:

   ```
   nix flake lock --update-input nixpkgs
   nix flake check --no-build
   sudo nixos-rebuild switch --flake .#nixos
   ```

The overlay does not change Solaar's runtime behavior; it only skips the sandbox test failure. Removing it has no effect on the installed binary beyond which nixpkgs revision supplies the derivation.

## Decision log

### 2026-10-16

- The flake is the single source of truth for language toolchains. No project carries a `shell.nix`.
- `devShells.<system>.{cpp,qt,rust,python,asm}` are the only entry points. Additional languages get additional `devShells.<system>` entries, not a new flake or a new template outside `templates/`.
- Templates are minimal (`.envrc` + `.clangd` for C-family, `.envrc` for others). Project files are not pre-populated; the three-command setup is the accepted cost for a general template.
- `nix-direnv` is enabled in both HM users. Without it, `direnv allow` on `qt` is slow enough that developers avoid it; with it, activation is invisible.
- `CC=clang` and `CXX=clang++` are exported by the `cpp` and `qt` shells to keep CMake's compiler aligned with clangd's parse.
- `CMAKE_EXPORT_COMPILE_COMMANDS=1` is exported by the `cpp` and `qt` shells; clangd is pointed at the resulting database with a per-project `.clangd`.
- `mutableExtensionsDir = false` is the fix for the VS Code extension-pack `package.json` error. It is a configuration requirement, not a bug to route around.
- Marketplace extensions and nixpkgs extensions are combined in a single `profiles.default.extensions` list. The marketplace list remains the escape hatch for tools not packaged in nixpkgs.
- The `13xforever` assembly extension is pulled out of the `with pkgs.vscode-extensions; …` block into an explicit `[ pkgs.vscode-extensions."13xforever"."language-x86-64-assembly" ]` list because publishers starting with a digit are not valid identifiers and cannot be resolved by `with`.
- `pkgs.qt6.full` is replaced by `qt6.env "name" [modules…]`. The `env` form is the supported replacement in nixpkgs and produces a merged prefix suitable for `mkShell`.
- The solaar workaround is temporary. Its removal is documented above and should be executed when PR #574929 merges into `nixos-26.05`. The overlay is intentionally scoped to `hosts/nixos/default.nix` so it is easy to delete.

## Known limitations

These are deferred concerns, not defects:

- **No automatic `cmake -B build` invocation.** clangd has no compilation database until the developer runs CMake once. This is a property of CMake, not of the workflow; the same is true on any OS. A future `direnv` `shellHook` could attempt `cmake -B build -S .` automatically when `build/` does not exist, but this is fragile for projects using other build systems and is not planned.
- **No pinned Python interpreter packages in the shell.** The `python` devShell is intentionally generic. Projects needing reproducible dependencies must use a `pyproject.toml` + `venv` (standard Python practice) or add a `python.withPackages` shell for the specific project.
- **No pre-installed `pyright` in the shell.** `pylance` (the VS Code extension) bundles its own analysis engine, so no external pyright is needed for editor integration. CLI usage requires installing `pyright` in the shell or running `npx pyright`.
- **The Qt extension (`theqtcompany.qt-cpp-pack`) is not installed.** Qt's official VS Code extension is not packaged in nixpkgs. `clangd` + the `qt` devShell provides equivalent functionality for the C++ side; Designer integration is not available from the editor. Projects that need Designer should launch `designer` from the shell or use `qtcreator`.
- **`ms-vscode.cpptools-extension-pack` and `vscode-clangd` coexist.** Their IntelliSense engines can conflict if both are active. Setting `C_Cpp.intelliSenseEngine` to `"disabled"` per-workspace is the recommended fix; the current config leaves this as a per-project choice.
- **No flake-check integration test.** `nix flake check` verifies that each shell evaluates and each template path exists, but does not build a project end-to-end. A future addition could add a `checks.<system>.cpp-build` derivation that runs a hello-world CMake project in the `cpp` shell and asserts the binary runs. This is deferred because it adds build time to every `nix flake check` invocation.
- **`set mouse` in nano is a shell-agnostic change.** It applies to nano in every terminal (Alacritty, kitty, VS Code integrated terminal), not only under tmux. This is intentional; nano's mouse-mode default is off for historical reasons, and enabling it does not degrade keyboard use.

## References

- Nix `mkShell` / devShells:
  https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-mkShell
- Flake templates:
  https://nixos.wiki/wiki/Flakes#Templates
- `nix-direnv`:
  https://github.com/nix-community/nix-direnv
- direnv:
  https://direnv.net/
- clangd — compilation database:
  https://clangd.llvm.org/design/compile-commands
- clangd configuration (`.clangd`):
  https://clangd.llvm.org/config
- CMake `CMAKE_EXPORT_COMPILE_COMMANDS`:
  https://cmake.org/cmake/help/latest/variable/CMAKE_EXPORT_COMPILE_COMMANDS.html
- Qt6 `qt6.env`:
  https://nixos.org/manual/nixpkgs/stable/#qt
- Home Manager `programs.vscode`:
  https://nix-community.github.io/home-manager/options.xhtml#opt-programs.vscode.enable
- Home Manager `programs.direnv`:
  https://nix-community.github.io/home-manager/options.xhtml#opt-programs.direnv.enable
- Nixpkgs PR #574929 (solaar test fix backport):
  https://github.com/NixOS/nixpkgs/pull/574929