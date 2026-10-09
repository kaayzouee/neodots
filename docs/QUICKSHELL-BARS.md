# Neodots Quickshell Bars

## Status

This document is the persistent design memory and implementation roadmap for the Quickshell top and bottom bars on the `feat/river-wayland` branch.

Current state: Phase 3 shell content and interaction foundation implemented. The current branch also contains the visual geometry contract, curated icon assets, menu/control-center interactions, battery/network/audio state handling, runtime crash hardening, and the first round of live-session fixes. Backdrop capture, true Liquid Glass rendering, notifications/media controls, and screenshot regression tests remain deferred.

## Repository review

The `feat/river-wayland` branch already has the right ownership boundaries for a Quickshell shell:

- `hosts/nixos/river-home.nix` is the Home Manager configuration for the dedicated `river` user.
- `quickshell` is already in that user's `home.packages`.
- `.config/river/init` currently launches `kwm`, so the shell should be started alongside KWM rather than replacing the existing River startup model.
- `config/kwm/config.zon` has KWM's built-in bar disabled with `.bar.show_default = false`. This is the correct starting point: KWM remains the window-management layer and Quickshell owns the visual shell.
- `modules/system/packages.nix` owns system package selection and already includes the custom River/KWM derivations.
- `packages/river/` and `packages/kwm/` own custom derivations. The Quickshell UI should not become a custom package unless we later need a pinned or patched Quickshell build.
- `docs/` already contains roadmap-oriented documents, so this project keeps its design memory in `docs/` instead of creating another configuration framework.

### Initial configuration ownership

Use this boundary:

```
hosts/nixos/river-home.nix
  └── installs / enables Quickshell
       └── .config/quickshell/neodots/
            ├── shell.qml
            ├── BarConfig.qml
            ├── components/
            ├── services/
            └── shaders/
```

KWM remains responsible for window management and its own IPC/configuration. Quickshell is responsible for the user-facing top and bottom shell.

## Target

Build two persistent Wayland layer-shell surfaces:

1. Top bar: macOS/Tahoe-inspired menu/status chrome.
2. Bottom bar: macOS/Tahoe-inspired floating Dock.

The target is not pixel-perfect cloning of Apple's private implementation. We should reproduce the visible design language with explicit, tunable geometry and a reusable glass material.

## Design principles

### 1. Geometry first

The shape must be a first-class component rather than an incidental `Rectangle.radius`.

The Dock should use a continuous-corner/superellipse-like signed distance function (SDF) so the same geometry can drive:

- clipping/masking
- glass edge falloff
- shadow
- rim light
- refraction strength near the edge

Conceptual superellipse:

`(|x|/a)^n + (|y|/b)^n = 1`

Treat `n`, corner radius, thickness, and inset as tunable parameters. Do not claim these values are Apple's exact private constants.

### 2. Separate shell surface from glass material

Keep these layers separate:

```
PanelWindow
  └── GlassSurface
       ├── shape/SDF
       ├── backdrop
       ├── border/highlight
       └── content
```

This allows the top bar and Dock to share the same material while using different geometry.

### 3. Prefer compositor-native behavior where available

Quickshell `PanelWindow` is backed by Wayland layer-shell and can be anchored and given margins/exclusive zones. `WlrLayershell` exposes the layer and namespace controls. citehttps://quickshell.org/docs/v0.3.0/types/Quickshell/PanelWindow/

Use these primitives for placement and input instead of absolute screen coordinates.

### 4. Avoid global screen blur

The first glass implementation should keep the capture/blur region as small as possible.

Quickshell 0.3.0 provides `ScreencopyView` for monitor/toplevel capture, but it is a capture primitive, not a documented "pixels behind this layer surface" primitive. That means a desktop-backdrop glass implementation may require careful handling of capture recursion and compositor support. citehttps://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/ScreencopyView/

Therefore:

- first ship a geometry/material prototype with a plain translucent background;
- then add backdrop capture;
- then add blur/refraction;
- keep a non-capture fallback.

### 5. Use Quickshell/QML as the integration layer

Quickshell is available as a Nixpkgs package and its documented `PanelWindow` is the natural primitive for bars. citehttps://quickshell.org/docs/v0.3.0/guide/install-setup/

Do not add a custom C++ renderer unless the QML/scenegraph implementation demonstrates a concrete limitation.

## Desired UI structure

### Top bar

Initial conceptual layout:

```
┌───────────────────────────────────────────────────────────────┐
│  system/menu     focused app               status / clock     │
└───────────────────────────────────────────────────────────────┘
```

But visually, avoid turning the entire screen edge into one giant opaque rounded rectangle. Prefer small grouped glass surfaces and transparent space where the reference design calls for it.

Initial responsibilities:

- launcher/system menu
- focused application title
- workspace/tag indicator
- network
- audio
- battery/power
- clock
- notification/control-center entry point

The first milestone only needs static layout and real clock/workspace data.

### Bottom Dock

Initial conceptual layout:

```
                    ╭──────────────────────╮
                    │  ● ● ● ● ● ● ●      │
                    ╰──────────────────────╯
```

Responsibilities:

- pinned applications
- running applications
- active indicator
- separator/grouping
- hover magnification
- click-to-launch/focus
- optional trash/downloads later

The first milestone should deliberately omit complicated Dock behaviors such as drag-to-reorder, download stacks, and minimize previews.

## Quickshell architecture

Planned structure:

```
.config/quickshell/neodots/
├── shell.qml
├── BarConfig.qml
├── BarConfig.qml
├── TopBar.qml
├── Dock.qml
├── shell.qml
├── components/
│   ├── ApplicationMenu.qml
│   ├── ControlCenter.qml
│   ├── DockIcon.qml
│   ├── GlassSurface.qml
│   ├── Superellipse.qml
│   └── SystemMenu.qml
├── services/
│   ├── AppCatalog.qml
│   ├── SystemState.qml
│   └── qmldir
└── assets/
    └── icons/
        └── mactahoe/
```

Keep `shell.qml` thin. It should instantiate one top/bottom bar pair per screen and leave data/services to separate objects.

## Multi-monitor rules

Every screen gets its own bar instances.

Do not assume:

- one screen;
- `Quickshell.screens[0]`;
- identical scale factors;
- identical physical sizes.

Panel geometry should use the target screen's dimensions and device scale.

The Dock and top bar should therefore be components parameterized by their screen.

## Layer-shell rules

Initial rules:

- Top bar: top-anchored `PanelWindow`.
- Dock: bottom-anchored `PanelWindow`.
- Keep focus disabled unless a popup explicitly needs keyboard focus.
- Use a namespace for each surface so compositor/debug tools can distinguish them.
- Use the layer-shell exclusion zone so tiled windows respect the shell while the visual surface remains floating inside its reserved region. Quickshell's automatic exclusion mode derives the reserved amount from the anchored panel dimensions and margins. citehttps://quickshell.org/docs/v0.3.0/types/Quickshell/PanelWindow/

KWM currently hides its own bar, so there should be no competing bar reservation/rendering path.

## Startup strategy

The Quickshell source tree is recursively linked by Home Manager into
`~/.config/quickshell/neodots/`, so the config is present on the actual user's
home directory rather than only existing in the repository.

The shell itself is owned by the user-level `neodots-quickshell.service`.
The service runs `qs -c neodots` and restarts it if the process exits.

River remains responsible for session startup and KWM remains the window manager.
The generated `.config/river/init` imports the live Wayland/session variables into
the user systemd manager, starts `neodots-quickshell.service`, and then `exec`s KWM.

This keeps the two processes isolated:

```
River session
  ├── user-systemd managed Quickshell
  │    └── qs -c neodots
  └── exec kwm
       └── window management
```

Restarting or crashing Quickshell therefore cannot terminate KWM or the River session.

## Reference split: shell structure vs. glass material

The project uses two different reference sources for two different concerns:

- **Tahoe/macOS shell structure:** use `lestercorderomurillo/macos-tahoe-liquid-kde` as the behavioral and layout reference for the menu bar, Dock grouping, app identity, running-app indicators, popovers, and future global-menu work.
- **Liquid Glass rendering:** use `ryohsuke1231/liquid-glass` as the material/rendering reference. Relevant ideas include separating the glass renderer from shell widgets, bounded backdrop capture, downsample/blur processing, tint and tone controls, edge-aware distortion, and frame/geometry synchronization.
- These repositories are references, not dependencies. Port concepts to Quickshell/River instead of copying compositor-specific GNOME/KDE implementations.

The River/Quickshell implementation must preserve a cheap fallback:

```
backdrop/material renderer unavailable
        ↓
translucent fill + border + highlight + shadow
```

The split is intentional: Tahoe informs **what the shell does and how it is arranged**; `liquid-glass` informs **how the material is rendered**.

## Glass implementation roadmap

### Phase 0 — Planning and visual contract

- [x] Review repository structure.
- [x] Decide Quickshell owns the visual shell.
- [x] Keep KWM's built-in bar disabled.
- [x] Create this design-memory document.
- [ ] Collect visual references for the exact desired top bar and Dock.
- [x] Define initial geometry tokens.
- [x] Define the Dock height as `screen.height / 14.75`.
- [x] Define the floating bottom gap as the active indicator diameter.

Suggested initial tokens:

```
topBarHeight
topBarInset
dockHeight
dockBottomInset
dockHorizontalPadding
dockCornerExponent
dockCornerRadius
glassTint
glassOpacity
glassBorderOpacity
glassHighlightOpacity
shadowOpacity
```

### Phase 1 — Minimal Quickshell shell

Goal: prove the shell integrates cleanly with River.

- [x] Create `.config/quickshell/neodots/shell.qml`.
- [x] Create top and bottom `PanelWindow` components.
- [x] Render simple opaque/translucent surfaces first.
- [x] Instantiate per output/screen.
- [x] Install the Quickshell config tree through Home Manager.
- [x] Start Quickshell from the River session through user systemd.
- [ ] Verify reload/restart behavior in a live River session.
- [ ] Verify that closing/restarting Quickshell does not kill KWM in a live session.

Acceptance:

- River + KWM works unchanged.
- Top and bottom bars appear on every screen.
- No duplicate KWM bar appears.
- Bars do not steal keyboard focus.

### Phase 2 — Geometry system

Goal: make the shapes correct before adding expensive rendering.

- [x] Implement reusable Dock superellipse geometry.
- [x] Implement top-bar capsule/group geometry.
- [ ] Add clipping/masks.
- [x] Add shadow and edge highlight.
- [ ] Test geometry at different sizes and DPRs.
- [ ] Tune against reference screenshots.

Acceptance:

- Dock corners look continuous rather than circular-cornered.
- Geometry remains stable while icons resize.
- No clipping artifacts at high scale factors.

### Phase 3 — Content and interactions

Top bar:

- [x] clock/date
- [x] focused application identity
- [x] Apple-menu-equivalent system launcher/menu
- [x] network status
- [x] audio status
- [x] battery status
- [x] Control Center-equivalent popover
- [x] workspace/tag state is polled from River with `riverctl list-tags`; it is available to the shell for future Spaces/Mission-Control UI, but is intentionally not placed into the primary menu-bar row.

Dock:

- [x] curated application set
- [x] macOS-role-equivalent application mapping
- [x] running state
- [x] active state
- [x] click-to-launch
- [x] Downloads utility
- [x] Trash utility
- [x] hover labels
- [x] hover magnification
- [x] activate a running app instead of launching a duplicate
- [x] launch bounce animation

Keep service polling/event handling separate from visual components.

### Phase 4 — Glass material

Start with a fake/cheap material:

- [ ] translucent tint
- [ ] subtle border
- [ ] highlight
- [ ] shadow
- [ ] brightness/contrast adjustment

Then:

- [ ] backdrop capture
- [ ] downsample
- [ ] blur
- [ ] refraction
- [ ] chromatic aberration
- [ ] edge/rim lighting

Do not start by implementing every Liquid Glass feature at once.

### Phase 5 — Backdrop and performance

- [ ] Determine how `ScreencopyView` behaves with River/KWM and layer-shell surfaces.
- [ ] Avoid capture feedback.
- [ ] Keep capture ROI restricted to each glass surface.
- [ ] Reuse blurred textures when several surfaces share a backdrop.
- [ ] Avoid recreating textures during simple animations.
- [ ] Measure GPU/CPU cost before adding further effects.

Important fallback:

```
full glass renderer unavailable
        ↓
translucent + border + shadow
```

The bar must remain usable without the expensive effect.

### Phase 6 — Polish

- [x] hover/magnification animation
- [x] popup menus
- [x] control center
- [ ] notifications
- [ ] media controls
- [ ] autohide behavior
- [ ] fullscreen behavior
- [ ] accessibility/reduced transparency option
- [ ] configuration through Nix
- [ ] screenshot-based visual regression checks


## Icon system roadmap

Goal: remove the current icon-theme warnings and make the Dock consistently macOS-like without coupling it to one incomplete theme.

Preferred resolution order:

```
installed desktop-entry icon
        ↓
MacTahoe-compatible icon theme
        ↓
hicolor / Adwaita fallback
        ↓
small Neodots-owned fallback SVG
```

The target icon aesthetic is **macOS Tahoe-like**, so MacTahoe is the preferred theme reference. Do not bundle proprietary Apple assets.

- [x] Add a pinned MacTahoe-derived icon subset to the Quickshell tree instead of changing the whole desktop theme.
- [x] Keep the icon asset source pinned to the 2026-09-10 upstream release (`839848b`).
- [x] Verify Quickshell's missing-icon-safe fallback path with `Quickshell.iconPath(..., true)`.
- [x] Stop using arbitrary icon names as the primary fallback for system utilities.
- [x] Give Downloads, Trash, Apps, and the curated applications direct MacTahoe assets.
- [x] Keep `DesktopEntries` for application launch/metadata while decoupling Dock appearance from desktop-entry icon availability.
- [x] Record the icon source and GPL-3.0-only attribution in the repository.
- [ ] Verify the absence of icon warnings in a live River session after rebuilding/restarting Quickshell.
- [ ] Keep application-specific branding assets out of the repository unless their license/redistribution terms are explicit.

Acceptance:

- No theme-name lookup is required for the curated Dock icons.
- The Dock has a coherent Tahoe-like icon style from a pinned MacTahoe subset.
- Missing system theme icons cannot produce Quickshell's purple/missing-texture fallback for the curated Dock items.
- Application launching still works independently of icon availability.

## Nix integration roadmap

The first implementation should not create a new Nix package.

Preferred ownership:

```
hosts/nixos/river-home.nix
  ├── home.packages = [ quickshell ... ]
  └── home.file.".config/quickshell/neodots/..."
```

Only introduce a custom package if one of these becomes necessary:

- pinned Quickshell version independent of nixpkgs;
- custom Quickshell patch;
- custom shader/build artifact pipeline;
- a reusable package consumed outside this host.

The existing `packages/` layout is intended for derivations, while Home Manager configuration remains with the Home Manager owner.

## Configuration strategy

Keep user-tunable values in one QML configuration object first:

```
BarConfig.qml
```

Later, migrate stable machine/user values into Nix-generated configuration if useful.

Do not hard-code:

- a username other than the existing Home Manager owner;
- a single monitor index;
- a fixed resolution;
- wallpaper-specific coordinates.

## Known technical risks

### Backdrop capture

Quickshell's `ScreencopyView` can capture a monitor or supported toplevel, but the documented API does not promise arbitrary exclusion of the Quickshell layer itself. citehttps://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/ScreencopyView/

This is the largest risk for a true desktop Liquid Glass effect.

### Blur cost

Blur and backdrop effects can become the dominant GPU cost if the source area is too large. The initial renderer should always operate on bounded regions.

### Multiple screens

Each screen can have different scale/geometry. Do not build the layout around one global coordinate system.

### Quickshell churn

Quickshell 0.x is still pre-1.0 and documents that breaking changes will occur, so keep the shell implementation small and isolated from the rest of the NixOS configuration. citeturn699539search13

## Existing reference implementations

These are references, not dependencies:

- Quickshell 0.3.0 `PanelWindow`: https://quickshell.org/docs/v0.3.0/types/Quickshell/PanelWindow/
- Quickshell 0.3.0 `WlrLayershell`: https://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/WlrLayershell/
- Quickshell 0.3.0 `ScreencopyView`: https://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/ScreencopyView/
- Quickshell installation/setup: https://quickshell.org/docs/v0.3.0/guide/install-setup/
- Existing Quickshell macOS Dock reference: https://github.com/vzbc/revo-shell/tree/62e13cd38588c3cdbef5613d088b9c4a265b965b/quickshell/macos
- Tahoe/KDE shell structure reference: https://github.com/lestercorderomurillo/macos-tahoe-liquid-kde
- Liquid Glass renderer reference: https://github.com/ryohsuke1231/liquid-glass
- MacTahoe icon theme: https://github.com/vinceliuice/MacTahoe-icon-theme
- Apple Liquid Glass materials guidance: https://developer.apple.com/design/human-interface-guidelines/materials

## Decision log

### 2026-10-08

- Quickshell is the shell/UI layer for the River branch.
- Phase 1 bars are implemented as the actual `PanelWindow` delegates; `shell.qml` does not wrap them in another window.
- The top bar and Dock use `ExclusionMode.Auto` so River/KWM can keep tiled windows out of the reserved shell regions while the visual surfaces remain inset and floating.
- KWM's built-in bar remains disabled.
- The first implementation is QML-only.
- The Quickshell source tree is installed declaratively by Home Manager.
- User systemd supervises the Quickshell process; River owns session startup ordering.
- The Dock gets reusable continuous-corner/SDF geometry.
- The top bar and Dock share a glass material API.
- Desktop backdrop capture is deferred until the basic shell works.
- Tahoe/KDE is the structure/interaction reference; `ryohsuke1231/liquid-glass` is the material/rendering reference.
- The icon plan is a pinned MacTahoe subset for deterministic Dock rendering, with `Quickshell.iconPath(..., true)` as the safe fallback for any future uncatalogued item.
- No custom Quickshell package is planned initially.
- This document is the source of truth for the bar project and should be updated when architecture decisions change.


## Phase 2 geometry notes

The current geometry implementation lives in:

```
config/quickshell/neodots/
├── BarConfig.qml
└── components/
    ├── Superellipse.qml
    └── GlassSurface.qml
```

`Superellipse.qml` samples each corner using the parametric superellipse relation:

`x = sign(cos(t)) |cos(t)|^(2/n)`
`y = sign(sin(t)) |sin(t)|^(2/n)`

The sampled points are assembled into a closed SVG path and rendered through `QtQuick.Shapes`. Qt Quick Shapes supports filled and stroked paths and renders the resulting geometry through the Qt Quick scene graph. [Qt Quick Shapes / ShapePath](https://doc.qt.io/qt-6/qml-qtquick-shapes-shapepath.html)

The shared `GlassSurface` deliberately does not use a custom fragment shader yet. Qt 6's ShaderEffect path expects preprocessed `.qsb` shader packages, so the shader backend will be introduced when we actually need backdrop/material processing rather than during the geometry-only phase. [Qt Quick Shader Effects](https://doc.qt.io/qt-6/qtquick-shadereffects-example.html) and [QShaderBaker](https://doc.qt.io/qt-6/qshaderbaker.html)


## Public macOS placement map

The content model follows Apple's current desktop documentation rather than a generic Linux status-bar layout.

### Top menu bar

Apple documents the menu bar as:

```
left
[Apple menu] [active app name + app menus]
                                  right
                    [status menus] [Control Center] [date/time]
```

The Apple Support guide states that the Apple menu and active application's menus are on the left. Status menus, Spotlight, privacy indicators, Control Center, and Notification Center/date-time occupy the right side. [Get to know your desktop, menu bar, and Dock](https://support.apple.com/guide/mac-help/desktop-menu-bar-and-dock-mchlws12345m2/mac) and [What's in the menu bar on Mac?](https://support.apple.com/en-sg/guide/mac-help/mchlp1446/mac).

The implementation follows that ordering:

- The Neodots snowflake is the Apple-menu role: system commands and launchers.
- The focused Wayland toplevel supplies the active application identity.
- The menu labels sit immediately after the active application.
- Network, audio, battery, Control Center, and date/time are grouped on the far right.

The Control Center role is based on Apple's current Control Center: Wi-Fi, Focus, sound, media, AirDrop, screen mirroring, and related settings are part of that system area. The current Phase 3 implementation starts with network, sound, and battery because those data sources are already reliable on this machine. [Use Control Center on Mac](https://support.apple.com/guide/mac-help/quickly-change-settings-mchl50f94f8f/mac).

### Dock

Apple documents the Dock as the place for frequently used applications, with a separator dividing pinned applications from recently used items; Downloads and Trash belong on the utility side. [Get to know your desktop, menu bar, and Dock](https://support.apple.com/guide/mac-help/desktop-menu-bar-and-dock-mchlws12345m2/mac) and [Use the Dock on Mac](https://support.apple.com/en-vn/guide/mac-help/mh35859/mac).

The Neodots Dock therefore uses this order:

```
[app icons ...] | [Downloads] [Trash]
```

The first-party macOS roles are mapped to programs already present in this NixOS profile:

| macOS role | Neodots application | Reason |
|---|---|---|
| Finder | Thunar | file manager / files |
| Safari | Waterfox | web browser |
| Terminal | Alacritty | terminal |
| Music | Spotify | music player |
| Messages | Vesktop | desktop messaging/chat |
| Photos | GIMP | image/photo editing |
| Launchpad / Apps | Fuzzel | application launcher |

This mapping is intentionally role-based. The icons should represent the same *job* as their macOS counterparts rather than merely picking visually similar Linux programs.

Quickshell's `DesktopEntries` API supplies application metadata and parsed launch commands, so the Dock can use the installed desktop entry for the icon and launch action instead of hard-coding every executable path. [Quickshell DesktopEntries](https://quickshell.org/docs/v0.3.0/types/Quickshell/DesktopEntries/) and [Quickshell DesktopEntry](https://quickshell.org/docs/v0.3.0/types/Quickshell/DesktopEntry/).

### Window/workspace data

River tags are read directly with `riverctl list-tags` in the Phase 3 service.
This keeps workspace state tied to the compositor's native tag model without
depending on the typed `WindowManager.Windowset` QML API, which produced lint
diagnostics on the active Quickshell version. The normalized tag state remains
available for a later Mission Control / Spaces-style UI.

## Phase 3 implementation map

```
services/
├── AppCatalog.qml     role-based macOS ↔ Linux application mapping
└── SystemState.qml    clock, active app, workspaces, network, volume, battery

components/
├── DockIcon.qml       app icon, launch, active/running dot, hover label
├── SystemMenu.qml     Apple-menu-equivalent system actions
└── ControlCenter.qml  top-right system status popover

bars/
├── TopBar.qml
└── Dock.qml
```

The current implementation uses Quickshell data providers where they are useful and small external status commands for NetworkManager/PipeWire state. This keeps the dependency surface compatible with the existing NixOS profile while still making the QML data model reactive.


## Icon implementation notes

The Dock does not install the complete MacTahoe theme system-wide. Instead, it vendors a small GPL-3.0-only subset from upstream commit `839848b` under `config/quickshell/neodots/assets/icons/mactahoe/`. This keeps Quickshell deterministic and avoids coupling the shell to whichever Qt/GTK icon theme happens to be active.

For curated Dock entries, the icon source is explicit and always available from the shell tree. For any future uncatalogued entry, `Quickshell.iconPath(name, true)` returns an empty source when the theme lacks the icon rather than requesting a missing texture. Quickshell documents the `check` variant specifically for this purpose. 


## Menu bar geometry

The top bar is deliberately **screen-spanning** rather than a centered capsule. On a 2880×1800 display, the layer-shell panel therefore occupies the full 2880-pixel output width.

The content follows the macOS menu-bar split:

```
[ system ] | [ active app ] | [ File | Edit | View | Window | Help ]
                                                                [ network | audio | battery | control center | date/time ]
```

The top bar uses a very low-opacity full-width surface, subtle vertical separators, and small hover capsules around individual controls. Apple documents the same left/right organization: Apple and app menus on the left, status menus on the right, with Control Center and date/time at the far right. citehttps://support.apple.com/guide/mac-help/desktop-menu-bar-and-dock-mchlws12345m2/mac

The Dock remains a separate floating island.


### Dock vertical geometry

The Dock surface height is proportional to the target monitor's height:

```
dockSurfaceHeight = screen.height / 14.75
```

For a 2880×1800 output:

```
1800 / 14.75 = 122.03 px
```

The surface is about 122 px tall on that reference output. The Dock geometry
below that surface is derived from its runtime height rather than fixed pixels:

- icon size is `dockSurfaceHeight * dockIconSizeRatio`;
- slot width is icon size plus proportional horizontal padding;
- icon-to-icon spacing is proportional to icon size;
- active/running indicator size is proportional to icon size;
- the gap between the Dock surface and the bottom of the screen equals the
  active/running indicator size;
- surface horizontal padding is proportional to icon size;
- the Dock width is the content's implicit width plus that proportional padding.

The current reference ratios live in `BarConfig.qml`. They are scale factors rather
than fixed pixel lengths, so the entire Dock grows/shrinks with monitor height and
its horizontal footprint grows/shrinks with the number of items it contains.

The phrase "1/14.75 of the monitor" is interpreted using the monitor **height**
because the requested 2880×1800 example uses 1800 for the calculation.

### Battery state

Battery percentage prefers the working /sys/class/power_supply/BAT* value when
available, with UPower retained as the fallback. The same source priority is
used for charging/discharging state so a stale or unavailable UPower state cannot
turn a discharging battery into "Power Adapter" in the shell.


### Bar corner rounding

Top bar and Dock corner radii share a single design target:

- corner ratio: 51% of the bar's height
- top bar radius: derived from `topSurfaceHeight`
- Dock radius: derived from `dockSurfaceHeight`

`Superellipse.effectiveRadius` caps the result at half of the shorter dimension, so the 51% target resolves to the maximum valid fully rounded radius without causing overlapping corner geometry.


# Implementation record

This section is the durable record of the decisions, bugs, fixes, and runtime observations that shaped the current implementation.

## 1. Final shell architecture

The shell is intentionally split into compositor-facing windows, reusable visual components, and status/data services.

```
shell.qml
  └── Quickshell.screens
       ├── TopBar.qml per screen
       └── Dock.qml per screen

TopBar.qml / Dock.qml
  └── GlassSurface
       ├── Superellipse geometry
       ├── border/highlight/shadow
       └── UI content

services/
  ├── AppCatalog.qml
  └── SystemState.qml
```

Important ownership rules:

- River owns the Wayland session.
- River's generated init applies a 175% output scale to every connected output with `wlr-randr` before launching KWM and Quickshell. The scale is configured at the compositor output layer rather than by changing KWM's master/stack layout ratio.
- KWM owns window management.
- KWM's built-in bar stays disabled.
- Quickshell owns the user-facing top bar and Dock.
- Home Manager installs the Quickshell tree into `~/.config/quickshell/neodots/`.
- A user systemd service supervises `qs -c neodots`.
- The generated River init imports Wayland/session variables, restarts the Quickshell service, then `exec`s KWM.
- Quickshell failures therefore do not become the window manager's process lifetime.

The actual UI files live at the root of the shell tree. The documentation's original `bars/` example was a planning sketch and should not be used as the current source of truth.

## 2. Top-bar design contract

The top bar is a full-width layer-shell panel, not a centered pill.

Current geometry:

- height: 50 px
- top inset: 0 px
- left/right inset: 0 px
- content padding is proportional to the 50 px surface height
- individual controls use a proportional 30 px control height
- separator height is proportional to the surface height
- the surface itself is translucent and low-opacity
- the Dock remains a separate floating island

Left-to-right content:

```
[system] | [active app] | [File] [Edit] [View] [Window] [Help]
                                                [Wi-Fi] [audio] [battery] | [Control Center] | [date/time]
```

The active application name comes from the focused Wayland toplevel and `DesktopEntries`. The implementation does not provide a true global appmenu backend; the visible File/Edit/View/Window/Help menus are explicit Neodots command menus that reproduce the placement and interaction model.

The right side is an Apple-inspired status-item collection rather than three hand-built status rectangles. The Control Center button uses a hand-drawn, translucent two-toggle symbol instead of a text glyph. Its width, track positions, track thickness, and knobs scale from the existing top-control height so it remains crisp and proportional. Each status item is content-sized, can be independently enabled, and supports either persistent visibility or `Show When Active` semantics.

Current command menu contents include:

- File: open Files, open Downloads, separator, new terminal.
- Edit: open NixOS configuration, open Neodots.
- View: applications launcher, focus next/previous.
- Window: focus next/previous, toggle fullscreen, zoom.
- Help: NixOS manual, Quickshell docs, Neodots repository.

## 3. Dock design contract

The Dock is a bottom-anchored floating layer-shell island.

Current geometry:

- surface height: `screen.height / 14.75`
- example at 2880×1800: ≈122 px
- bottom inset: the running-indicator diameter
- icon size: `dockSurfaceHeight * dockIconSizeRatio`
- icon slot width: icon size plus proportional slot padding
- icon slot height: the runtime Dock surface height
- icon-to-icon spacing: proportional to icon size
- surface horizontal padding: proportional to icon size
- Dock width: content-driven from the actual item widths plus proportional surface padding
- magnification scale: 1.42
- magnification spread: 2.6
- animation duration: 140 ms

The icon, slot, spacing, indicator, and surface padding all scale from the runtime Dock height/icon size. The utility icons (Downloads and Trash) use the same centered runtime geometry as application icons. The running indicator is outside the magnified visual layer so magnification does not change its baseline or move neighboring items.

The Dock order is:

```
[Finder-role] [Safari-role] [Terminal] [Music] [Messages] [Photos] [Launchpad] | [Downloads] [Trash]
```

The actual Linux applications are:

| Role | Application |
|---|---|
| Finder | Thunar |
| Safari | Waterfox |
| Terminal | Alacritty |
| Music | Spotify / G4Music role |
| Messages | Vesktop |
| Photos | GIMP |
| Launchpad | Fuzzel |

The mapping is deliberately role-based rather than a literal Apple application dependency.

## 4. The 51% corner rule

Bar corners use a single shared design token:

`barCornerRatio = 0.51`

The radii are derived from the surface height:

```
topCornerRadius  = topSurfaceHeight  * 0.51
dockCornerRadius = dockSurfaceHeight * 0.51
```

This is a design target, not a claim about Apple's private implementation.

`Superellipse.qml` clamps the effective radius to half of the shorter dimension. This means the 51% target remains geometrically valid even when the calculated radius would otherwise exceed the maximum continuous-corner radius.

The Dock and top bar therefore share the same corner-language instead of independently tuned numbers.

## 5. Superellipse and glass implementation

`Superellipse.qml` samples a parametric superellipse for each corner and assembles the result into a closed SVG path rendered through Qt Quick Shapes.

Current exponent:

- 4.0 for the shared bar geometry.

`GlassSurface.qml` currently provides:

- translucent fill
- border
- subtle inner highlight
- cheap offset shadow
- shared corner geometry

It deliberately does not perform backdrop capture, blur, refraction, chromatic aberration, or a custom fragment-shader material yet.

The expensive Liquid Glass path remains a later phase. The required fallback is always:

```
advanced material unavailable
        ↓
translucent fill + border + highlight + shadow
```

## 6. Curated icon implementation

The Dock uses a pinned, vendored subset of the MacTahoe icon theme instead of requiring a system-wide theme match.

Pinned upstream source:

- project: `vinceliuice/MacTahoe-icon-theme`
- upstream release date recorded for the project: 2026-09-10
- source commit: `839848b`
- license recorded in the repository: GPL-3.0-only

The curated local assets are:

- `Vesktop.svg`
- `alacritty.svg`
- `applications-system.svg`
- `file-manager.svg`
- `folder-download.svg`
- `g4music.svg`
- `gimp.svg`
- `user-trash.svg`
- `waterfox.svg`
- `NOTICE.md`

Do not add proprietary Apple assets.

A runtime path issue was found during testing:

- relative paths such as `../assets/...` could resolve through Quickshell's QML resource namespace (`qrc:/...`) instead of the user's live shell tree;
- `Quickshell.shellPath(...)` alone could also produce a `qrc:/home/...` source in the observed runtime;
- the working form is an explicit filesystem URL:
  `file://` + `Quickshell.shellPath("assets/icons/mactahoe/<asset>.svg")`.

This makes the curated icons deterministic and independent of the active desktop icon theme.

## 7. Application state and Dock behavior

`AppCatalog.qml` separates application launch/metadata from Dock appearance.

The Dock uses ToplevelManager matching by app-id patterns to determine:

- whether an application is running;
- whether it is active;
- which existing window should be activated;
- whether a launch is required.

Clicking a running application does not launch another copy.

Because Quickshell's generic Toplevel API does not expose River's native tag membership in the form needed here, activation uses a pragmatic River fallback:

1. focus the Dock's output;
2. probe River tags 1 through 9 with `riverctl set-focused-tags`;
3. ask the target to activate;
4. stop when the target becomes active;
5. as a final fallback, expose all tags with `4294967295` and activate the target.

This is an activation workaround, not a claim of native River tag introspection.

The Dock also supports:

- hover labels;
- hover magnification;
- active/running dots;
- launch-on-click;
- Downloads utility;
- Trash utility.

## 8. Top-bar popup architecture and crash fix

A significant runtime crash was traced to the application menu popup anchor.

Observed crash characteristics:

- Quickshell 0.3.0;
- Qt 6.11.2;
- SIGSEGV in the popup anchor/window update path;
- stack frames included `PopupAnchor::onItemWindowChanged()` and `PopupAnchor::setItem(QQuickItem*)`;
- the click path entered from a QML `MouseArea`;
- the final log warning reported an `undefined` value being assigned to a `QString` in `ApplicationMenu.qml`.

Root cause:

- the popup's anchor item was indirectly tied to a Repeater delegate;
- as the selected menu changed, the delegate could transiently switch between a live item and `null`;
- the popup anchor machinery could observe that unstable item lifetime.

The fix was to keep the popup permanently anchored to the stable `activeAppItem` and move the popup horizontally with an explicit `anchorX` calculation.

Current pattern:

```
anchorItem: activeAppItem
anchorX: applicationMenuAnchorX(openMenuIndex)
```

The delegate is only used to calculate the horizontal offset; it is never used as the popup's lifetime anchor.

The popup delegates were also hardened so optional model fields are safe:

- `separator` is checked through a boolean property;
- `label` falls back to an empty string;
- `command` is accessed safely.

This removed the transient null-anchor design that caused the reported crash.

## 9. Battery-state implementation and runtime observation

Battery handling is intentionally physical-battery-first rather than relying only on an aggregate power device.

Preferred source:

```
/sys/class/power_supply/BAT*
        ↓
UPower physical laptop battery
        ↓
UPower display/aggregate device
```

The QML logic prefers an actual UPower device where `isLaptopBattery` is true and keeps a sysfs fallback for percentage/state.

Observed runtime facts during debugging:

- the physical UPower device was identified as `A32-K55`;
- UPower exposed a raw percentage value of `0.44` in the observed session;
- the shell therefore normalizes raw values ≤1 to a 0–100 percentage representation;
- the physical battery state was `Discharging`;
- Fastfetch independently reported the same physical battery at 50% with about 2 h 14 min remaining in one live session.

The same source priority is used for charging/discharging state so an unavailable or stale aggregate state cannot turn a physically discharging battery into `Power Adapter`.

Displayed status text is derived from the same state source:

- Charging
- Battery Power
- Power Adapter

This prevents percentage and power-state indicators from disagreeing.

## 10. Control Center

The top-right Control Center popup is currently a real functional panel rather than a placeholder.

Current contents:

- Wi-Fi state and toggle through NetworkManager/`nmcli`;
- battery percentage, readiness, and status;
- sound volume percentage;
- mute toggle;
- direct volume click/drag;
- mouse wheel volume adjustment;
- network signal summary;
- River workspace/tag summary.

Current panel dimensions:

- width: 390 px
- height: 360 px

A layout warning was fixed by keeping the Wi-Fi `MouseArea` as a direct child of its card instead of placing it inside a `ColumnLayout` in a way that violated the active Quickshell layout rules.

## 11. Logo system menu

Clicking the left logo opens a content-sized system menu with the following order:

```
About this mark
────────────────────────
System Settings...
Location
App Store...
────────────────────────
Recent Items
────────────────────────
Force Quit...
────────────────────────
Sleep
Restart...
Shut Down...
────────────────────────
Lock Screen
Log out <current user>...
```

Actions are mapped to local equivalents for this NixOS setup: Fastfetch for system information, XFCE Settings, Thunar for the home location and recent items, the NixOS package search for the app-store role, XFCE Task Manager for force-quit, systemd power actions, Swaylock, and `riverctl exit` for logout. The logout label reads the current user's environment name.

Menu width and height follow the rendered labels and row content. Font size is the single typography base; row line-height is 115% of that size, while horizontal/vertical surface padding, item padding, separator blocks, corner radius, and the gap below the logo are all derived from font-size ratios. Avoid adding unrelated fixed-pixel gaps: tune the ratios instead.

## 12. SystemState responsibilities

`SystemState.qml` currently owns:

- clock/date formatting;
- active toplevel/app id/title;
- physical battery state and fallback battery reading;
- Wi-Fi enabled state;
- NetworkManager SSID and signal polling;
- PipeWire/WirePlumber volume and mute state;
- volume adjustment helpers;
- Wi-Fi toggle;
- River workspace/tag text.

Polling intervals currently include:

- network: 5 s;
- battery: 10 s;
- volume: 1 s;
- workspace/tag summary: 3 s.

The service layer intentionally contains polling and state access so visual components remain focused on presentation and interaction.

## 13. Validation and repository discipline

The implementation was initially developed as one feature commit above the
established base. Subsequent visual/runtime refinements are now kept as linear
commits on `feat/river-wayland`; do not rewrite branch history just to squash
follow-up work unless explicitly requested.

For live QML development, the user systemd layer also includes
`neodots-quickshell-watch.service`. It watches the live repository source tree
under `~/neodots/config/quickshell/neodots` with `inotifywait`, debounces editor
save bursts briefly, resets the Quickshell unit's failed state, and restarts the
shell. The Quickshell service itself has `StartLimitIntervalSec = 0`, so a bad
QML edit cannot permanently hit systemd's restart-rate ceiling; once the file is
fixed and saved, the watcher can restart the shell again immediately.

The project CI includes:

- Quickshell QML validation with `qmllint`;
- Format checks;
- NixOS evaluation/build checks.

The preferred local validation flow after pulling the branch is:

```bash
git fetch origin feat/river-wayland
git reset --hard origin/feat/river-wayland

sudo rsync -a \
  --exclude='.git/' \
  --exclude='.git*' \
  --exclude='hardware-configuration.nix' \
  ./ /etc/nixos/

sudo nixos-rebuild test --flake /etc/nixos#nixos
systemctl --user restart neodots-quickshell.service
```

For a focused live-session smoke test:

```bash
systemctl --user status neodots-quickshell.service
journalctl --user -u neodots-quickshell.service -n 200 --no-pager
```

A Quickshell crash report should be inspected under the user's Quickshell crash directory when a popup or QML binding regression is suspected.

## 14. Known limitations that are intentional

The current shell is a functional Tahoe-inspired implementation, not a full private macOS clone.

Known limitations:

- the top bar's File/Edit/View/Window/Help menus are static Neodots actions, not a true global application menu protocol;
- River tags are probed for activation rather than exposed through a dedicated typed River-tag API in QML;
- Liquid Glass backdrop capture is not implemented yet;
- no global blur/refraction/chromatic aberration pipeline exists yet;
- no media controls;
- no notification center;
- no Dock drag-to-reorder;
- no minimize-window previews;
- no autohide behavior;
- no reduced-transparency/accessibility switch;
- no screenshot-based visual regression suite;
- icon verification still needs an explicit live-session pass after future rebuilds;
- popup geometry and visual polish still need screenshot-level tuning across multiple scale factors.

These are deferred features, not reasons to complicate the current stable implementation.

## 15. Bottom Dock geometry rule

The bottom Dock now follows the explicit monitor-relative sizing contract requested
for the River/Quickshell implementation.

Formula:

```
Dock height = monitor height / 14.75
Dock bottom gap = active running-indicator diameter
```

Example:

```
monitor = 2880 × 1800
Dock height = 1800 / 14.75 ≈ 122.03 px
bottom gap = ≈5.23 px at the 2880×1800 reference output
```

The Dock's width is determined by its content, horizontal padding, and the
runtime item geometry. There is no fixed width cap; the monitor-relative rule
controls the **vertical size** because the reference example explicitly derives
the value from 1800.

### Top-bar proportional layout rule

The top bar follows the same principle as the Dock: the surface provides a scale,
while individual controls size themselves from their actual text/glyph content.

- control height is derived from `topSurfaceHeight`;
- horizontal control padding is proportional to `topSurfaceHeight`;
- menu/status control widths are `text.implicitWidth + proportional padding`;
- separators use proportional width/height;
- row/group spacing is proportional to `topSurfaceHeight`;
- no fixed control widths are used for the system, active-app, status, Control
  Center, or date/time items.

Changing the top-bar font or glyphs therefore changes the item's intrinsic width
without requiring manual width corrections elsewhere.

### Apple-inspired status item model

The right side now follows the same conceptual model documented by Apple for Menu Bar
controls: status items are an independent collection, users can choose which items
appear in the menu bar, and some controls can use `Show When Active` behavior rather
than being permanently present. Apple also keeps Control Center as a distinct surface
and the clock as the terminal right-side item. citehttps://support.apple.com/en-vn/guide/mac-help/mchlad96d366/mac

Neodots recreates those ideas without pretending to be a private macOS implementation:

```
RightSection
  ├── StatusItemCollection
  │    ├── Wi-Fi
  │    ├── audio
  │    └── battery
  ├── section boundary
  ├── Control Center
  └── date/time
```

Implementation rules:

- `components/StatusItem.qml` owns the shared visual and input contract for status
  controls.
- Width is derived from the rendered content's `implicitWidth` plus proportional
  horizontal padding.
- `BarConfig.qml` owns the status-item collection and each item's
  `visibilityMode`/enabled setting.
- `visibilityMode: "always"` keeps the item persistent.
- `visibilityMode: "active"` implements the Apple-style "Show When Active" model.
- Hidden items collapse to zero width so they do not leave phantom spacing in the
  status collection.
- Wi-Fi and battery open the existing Control Center; audio preserves click/drag and
  wheel volume interaction.
- Control Center is not modeled as a status item and date/time remains the
  right-most terminal item.

The default configuration intentionally keeps Wi-Fi, audio, and battery visible; the
new model adds configurability rather than removing any of the existing status
information.

## 16. Change history for the 2026-10-08 implementation

The implementation evolved through these concrete milestones:

1. established Quickshell as a dedicated River/KWM shell layer;
2. disabled the competing KWM default bar;
3. created full-width TopBar and floating Dock layer-shell surfaces;
4. introduced shared `GlassSurface` and `Superellipse` geometry;
5. added curated MacTahoe icons and deterministic filesystem URL loading;
6. added running/active Dock behavior and River tag activation fallback;
7. added NetworkManager, PipeWire, battery, clock, and workspace state;
8. added functional system menu and Control Center;
9. unified utility/icon vertical alignment around the shared runtime Dock icon geometry;
10. diagnosed and fixed the popup-anchor segmentation fault by stabilizing popup ownership around persistent anchors;
11. hardened popup model data against `undefined` values;
12. fixed battery percentage/state handling around the observed UPower/sysfs behavior;
13. unified top-bar and Dock corner geometry around the 51% bar-corner rule;
14. changed Dock height from a fixed pixel value to `screen.height / 14.75`;
15. replaced fixed Dock width, icon size, slot width, spacing, and bottom-gap pixels
    with proportions derived from runtime Dock height/icon size;
16. kept the Dock width content-driven so the island grows/shrinks with its actual
    contents;
17. scaled the running indicator and launch-bounce geometry from the same icon
    scale;
18. introduced a reusable `StatusItem.qml` component so menu-bar status controls
    size from their rendered content rather than hand-tuned rectangles;
19. modeled the top-right controls as a configurable status-item collection with
    `always` / `active` visibility semantics, a distinct Control Center boundary,
    and a terminal clock;
20. restored the Dock icon ratio to `5/7` of the runtime Dock height as the
    user-tunable default, keeping the Dock's scale entirely derived from the
    runtime surface height and this single design token.

This section is the project's implementation memory. Future changes that alter any of these invariants should update this document in the same change.
