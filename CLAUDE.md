# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & run

SwiftPM project, no Xcode workspace. macOS 14+, pure Apple frameworks (AppKit + SwiftUI + ServiceManagement).

```sh
swift build                          # debug build → .build/debug/Hoist
swift build -c release               # release build → .build/release/Hoist
./scripts/bundle.sh [debug|release]  # wrap the SwiftPM binary into Hoist.app
open Hoist.app                       # launch the bundled menu-bar app
```

There is no test target. Do not invent test commands.

## Why bundle.sh exists

`swift run` produces a bare executable with no `Info.plist` and no stable bundle identifier, so `LSUIElement` (hide from Dock) doesn't stick and `SMAppService` (launch-at-login) has nothing to register. `scripts/bundle.sh` synthesizes `Info.plist`, copies in `Resources/Hoist.icns`, and ad-hoc codesigns — that's the supported run mode. Bundle identifier `com.hoist.Hoist` is hardcoded in the script.

## Architecture

Five source files in `Sources/Hoist/`. Single-process menu-bar app with no third-party dependencies.

- **App.swift** — `HoistApp.main` boots `NSApplication` with `.accessory` activation policy (no Dock, no ⌘-Tab). `AppDelegate` owns the `NSStatusItem`, builds the dropdown menu on demand via `NSMenuDelegate.menuNeedsUpdate`, runs a minute-aligned `Timer` that re-renders the title when the clock is enabled, and handles ⌘Q quit confirmation and update triggers.
- **Settings.swift** — `SettingsStore` (singleton, `@MainActor`) is the single source of truth, backed by `UserDefaults`. It is *both* an `ObservableObject` (for SwiftUI bindings in PreferencesView) *and* posts `SettingsStore.didChange` from each `didSet` (for AppKit observers in AppDelegate). Both are intentional — see the comment in Settings.swift; `objectWillChange` fires before assignment, which is wrong for the AppKit refresh path.
- **PreferencesWindow.swift** — `PreferencesWindowController` hosts a SwiftUI `PreferencesView` in an `NSWindow`. To take key focus the controller temporarily flips activation policy to `.regular`, then drops back to `.accessory` in `windowWillClose`. Launch-at-login uses `SMAppService.mainApp` via the `LoginItem` wrapper. Hosts in-window quit confirmation and update status/checks.
- **UpdateChecker.swift** — Zero-dependency update checker and in-app installer using GitHub's public Releases API (`anshulg8/hoist`). Handles background checking, modal prompts, downloading, extracting via `ditto`, ad-hoc signing, and seamless hot relaunch.
- **Countries.swift** — Hand-curated table (~110 entries) of `Country { code, name, timeZone }`. Flag emoji is derived from the ISO alpha-2 code via regional-indicator scalars (`emojiFlag(for:)`); for multi-zone countries the table picks the *capital city's* IANA zone.

### Cross-cutting invariants

- The status-item title is computed by `SettingsStore.statusBarString`; the menu-bar refresh path is `setting changed → didSet → didChange notification → AppDelegate.refreshStatusButton`. Don't bypass it.
- The dropdown menu is rebuilt from scratch on every open (`menuNeedsUpdate`). It's cheap (~120 items) and avoids the bookkeeping of keeping checkmarks/favourites in sync incrementally.
- The minute timer is only armed when `showTime` is true and is re-armed on every `didChange` to handle `showTime` flipping. Don't add a redundant always-on timer.
- The `Country` table's `timeZone` strings are validated via `TimeZone(identifier:)` at runtime in `currentTimeString()`; unknown identifiers degrade to no-time-shown rather than crashing. Keep that contract if adding entries.
