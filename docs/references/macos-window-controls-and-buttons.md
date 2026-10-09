# Apple HIG reference: buttons and macOS window controls

**Local reference updated:** 9 October 2026  
**Primary source:** Apple, [Buttons — Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/buttons)  
**Related source:** Apple, [Windows — Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/windows)  
**Visual reference:** NameThatUI, [Traffic Lights (Window Controls)](https://namethatui.com/macos/traffic-lights)

This file is a concise, locally maintained design summary for Neodots. It is not a verbatim mirror of Apple's copyrighted guideline page; consult the linked source for the complete and current guidance.

## Button design notes

- A control should communicate its action through a familiar symbol, a concise label, or both. Do not rely on color alone to explain what a button does.
- Keep related controls visually coherent. Their size, spacing, shape, and hover/pressed states should make them feel like one set.
- Give custom controls visible interaction feedback, including a pressed state. Add a tooltip or another accessible name when the symbol alone may not be sufficient.
- Make the clickable area more generous than the visible icon where possible. Apple's general button guidance recommends a 44-by-44-point hit region; compact, platform-native window-frame controls are a specialized case, but their hit targets should still be forgiving.
- Use semantic roles carefully. A destructive action such as closing a window should be recognizable and should not be made ambiguous by decorative styling.
- Prefer system-provided window frames and controls where the platform provides them. Custom controls on other platforms should preserve familiar semantics rather than copying appearance while changing the action.

## macOS traffic-light semantics

The controls belong together at the leading edge of a window's title-bar area:

1. **Red — Close.** Request that the focused window close. Closing a window is not the same as explicitly quitting the application.
2. **Yellow — Minimize.** Temporarily remove the window from the visible workspace without closing it; retain a way to bring it back, such as activating its Dock entry.
3. **Green — Zoom/full screen.** On macOS, this is the zoom/full-screen control and exposes the system's window-arrangement behavior. For Neodots on River/KWM, the green control is adapted to toggle the KWM maximize state rather than claim to implement Apple's full-screen menu.

The NameThatUI reference calls out the standard close, minimize, and zoom controls and notes that their glyphs appear when the pointer hovers over the group. The Neodots treatment follows that cue with compact red/yellow/green circles, small hover glyphs, and larger invisible click targets.

## Neodots implementation contract

- Red sends KWM's existing close action to the active window.
- Yellow moves the window to a reserved, normally invisible KWM tag while retaining its original tag, then focuses another visible window. Activating the running app from the Dock requests focus and restores the saved tag.
- Green toggles KWM's maximize state.
- These are window actions, not floating/tiled shortcuts. Floating remains available separately through the window manager's keyboard binding.
- The top bar is a Quickshell surface rather than a native per-window title bar, so these controls act on the currently active toplevel.

## Sources and attribution

- Apple Developer, *Buttons*, Human Interface Guidelines: <https://developer.apple.com/design/human-interface-guidelines/buttons>
- Apple Developer, *Windows*, Human Interface Guidelines: <https://developer.apple.com/design/human-interface-guidelines/windows>
- NameThatUI, *Traffic Lights (Window Controls)*: <https://namethatui.com/macos/traffic-lights>

Source pages checked on 9 October 2026. Apple's online guideline is dynamically rendered and may change; use the official page as the authoritative source.
