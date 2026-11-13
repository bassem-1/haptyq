# tremor: design spec

tremor is a macOS 13+ menu bar app that makes the force touch trackpad react to where the cursor is.
example: near the red close button the trackpad pulses faster and harder ("frenzy"), while near
full screen it only taps once ("tick"). it uses private MultitouchSupport apis, so it isn't on the app store.
it's distributed as an ad-hoc signed zip on github releases (no paid apple developer account).

## 0. ground rules (all agents)

- swift 5 language mode (tools 5.9), macOS 13 deployment target. local toolchain = command line tools only (no xcode):
  xctest is unavailable, so tests use **swift-testing** (`import Testing`, `@Test`, `#expect`).
- each agent builds with its own scratch path to avoid clobbering: `swift build --scratch-path .build/<agent>`.
- only edit files you own (see section 7). `Sources/TremorKit/Model.swift` is frozen: don't edit it, tell the lead what you need.
- no new third-party dependencies.
- no force unwraps on runtime data, no `try!`, no `fatalError` outside truly impossible states.
- leave `print` debugging out. use `os.Logger(subsystem: "io.github.bassem-1.tremor", category: ...)` if needed.
- keep comments short. explain why, not what.

## 1. brand & visual language

the goal is to look designed, not generated. restraint over decoration.

- **lowercase only.** every user-visible string: labels, menus, alerts, window titles, accessibility labels, readme headings. no exceptions.
- **two colors only:** black `#000000` and neon yellow `#E4FF1A`. secondary/tertiary text and hairlines use the
  same yellow at reduced opacity (`0.55` for secondary text, `0.32` for disabled, `0.16` for hairlines/borders,
  `0.08` for pressed/hover fills). no grey, no white, no system accent color, no other hues, including in focus rings
  (disable them with `.focusEffectDisabled()` on macOS 14+ guarded by `if #available`, else accept the default).
- **type:** `Font.system(size:, weight:, design: .monospaced)`. sizes: 22 (gadget state word), 13 (titles/rows),
  11 (secondary, captions). weights: regular and medium only. tracking default. no bold, no italics.
- **spacing:** 4pt grid. popover padding 16, row height 32, section gap 16. corner radius 10 (controls 6).
- **no:** emoji, gradients, drop shadows, glassmorphism, sf symbols in content (exception: none). the menu bar glyph is custom-drawn.
- **motion:** only functional motion. a pulse indicator flashes when a haptic fires (opacity 1 → 0.16 over 180ms).
  no bouncy springs, nothing animates on idle.
- force dark appearance on all tremor windows (`NSAppearance(named: .darkAqua)`) so system controls never render light.

### signature control: the signal bar

a feel is chosen with a 5-cell horizontal bar (like a signal meter). cell i (0...4) maps to `Feel(level: i)`.
cells 1...level are filled yellow, the rest are 16% yellow outlines. cell 0 is "off" and is drawn as a short
dash, filled when feel == .off. clicking cell i sets the feel. cells are 10×14pt, 3pt gap, radius 2. to the right
the feel name in 11pt secondary text, e.g. `frenzy`. this one control should be the visual identity.

## 2. surfaces

### 2.1 menu bar item
- `MenuBarExtra` with `.menuBarExtraStyle(.window)`.
- label: custom template `NSImage` 18×18: three vertical rounded bars (heights 6/12/8, width 2.5, gap 2.5).
  when disabled, draw them at 35% alpha. it must be a template image so macOS tints it.

### 2.2 popover (width 300)
```
tremor                                   [■■ on]
haptics that tell you where you are.

close            ▬ ■ ■ ■ ■   frenzy
minimize         ▬ ■ ■ □ □   calm
full screen      ▬ ■ □ □ □   tick
other buttons    ▬ □ □ □ □   off
window edges     ▬ ■ □ □ □   tick
─────────────────────────────────────────
desktop gadget                       [on]
gadget floats above windows          [off]
launch at login                      [off]
─────────────────────────────────────────
quit                                v0.1.0
```
- header: `tremor` 13 medium, tagline 11 secondary. master switch top-right (custom capsule switch, see 2.4).
- zone row: title left, signal bar right. hovering a row shows the zone's `detail` as a caption under the list
  (single shared caption line, 11pt secondary, so the layout never jumps). clicking the title expands the row
  (one at a time) to show: `reach  near · mid · far` (proximity zones only, `zone.allowsReach`),
  `confirm click  [switch]` (proximity zones only), and a `feel it` text button that calls `engine.preview`.
- when the master switch is off, zone rows dim to 32% and aren't interactive.
- permission banner (shown instead of the zone list when `!Permissions.isTrusted`): 
  `tremor needs accessibility access to see where buttons are.` + text buttons `grant access` (request + open settings)
  and, after the user has clicked it once, `i did it` (calls `engine.refresh()`). poll `Permissions.isTrusted`
  every 1s while the banner is visible and dismiss automatically.
- hardware banner when `!engine.hardwareAvailable`: `no force touch trackpad found. settings are saved anyway.`
- footer: `quit` text button, version from `CFBundleShortVersionString` or `dev`.

### 2.3 desktop gadget
- `NSPanel`, styleMask `[.borderless, .nonactivatingPanel]`, clear background, not opaque, no shadow,
  `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]`,
  `hidesOnDeactivate = false`, `canBecomeKey` false. dragging is handled in `sendEvent` (not `isMovableByWindowBackground`, which swallows mouse-up and breaks click-to-toggle).
- level: `Int(CGWindowLevelForKey(.desktopIconWindow)) + 1` when `!gadgetFloats`, else `.floating`.
- size 140×140, black rounded rect radius 22 with a 1px 16%-yellow border.
- content: top-left `tremor` 11 secondary; center the state word `on` / `off` at 22 medium (yellow when on,
  32% when off); below it a pulse dot (6pt circle) that flashes on every `onPulse`; bottom-left caption:
  the strongest active zone, e.g. `close · frenzy` (11 secondary), or `paused` when off.
- clicking anywhere that isn't a drag toggles `enabled`. distinguish click vs drag: treat as click only if the mouse
  moved < 3pt between down and up.
- position persists to `settings.gadgetOrigin` on move end; default: top-right of main screen's visibleFrame inset 24.
  clamp into a visible screen on launch and on `NSApplication.didChangeScreenParametersNotification`.
- right-click shows a small menu: `hide gadget`, `float above windows` (checkmark), `quit`.

### 2.4 custom switch
capsule 34×18. off: 16% yellow border, knob 32% yellow at left. on: yellow fill, black knob at right.
120ms ease-out knob slide. accessible as a toggle with a lowercase label.

## 3. app structure (target `tremor`)

- `@main struct TremorApp: App` with `MenuBarExtra`. `LSUIElement` = true (no dock icon); also set
  `NSApp.setActivationPolicy(.accessory)` at launch as a belt-and-braces measure.
- `@MainActor final class AppModel: ObservableObject`:
  - `@Published var settings: Settings` loaded from `SettingsStore.load()`; on change → `engine.apply`, debounce 300ms
    then `SettingsStore.save`; also save on `NSApplication.willTerminateNotification`.
  - `@Published var trusted: Bool`, `@Published var pulse: Int` (increments on `engine.onPulse`).
  - owns `TremorEngine` and `GadgetController`.
- `GadgetController` shows/hides/re-levels the panel reactively from settings.
- files: `TremorApp.swift`, `AppModel.swift`, `Theme.swift` (colors, fonts, spacing tokens), `PopoverView.swift`,
  `SignalBar.swift`, `TremorSwitch.swift`, `GadgetController.swift`, `GadgetView.swift`, `MenuBarIcon.swift`.
  remove the placeholder `main.swift` (a target with `@main` must not have `main.swift`).

## 4. engine (target `TremorKit`)

public api is fixed by `TremorEngine.swift` (skeleton). implementation rules:

### 4.1 threading
- the event tap callback does nothing but copy `event.location` / type / deltas and hand them to a private serial
  `DispatchQueue` ("tremor.tracker", qos userInteractive). never call ax apis inside the callback.
- ax lookups happen on the tracker queue, at most every 50ms (coalesce moves), with
  `AXUIElementSetMessagingTimeout(systemWide, 0.05)`.
- `Actuator.fire` must be serialized: add a private lock inside `Actuator` (HapticCore). its fallback
  (`NSHapticFeedbackManager`) must be dispatched to the main thread.
- `onPulse` is delivered on main, throttled to ≤30 Hz.
- the tap's run loop source is added to the main run loop. handle `.tapDisabledByTimeout`/`.tapDisabledByUserInput`
  by re-enabling.

### 4.2 targets
on each lookup, for the window under the cursor (from `AXUIElementCopyElementAtPosition` → own role is window, or its
`kAXWindowAttribute`) and the focused window of the focused app, read button frames:
`kAXCloseButtonAttribute` → .close, `kAXMinimizeButtonAttribute` → .minimize,
`kAXFullScreenButtonAttribute` or else `kAXZoomButtonAttribute` → .zoom. dedupe identical frames.
distance = max(0, |cursor − button center| − min(w,h)/2) in global top-left coordinates (same space as cgevent location).

### 4.3 feel semantics
pure function, unit tested: `func proximityConfig(for: ZoneSetting, ladder: [Int32]) -> ProximityConfig?`
(put it in `TremorKit/Mapping.swift`). radius = reach.points. ids slice the ladder (weak→strong):

| feel    | proximity zones (close/minimize/zoom)                                      | buttons (on enter) | edges (resize ratchet)   |
|---------|----------------------------------------------------------------------------|--------------------|--------------------------|
| off     | nothing                                                                    | nothing            | nothing                  |
| tick    | one tap (ladder[1]) when the cursor enters the button rect, no ramp        | tap ladder[0]      | ladder[0] every 40pt     |
| calm    | slowest 260ms, fastest 110ms, curve 2.2, ids ladder[0...1]                 | tap ladder[1]      | ladder[1] every 40pt     |
| ramp    | slowest 200ms, fastest 45ms, curve 1.8, ids whole ladder                   | tap ladder[2]      | ladder[2] every 25pt     |
| frenzy  | slowest 120ms, fastest 16ms, curve 1.1, ids upper half of ladder           | tap ladder.last    | ladder.last every 14pt   |

ladder indices are clamped to the ladder's bounds. only the **nearest** active proximity target drives the
`ProximityEngine` at any time (ties: higher feel wins). `idleMs` 250 for all.
`buttons` covers any `AXButton` under the cursor that is not one of the traffic-light buttons; fire once per
entered element (`CFEqual` against the previous one).

### 4.4 clicks
- mouse down: stop the proximity engine (`update(distance: nil)`) so the click feels clean.
- if mouse down was on a traffic-light button whose zone has `confirmClick` and feel != .off, on mouse up over the same
  element play after 60ms: close → `latch` (or `heartbeat` when the window's `AXModified` is true),
  minimize → `sink`, zoom → `inhale` (patterns from `HapticCore.Library.builtIn`).
- edges: mouse down within 6pt of the window frame edge starts resize tracking; drag accumulates
  `hypot(dx,dy)`; fire per step per table. mouse up ends it.

### 4.5 lifecycle
- `apply(settings)`: store; if enabled && trusted && hardware → ensure tap running, else tear it down.
  disabling must silence immediately (proximity `update(distance: nil)`).
- `refresh()`: re-check trust, (re)create the tap if needed.
- listen-only tap on `.cgSessionEventTap` for mouseMoved, leftMouseDown/Up/Dragged.
- `preview(zone, setting)`: independent of the tap and of `enabled`; for proximity feels simulate distance going
  from `reach.points` → 0 over 1.2s (then hold 150ms, then stop); tick/buttons: single tap; edges: 8 ratchet steps.
  calling preview again cancels the previous one.
- `Permissions`: `AXIsProcessTrusted()`, `AXIsProcessTrustedWithOptions(prompt:true)`, open
  `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.
- `LaunchAtLogin`: `SMAppService.mainApp` register/unregister; return a lowercase error string on failure.

### 4.6 HapticCore changes
- add the lock to `Actuator` (see 4.1).
- extend `ProximityEngine` with `update(distance: Double?, config: ProximityConfig?)` (config replaces the stored one
  atomically on the engine queue); keep `update(distance:)` and `config` for haptic-web.
- `haptic-daemon` is removed (superseded by tremor). keep `haptic-lab` and `haptic-web` compiling.

## 5. tests (`Tests/TremorKitTests`, swift-testing)
- settings: defaults, json round-trip, decoding `{}` and partial/garbage zones falls back to defaults, unknown keys ignored.
- mapping: every feel × zone row of the table, ladder clamping with ladders of length 1 and 2, nil for off.
- distance math and target selection (nearest wins, ties → higher feel). keep that logic in pure functions to test it.

## 6. distribution
- `scripts/make-icon.swift`: renders the app icon with AppKit (black rounded square per macOS icon grid, the
  three-bar glyph in yellow, large and centered) at 1024 → `scripts/bundle.sh` builds the `.iconset` via `sips` and
  `iconutil`.
- `Resources/Info.plist`: `CFBundleName`/`CFBundleDisplayName` `tremor`, `CFBundleIdentifier`
  `io.github.bassem-1.tremor`, `CFBundleExecutable` `tremor`, `CFBundleIconFile` `AppIcon`, `LSUIElement` true,
  `LSMinimumSystemVersion` 13.0, `CFBundleShortVersionString`/`CFBundleVersion` substituted from `VERSION`
  (file at repo root, `0.1.0`), `NSHumanReadableCopyright`.
- `scripts/bundle.sh [--universal]`: release build (universal uses `--arch arm64 --arch x86_64`, requires xcode,
  output under `.build/apple/Products/Release`; otherwise host arch), assemble `dist/tremor.app`, ad-hoc sign
  (`codesign --force --sign - --timestamp=none`), zip with `ditto -c -k --keepParent` → `dist/tremor-<version>.zip`,
  and print the sha256. `set -euo pipefail`, quote everything, work from repo root regardless of cwd.
- `.github/workflows/release.yml`: on tag `v*`: `macos-14` runner, `swift test`, `scripts/bundle.sh --universal`,
  create the release with the zip attached (`gh release create` using `GITHUB_TOKEN`, `permissions: contents: write`).
- `.github/workflows/ci.yml`: on push/pr: `swift build` + `swift test`.
- readme (lowercase): what it is, a short gif placeholder line, install (download zip, move to /Applications,
  first open: macOS 15+ → system settings › privacy & security › open anyway; macOS 13–14 → right-click › open;
  or `xattr -dr com.apple.quarantine /Applications/tremor.app`), grant accessibility, note that ad-hoc builds
  need accessibility re-granted after each update, build from source, calibrating ids with `haptic-web`,
  disclaimer about private apis, license line (mit). add `LICENSE` (mit, 2026, "tremor contributors").

## 7. ownership
| owner          | files |
|----------------|-------|
| lead           | `Package.swift`, `Sources/TremorKit/Model.swift`, `docs/` |
| engine agent   | `Sources/HapticCore/**`, `Sources/TremorKit/**` (except Model.swift), `Sources/haptic-web/**`, `Sources/haptic-lab/**`, `Tests/**` |
| ui agent       | `Sources/tremor/**` |
| release agent  | `scripts/**`, `Resources/**`, `.github/**`, `README.md`, `LICENSE`, `VERSION`, `.gitignore` |
