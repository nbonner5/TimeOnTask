import Foundation

enum SessionMode: String, CaseIterable, Codable {
    case countdown = "Countdown", stopwatch = "Stopwatch"
}

struct FocusDuration: Equatable {
    static let maximum = 99 * 3600 + 59 * 60 + 59
    let seconds: Int
    init(seconds: Int) { self.seconds = min(Self.maximum, max(1, seconds)) }
    init(hours: Int, minutes: Int, seconds: Int) {
        self.init(seconds: min(99, max(0, hours)) * 3600 + min(59, max(0, minutes)) * 60 + min(59, max(0, seconds)))
    }
    var hours: Int { seconds / 3600 }
    var minutes: Int { seconds / 60 % 60 }
    var remainderSeconds: Int { seconds % 60 }
}

enum FocusColor: String, CaseIterable, Codable, Identifiable {
    case mint, blue, purple, pink, red, orange, yellow, graphite
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
}

enum FocusSymbols {
    static func displayName(_ symbol: String) -> String {
        let names = ["briefcase.fill": "Work", "hammer.fill": "Build", "chevron.left.forwardslash.chevron.right": "Code",
                     "terminal.fill": "Terminal", "pencil": "Write", "doc.text.fill": "Document", "book.fill": "Read",
                     "graduationcap.fill": "Study", "paintbrush.pointed.fill": "Draw", "paintpalette.fill": "Design",
                     "photo.fill": "Photos", "camera.fill": "Camera", "headphones": "Listen", "music.note": "Music",
                     "gamecontroller.fill": "Games", "brain.head.profile": "Think", "sparkles": "Create", "leaf.fill": "Nature",
                     "heart.fill": "Wellness", "dumbbell.fill": "Exercise", "person.fill": "Personal", "laptopcomputer": "Computer",
                     "globe": "Web", "star.fill": "Favorite"]
        return names[symbol] ?? "Work"
    }
    static let all = ["briefcase.fill", "hammer.fill", "chevron.left.forwardslash.chevron.right", "terminal.fill",
                      "pencil", "doc.text.fill", "book.fill", "graduationcap.fill", "paintbrush.pointed.fill",
                      "paintpalette.fill", "photo.fill", "camera.fill", "headphones", "music.note",
                      "gamecontroller.fill", "brain.head.profile", "sparkles", "leaf.fill", "heart.fill",
                      "dumbbell.fill", "person.fill", "laptopcomputer", "globe", "star.fill"]
}

struct FocusProfile: Codable, Identifiable {
    var id = UUID()
    var name: String
    var symbol = "briefcase.fill"
    var color: FocusColor = .mint
    var apps: [String: String] = [:]
    var rules: [WebsiteRule] = []
    var browsers = ["com.google.Chrome"]
    var mode: SessionMode = .countdown
    var durationSeconds = 3600
    var elapsed: Double = 0

    init(name: String) { self.name = name }
    private enum CodingKeys: String, CodingKey {
        case id, name, symbol, color, apps, rules, browsers, mode, durationSeconds, elapsed
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        let savedSymbol = try values.decodeIfPresent(String.self, forKey: .symbol) ?? "briefcase.fill"
        symbol = FocusSymbols.all.contains(savedSymbol) ? savedSymbol : "briefcase.fill"
        color = FocusColor(rawValue: try values.decodeIfPresent(String.self, forKey: .color) ?? "mint") ?? .mint
        apps = try values.decode([String: String].self, forKey: .apps)
        rules = try values.decode([WebsiteRule].self, forKey: .rules)
        browsers = try values.decode([String].self, forKey: .browsers)
        mode = try values.decode(SessionMode.self, forKey: .mode)
        durationSeconds = try values.decode(Int.self, forKey: .durationSeconds)
        elapsed = try values.decode(Double.self, forKey: .elapsed)
    }
}

struct FocusWorkspace: Codable {
    var profiles: [FocusProfile]
    var selectedID: UUID
    var selectedIndex: Int { profiles.firstIndex { $0.id == selectedID } ?? 0 }
    var selected: FocusProfile {
        get { profiles[selectedIndex] }
        set { profiles[selectedIndex] = newValue }
    }

    init(profile: FocusProfile = FocusProfile(name: "Work")) {
        profiles = [profile]; selectedID = profile.id
    }

    // Keep the legacy key intact so existing users can migrate without losing progress.
    static func restore(current: Data?, legacy: Data?) -> FocusWorkspace {
        if let current, var saved = try? JSONDecoder().decode(Self.self, from: current), !saved.profiles.isEmpty {
            var ids = Set<UUID>()
            for index in saved.profiles.indices {
                if !ids.insert(saved.profiles[index].id).inserted { saved.profiles[index].id = UUID() }
                saved.profiles[index].durationSeconds = FocusDuration(seconds: saved.profiles[index].durationSeconds).seconds
                if !saved.profiles[index].elapsed.isFinite { saved.profiles[index].elapsed = 0 }
                saved.profiles[index].elapsed = max(0, saved.profiles[index].elapsed)
            }
            if !saved.profiles.contains(where: { $0.id == saved.selectedID }) { saved.selectedID = saved.profiles[0].id }
            return saved
        }
        struct Legacy: Decodable {
            var mode: SessionMode; var minutes: Int; var elapsed: Double
            var rules: [String]; var apps: [String: String]
        }
        if let legacy, let old = try? JSONDecoder().decode(Legacy.self, from: legacy) {
            var profile = FocusProfile(name: "Work")
            profile.mode = old.mode
            profile.durationSeconds = FocusDuration(seconds: min(480, max(1, old.minutes)) * 60).seconds
            profile.elapsed = max(0, old.elapsed)
            profile.apps = old.apps
            profile.rules = old.rules.compactMap(WebsiteRule.init)
            return Self(profile: profile)
        }
        return Self()
    }

    mutating func add(name: String, duplicate: Bool = false) {
        var profile = duplicate ? selected : FocusProfile(name: name)
        profile.id = UUID(); profile.name = name; profile.elapsed = 0
        profiles.append(profile); selectedID = profile.id
    }

    mutating func removeSelected() {
        guard profiles.count > 1 else { return }
        profiles.remove(at: selectedIndex); selectedID = profiles[0].id
    }
}

/// URL handlers aren't a browser identity: editors and desktop clients handle
/// http/https links too. Only known browser bundle identifiers get special treatment.
enum ApplicationSelectionPolicy {
    enum Destination: Equatable { case nativeApp, supportedBrowser, unsupportedBrowser }
    private static let unsupportedBrowserIDs: Set<String> = [
        "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.nightly",
        "org.torproject.torbrowser", "com.duckduckgo.macos.browser",
        "com.kagi.kagimacOS", "com.kagi.kagimacOS.RC",
        "com.google.Chrome.beta", "com.google.Chrome.dev", "com.google.Chrome.canary",
        "com.brave.Browser.beta", "com.brave.Browser.nightly",
        "com.microsoft.edgemac.Beta", "com.microsoft.edgemac.Dev", "com.microsoft.edgemac.Canary"
    ]

    static func destination(bundleIdentifier: String, supportedBrowserIDs: Set<String>) -> Destination {
        if supportedBrowserIDs.contains(bundleIdentifier) { return .supportedBrowser }
        if unsupportedBrowserIDs.contains(bundleIdentifier) { return .unsupportedBrowser }
        return .nativeApp
    }
}

/// A fresh digit replaces the selected segment; a second quick digit completes it.
struct TimeSegmentEntry {
    private var digits = ""
    private var lastInput: TimeInterval = 0
    mutating func enter(_ digit: Int, at now: TimeInterval, maximum: Int) -> Int {
        if now - lastInput > 1.5 || digits.count >= 2 { digits = "" }
        digits += String(min(9, max(0, digit)))
        lastInput = now
        return min(maximum, Int(digits) ?? 0)
    }
    mutating func reset() { digits = ""; lastInput = 0 }
}
