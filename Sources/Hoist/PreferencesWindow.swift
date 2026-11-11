import AppKit
import SwiftUI
import ServiceManagement

/// Hosts the SwiftUI preferences view in a standard window. Lives across
/// show/hide cycles (one instance per AppDelegate) so the frame and
/// search text persist between openings.
@MainActor
final class PreferencesWindowController: NSWindowController {
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Hoist Preferences"
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .normal

        let root = PreferencesView(settings: settings)
        window.contentView = NSHostingView(rootView: root)

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Bring the prefs window forward; briefly elevate to `.regular` so
    /// the window can take key focus (under `.accessory` it can't).
    func showAndFocus() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    var isWindowVisible: Bool {
        window?.isVisible == true
    }
}

extension PreferencesWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Drop back to menu-bar-only when the prefs window closes so we
        // don't keep a Dock icon around.
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - Launch-at-login bridge

/// Thin wrapper around `SMAppService.mainApp` so the SwiftUI toggle can
/// read/write a plain `Bool`. macOS 13+ — earlier versions are out of
/// scope (Package.swift pins .macOS(.v14)).
@MainActor
private final class LoginItem: ObservableObject {
    @Published private(set) var isEnabled: Bool

    init() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }

    func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Surface failure via the published value snapping back to
            // whatever the OS actually reports — the user sees the
            // checkbox revert and learns the change didn't stick.
            NSLog("Hoist: launch-at-login change failed: \(error.localizedDescription)")
        }
        // Re-read truth from the system rather than trusting our intent.
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }
}

// MARK: - SwiftUI

/// The preferences UI. All controls write through to `SettingsStore`,
/// which persists to UserDefaults and notifies AppDelegate to refresh
/// the menu bar instantly.
private struct PreferencesView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @StateObject private var loginItem = LoginItem()
    @State private var searchText: String = ""
    @State private var showQuitConfirmation: Bool = false

    private var filteredCountries: [Country] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return Country.all }
        return Country.all.filter {
            $0.name.localizedCaseInsensitiveContains(needle)
                || $0.code.localizedCaseInsensitiveContains(needle)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Live preview row — shows exactly what the menu bar will
            // render, so a user can validate their choice before closing.
            HStack(spacing: 8) {
                Text("Preview:")
                    .foregroundStyle(.secondary)
                Text(settings.statusBarString)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Divider()

            // --- Display mode ---
            VStack(alignment: .leading, spacing: 8) {
                Text("Display").font(.headline)
                Picker("Mode", selection: Binding(
                    get: { settings.displayMode },
                    set: { settings.displayMode = $0 }
                )) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if settings.displayMode == .flagAndCustom {
                    TextField("Custom text", text: Binding(
                        get: { settings.customText },
                        set: { settings.customText = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                Toggle("Show local time of selected country", isOn: Binding(
                    get: { settings.showTime },
                    set: { settings.showTime = $0 }
                ))

                Toggle("Launch Hoist at login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.set($0) }
                ))
            }
            .padding(.horizontal, 16)

            Divider()

            // --- Country picker ---
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Country").font(.headline)
                    Spacer()
                    TextField("Search…", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                }

                Text("Tap the star to add a country to your favourites — they'll appear at the top of the menu-bar Country submenu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                List(filteredCountries) { country in
                    CountryRow(
                        country: country,
                        isSelected: country.code == settings.countryCode,
                        isFavorite: settings.favorites.contains(country.code),
                        onSelect: { settings.countryCode = country.code },
                        onToggleFavorite: { settings.toggleFavorite(country.code) }
                    )
                }
                .listStyle(.bordered)
                .frame(minHeight: 280)
            }
            .padding(.horizontal, 16)

            Divider()

            // --- Footer: Version, Check for Updates, Quit ---
            HStack(spacing: 8) {
                Text("Hoist \(updateChecker.currentVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("•")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Button(action: {
                    updateChecker.checkForUpdates(explicit: true)
                }) {
                    HStack(spacing: 4) {
                        if updateChecker.isChecking {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11))
                        }
                        Text("Check for Updates…")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .disabled(updateChecker.isChecking)

                Spacer()

                Button(action: {
                    showQuitConfirmation = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                            .font(.system(size: 11))
                        Text("Quit Hoist")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit Hoist (⌘Q)")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(minWidth: 480, minHeight: 600)
        .alert("Quit Hoist?", isPresented: $showQuitConfirmation) {
            Button("Quit Hoist", role: .destructive) {
                NSApp.terminate(nil)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The menu-bar flag will be removed until you relaunch Hoist.")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HoistRequestQuitConfirmation"))) { _ in
            showQuitConfirmation = true
        }
    }
}

/// A row in the country list. The star button is its own tap target so
/// favouriting doesn't also select the country (and vice versa).
private struct CountryRow: View {
    let country: Country
    let isSelected: Bool
    let isFavorite: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .help(isFavorite ? "Remove from favourites" : "Add to favourites")

            Text(country.flag).font(.system(size: 18))
            Text(country.name)
                .fontWeight(isSelected ? .semibold : .regular)
            Spacer()
            Text(country.code)
                .foregroundStyle(.secondary)
                .font(.system(.caption, design: .monospaced))
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}
