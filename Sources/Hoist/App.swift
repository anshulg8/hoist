import AppKit
import SwiftUI

@main
struct HoistApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // .accessory keeps us out of the Dock and the ⌘-Tab switcher —
        // appropriate for a menu-bar-only utility. The Preferences window
        // briefly elevates to .regular so it can take key focus, then we
        // drop back to .accessory on close (see PreferencesWindow.swift).
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let settings = SettingsStore.shared

    private var statusItem: NSStatusItem?
    private var preferencesController: PreferencesWindowController?
    private var aboutWindow: NSWindow?
    private var localKeyMonitor: Any?

    /// Minute-aligned timer that re-renders the status title so the
    /// optional clock advances without drift. Nil while time is hidden.
    private var minuteTimer: Timer?

    // MARK: - App lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        installStatusItem()
        configureMinuteTimer()
        installLocalKeyMonitor()

        // Background update check shortly after launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UpdateChecker.shared.checkForUpdates(explicit: false)
        }

        // Refresh the menu-bar title whenever any setting changes.
        // SettingsStore posts this notification *after* the new value is
        // assigned, so reading `settings.statusBarString` here is safe.
        // We also reconfigure the minute timer in case `showTime` flipped.
        NotificationCenter.default.addObserver(
            forName: SettingsStore.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshStatusButton()
                self?.configureMinuteTimer()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let m = localKeyMonitor {
            NSEvent.removeMonitor(m)
            localKeyMonitor = nil
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Closing the Preferences window must not quit the app — the
        // status item is the long-lived UI surface.
        false
    }

    // MARK: - Main menu

    /// Even under `.accessory` the system still searches `NSApp.mainMenu`
    /// to resolve key equivalents. Without this, ⌘C / ⌘V / ⌘X / ⌘A inside
    /// the Preferences window's text fields silently no-op.
    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Hoist")
        let aboutItem = NSMenuItem(
            title: "About Hoist",
            action: #selector(openAboutWindow),
            keyEquivalent: ""
        )
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        let updateItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        appMenu.addItem(updateItem)
        appMenu.addItem(.separator())
        let prefsItem = NSMenuItem(
            title: "Preferences…",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefsItem.target = self
        appMenu.addItem(prefsItem)
        appMenu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: "Quit Hoist",
            action: #selector(requestQuitConfirmation),
            keyEquivalent: "q"
        )
        quitItem.target = self
        appMenu.addItem(quitItem)
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        let undo = NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(undo)
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut",  action: #selector(NSText.cut(_:)),  keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste",action: #selector(NSText.paste(_:)),keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Status item

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            // System menu-bar font + emoji-aware appearance. The button
            // auto-adapts to light/dark mode by default.
            button.font = NSFont.menuBarFont(ofSize: 0)
            button.imagePosition = .noImage
        }

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item

        refreshStatusButton()
    }

    private func refreshStatusButton() {
        guard let button = statusItem?.button else { return }
        button.title = settings.statusBarString
        button.toolTip = "\(settings.country.flag) \(settings.country.name)"
    }

    // MARK: - Minute timer (drives the optional clock)

    /// Re-arms the minute timer so it fires at the next minute boundary
    /// and every 60s thereafter. Disabled when the clock is hidden — no
    /// point waking the runloop just to recompute an unused string.
    private func configureMinuteTimer() {
        minuteTimer?.invalidate()
        minuteTimer = nil
        guard settings.showTime else { return }

        let calendar = Calendar.current
        let nextMinute = calendar.nextDate(
            after: Date(),
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(60)

        let timer = Timer(fire: nextMinute, interval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshStatusButton() }
        }
        // .common so the timer keeps firing while menus are tracking too.
        RunLoop.main.add(timer, forMode: .common)
        minuteTimer = timer
    }

    // MARK: - Menu actions

    @objc private func openPreferences() {
        if preferencesController == nil {
            preferencesController = PreferencesWindowController(settings: settings)
        }
        preferencesController?.showAndFocus()
    }

    @objc private func selectCountry(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        settings.countryCode = code
    }

    @objc private func selectDisplayMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = DisplayMode(rawValue: raw) else { return }
        settings.displayMode = mode
    }

    @objc private func toggleShowTime() {
        settings.showTime.toggle()
    }

    @objc private func customTextChanged(_ sender: NSTextField) {
        settings.customText = sender.stringValue
    }

    @objc func checkForUpdates() {
        UpdateChecker.shared.checkForUpdates(explicit: true)
    }

    @objc func openAboutWindow() {
        if aboutWindow == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 330),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.center()
            win.title = "About Hoist"
            win.isReleasedWhenClosed = false
            win.delegate = self
            let hosting = NSHostingView(rootView: AboutView(onClose: { [weak win] in win?.close() }))
            win.contentView = hosting
            aboutWindow = win
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow?.center()
        aboutWindow?.makeKeyAndOrderFront(nil)
    }

    func windowClosed(_ closedWindow: NSWindow?) {
        let isPreferencesVisible = (closedWindow !== preferencesController?.window) && (preferencesController?.isWindowVisible == true)
        let isAboutVisible = (closedWindow !== aboutWindow) && (aboutWindow?.isVisible == true)
        if !isPreferencesVisible && !isAboutVisible {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func windowWillClose(_ notification: Notification) {
        windowClosed(notification.object as? NSWindow)
    }

    @objc func quitApp() {
        requestQuitConfirmation()
    }

    @objc func requestQuitConfirmation() {
        let isAnyViewVisible = (preferencesController?.isWindowVisible == true) || (aboutWindow?.isVisible == true)
        if isAnyViewVisible {
            NotificationCenter.default.post(name: Notification.Name("HoistRequestQuitConfirmation"), object: nil)
        } else {
            let alert = NSAlert()
            alert.messageText = "Quit Hoist?"
            alert.informativeText = "The menu-bar flag will be removed until you relaunch Hoist."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Quit Hoist")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                NSApp.terminate(nil)
            }
        }
    }

    // MARK: - Key event monitor

    private func installLocalKeyMonitor() {
        guard localKeyMonitor == nil else { return }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            let isCmd = event.modifierFlags.contains(.command)
            let char = event.charactersIgnoringModifiers?.lowercased()

            // ⌘Q: Request quit with confirmation dialog
            if isCmd && char == "q" {
                self.requestQuitConfirmation()
                return nil
            }

            // ⌘W: Close active window
            if isCmd && char == "w" {
                if let win = self.aboutWindow, win.isVisible {
                    win.close()
                    return nil
                }
                if let controller = self.preferencesController, controller.isWindowVisible {
                    controller.window?.close()
                    return nil
                }
            }

            // Escape: Close active window
            if event.keyCode == 53 {
                if let win = self.aboutWindow, win.isVisible {
                    win.close()
                    return nil
                }
                if let controller = self.preferencesController, controller.isWindowVisible {
                    controller.window?.close()
                    return nil
                }
            }

            return event
        }
    }
}

// MARK: - Status menu construction

extension AppDelegate: NSMenuDelegate {
    /// Rebuilt every time the user opens the menu. Cheap (~120 items) and
    /// guarantees the "current selection" checkmarks stay in sync without
    /// needing observation plumbing.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // Header — non-interactive, shows the current country in full,
        // plus current local time when the clock is enabled (handy
        // confirmation that the time-zone mapping is working).
        var headerTitle = "\(settings.country.flag)  \(settings.country.name) (\(settings.country.code))"
        if settings.showTime, let time = settings.currentTimeString() {
            headerTitle += "  •  \(time)"
        }
        let header = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(.separator())

        menu.addItem(buildCountriesSubmenu())
        menu.addItem(buildDisplayModeSubmenu())
        menu.addItem(buildShowTimeItem())

        // Custom text inline editor — shown only when relevant, so the
        // menu doesn't carry a confusing dead field in flag-only mode.
        if settings.displayMode == .flagAndCustom {
            menu.addItem(buildCustomTextItem())
        }

        menu.addItem(.separator())

        let prefs = NSMenuItem(
            title: "Preferences…",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefs.target = self
        menu.addItem(prefs)

        let updateItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu.addItem(updateItem)

        let aboutItem = NSMenuItem(
            title: "About Hoist…",
            action: #selector(openAboutWindow),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Hoist",
            action: #selector(requestQuitConfirmation),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    /// Country submenu, structured as:
    ///   Favourites    (only if non-empty)
    ///   Recently used (only if non-empty, deduped against favourites
    ///                  and the current selection)
    ///   All countries (always)
    /// The two leading sections cover the 80% case — the user picks from
    /// the same handful of countries — without the friction of scrolling
    /// through 110 alphabetical entries.
    private func buildCountriesSubmenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Country", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Country")

        let favCountries = Country.all.filter { settings.favorites.contains($0.code) }
        if !favCountries.isEmpty {
            submenu.addItem(sectionHeader("★ Favourites"))
            for country in favCountries {
                submenu.addItem(makeCountryRow(country))
            }
            submenu.addItem(.separator())
        }

        let recentCodes = settings.recents
            .filter { $0 != settings.countryCode && !settings.favorites.contains($0) }
        let recentCountries = recentCodes.compactMap { Country.find(code: $0) }
        if !recentCountries.isEmpty {
            submenu.addItem(sectionHeader("Recently used"))
            for country in recentCountries {
                submenu.addItem(makeCountryRow(country))
            }
            submenu.addItem(.separator())
        }

        submenu.addItem(sectionHeader("All countries"))
        for country in Country.all {
            submenu.addItem(makeCountryRow(country))
        }

        item.submenu = submenu
        return item
    }

    /// A single country row. A leading star marks favourites in-place;
    /// the favourite/unfavourite *action* lives in Preferences so menu
    /// rows stay single-purpose (tap to select, nothing else).
    private func makeCountryRow(_ country: Country) -> NSMenuItem {
        let isFavorite = settings.favorites.contains(country.code)
        let star = isFavorite ? "★ " : ""
        let row = NSMenuItem(
            title: "\(country.flag)  \(star)\(country.name)  (\(country.code))",
            action: #selector(selectCountry(_:)),
            keyEquivalent: ""
        )
        row.target = self
        row.representedObject = country.code
        row.state = (country.code == settings.countryCode) ? .on : .off
        return row
    }

    private func sectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func buildDisplayModeSubmenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Display Mode", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Display Mode")

        for mode in DisplayMode.allCases {
            let row = NSMenuItem(
                title: mode.label,
                action: #selector(selectDisplayMode(_:)),
                keyEquivalent: ""
            )
            row.target = self
            row.representedObject = mode.rawValue
            row.state = (mode == settings.displayMode) ? .on : .off
            submenu.addItem(row)
        }

        item.submenu = submenu
        return item
    }

    private func buildShowTimeItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: "Show local time",
            action: #selector(toggleShowTime),
            keyEquivalent: ""
        )
        item.target = self
        item.state = settings.showTime ? .on : .off
        return item
    }

    /// Inline NSTextField wrapped in an NSMenuItem.view. Wider than the
    /// default menu width to discourage truncation; height matches a
    /// standard menu row.
    private func buildCustomTextItem() -> NSMenuItem {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 28))

        let label = NSTextField(labelWithString: "Text:")
        label.font = NSFont.menuFont(ofSize: 0)
        label.frame = NSRect(x: 14, y: 6, width: 36, height: 18)
        container.addSubview(label)

        let field = NSTextField(frame: NSRect(x: 54, y: 4, width: 196, height: 22))
        field.placeholderString = "e.g. Mumbai"
        field.stringValue = settings.customText
        field.target = self
        field.action = #selector(customTextChanged(_:))
        field.isEditable = true
        field.isSelectable = true
        field.bezelStyle = .roundedBezel
        field.cell?.sendsActionOnEndEditing = true
        container.addSubview(field)

        let item = NSMenuItem()
        item.view = container
        return item
    }
}
