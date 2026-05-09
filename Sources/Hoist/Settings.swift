import Foundation
import Combine

/// What the menu-bar item shows next to (or instead of) the flag.
/// Time is *additive* — controlled separately by `showTime` — so any of
/// these modes composes with the optional clock.
enum DisplayMode: String, CaseIterable, Identifiable {
    case flagOnly        // 🇮🇳
    case flagAndCode     // 🇮🇳 IN
    case flagAndCustom   // 🇮🇳 <user text>

    var id: String { rawValue }
    var label: String {
        switch self {
        case .flagOnly:       return "Flag only"
        case .flagAndCode:    return "Flag + ISO code"
        case .flagAndCustom:  return "Flag + custom text"
        }
    }
}

/// Single source of truth for user preferences. Backed by `UserDefaults`,
/// observable from SwiftUI (Preferences window) and from AppKit (status
/// item refresh) — the latter via the `didChange` notification.
///
/// We keep this an `ObservableObject` *and* fire a notification because:
///   - SwiftUI binds to `@ObservedObject` (needs `objectWillChange`).
///   - The status item lives in `AppDelegate`, not a SwiftUI view, and
///     reacting via Combine on `objectWillChange` is awkward (it fires
///     *before* the new value is assigned). A plain `didSet` notification
///     is simpler and runs after the value has been written.
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    static let didChange = Notification.Name("HoistSettingsDidChange")

    private enum Keys {
        static let countryCode = "hoist.countryCode"
        static let displayMode = "hoist.displayMode"
        static let customText  = "hoist.customText"
        static let showTime    = "hoist.showTime"
        static let favorites   = "hoist.favorites"   // [String]
        static let recents     = "hoist.recents"     // [String], MRU first
    }

    /// How many recent selections to remember. Five fits comfortably in
    /// the menu without dwarfing the favourites section.
    private static let recentsLimit = 5

    private let defaults = UserDefaults.standard

    var countryCode: String {
        willSet { objectWillChange.send() }
        didSet {
            defaults.set(countryCode, forKey: Keys.countryCode)
            recordRecent(countryCode)
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        }
    }

    var displayMode: DisplayMode {
        willSet { objectWillChange.send() }
        didSet {
            defaults.set(displayMode.rawValue, forKey: Keys.displayMode)
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        }
    }

    var customText: String {
        willSet { objectWillChange.send() }
        didSet {
            defaults.set(customText, forKey: Keys.customText)
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        }
    }

    var showTime: Bool {
        willSet { objectWillChange.send() }
        didSet {
            defaults.set(showTime, forKey: Keys.showTime)
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        }
    }

    /// Set semantics — order doesn't matter, membership does. Stored as
    /// a sorted array in defaults to keep the on-disk format diff-friendly.
    var favorites: Set<String> {
        willSet { objectWillChange.send() }
        didSet {
            defaults.set(Array(favorites).sorted(), forKey: Keys.favorites)
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        }
    }

    /// MRU-ordered. First element is most-recently selected. Capped at
    /// `recentsLimit`; persisted on every change.
    private(set) var recents: [String] {
        willSet { objectWillChange.send() }
        didSet {
            defaults.set(recents, forKey: Keys.recents)
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        }
    }

    private init() {
        // Read everything once at startup. Anything malformed or missing
        // falls back to a sensible default rather than crashing.
        self.countryCode = defaults.string(forKey: Keys.countryCode) ?? Country.fallback.code
        self.displayMode = defaults.string(forKey: Keys.displayMode)
            .flatMap(DisplayMode.init(rawValue:)) ?? .flagAndCode
        self.customText = defaults.string(forKey: Keys.customText) ?? ""
        self.showTime = defaults.object(forKey: Keys.showTime) as? Bool ?? false
        self.favorites = Set(defaults.stringArray(forKey: Keys.favorites) ?? [])
        self.recents = defaults.stringArray(forKey: Keys.recents) ?? []
    }

    // MARK: - Derived state

    /// The currently selected `Country`, with fallback if the stored code
    /// is no longer in our table (e.g. stale defaults from an older build).
    var country: Country { Country.find(code: countryCode) ?? Country.fallback }

    /// Exact string the menu-bar status item should display. Empty custom
    /// text degrades to flag-only so the bar never shows a dangling space.
    /// Time is appended last when enabled (e.g. `🇮🇳 IN 18:42`).
    var statusBarString: String {
        let flag = country.flag
        var head: String
        switch displayMode {
        case .flagOnly:
            head = flag
        case .flagAndCode:
            head = "\(flag) \(country.code)"
        case .flagAndCustom:
            let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
            head = trimmed.isEmpty ? flag : "\(flag) \(trimmed)"
        }
        if showTime, let time = currentTimeString() {
            head += " \(time)"
        }
        return head
    }

    /// Local time at the selected country's capital, formatted HH:mm.
    /// Returns nil if the time-zone identifier is unknown to Foundation
    /// (shouldn't happen for our hand-curated table — guard remains in
    /// case a future entry has a typo).
    func currentTimeString() -> String? {
        guard let tz = TimeZone(identifier: country.timeZone) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = tz
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    // MARK: - Favourites / recents

    func toggleFavorite(_ code: String) {
        if favorites.contains(code) {
            favorites.remove(code)
        } else {
            favorites.insert(code)
        }
    }

    /// Promote `code` to the head of `recents`, dedupe, cap at the limit.
    /// Called from `countryCode` didSet so every selection participates.
    private func recordRecent(_ code: String) {
        var list = recents.filter { $0 != code }
        list.insert(code, at: 0)
        if list.count > Self.recentsLimit {
            list = Array(list.prefix(Self.recentsLimit))
        }
        recents = list
    }
}
