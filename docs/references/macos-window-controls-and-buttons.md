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

- Waterfox's controls live in the browser's own title/tab bar. The shell no longer draws a second set of traffic lights in the global Quickshell bar.
- The CSS changes the appearance and placement of Waterfox's existing titlebar buttons; it does not replace their built-in commands.
- Red keeps Waterfox's native close-window command.
- Yellow uses Waterfox's native minimize request. KWM handles that request by moving the window to a reserved, normally invisible tag while retaining its original tag, then focuses another visible window. The Dock retains the path to reactivate and restore the minimized window.
- Green keeps Waterfox's native maximize/restore command, which KWM already handles.
- The buttons sit at the leading edge of the tab bar; horizontal space is reserved so tabs begin after them. Glyphs appear on hover or keyboard focus, presses give immediate feedback, and motion is disabled when reduced motion is requested.
- Home Manager merges the managed CSS block into existing Waterfox profiles without deleting unrelated custom CSS. New profiles created after a rebuild need the activation to run again.
- This implementation is specifically for Waterfox's Mozilla-style chrome. Other applications need their own native titlebar integration; a generic shell overlay is not a substitute for per-window controls.
- Floating remains separate from window close, minimize, and maximize behavior.

## Sources and attribution

- Apple Developer, *Buttons*, Human Interface Guidelines: <https://developer.apple.com/design/human-interface-guidelines/buttons>
- Apple Developer, *Windows*, Human Interface Guidelines: <https://developer.apple.com/design/human-interface-guidelines/windows>
- NameThatUI, *Traffic Lights (Window Controls)*: <https://namethatui.com/macos/traffic-lights>

Source pages checked on 9 October 2026. Apple's online guideline is dynamically rendered and may change; use the official page as the authoritative source.
