import Foundation

struct WebsiteRule: Codable, Identifiable, Equatable {
    var id: String { text }
    let text: String
    let host: String
    let port: Int?

    init?(_ input: String) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty,
              let url = URLComponents(string: text.contains("://") ? text : "http://" + text),
              ["http", "https"].contains(url.scheme ?? ""),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil,
              url.path.isEmpty || url.path == "/", url.query == nil, url.fragment == nil,
              !host.contains("*"), !host.contains(" "),
              url.port == nil || (1...65535).contains(url.port!) else { return nil }
        let normalized = Self.normalizedHost(host)
        self.host = normalized
        self.port = url.port
        self.text = normalized + (url.port.map { ":\($0)" } ?? "")
    }

    private static func normalizedHost(_ host: String) -> String {
        let host = host.lowercased()
        guard host.hasPrefix("www.") else { return host }
        let base = String(host.dropFirst(4))
        // Only normalize ordinary website domains, keeping local names and IPs exact.
        guard base.contains("."), !base.split(separator: ".").allSatisfy({ UInt8($0) != nil }) else { return host }
        return base
    }

    func matches(_ url: URL) -> Bool {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let urlHost = url.host,
              Self.normalizedHost(urlHost) == Self.normalizedHost(host) else { return false }
        guard let port else { return true }
        return port == (url.port ?? (url.scheme == "https" ? 443 : 80))
    }
}

struct FocusClock {
    var elapsed: TimeInterval = 0
    private var lastSample: TimeInterval?
    private var previouslyEligible = false

    // Require eligible samples at both ends. A delayed sample never credits a large gap.
    mutating func sample(at now: TimeInterval, eligible: Bool) {
        if let previous = lastSample, previouslyEligible, eligible {
            let delta = now - previous
            if delta >= 0 && delta <= 2 { elapsed += delta }
        }
        lastSample = now
        previouslyEligible = eligible
    }
    mutating func interrupt() { lastSample = nil; previouslyEligible = false }
}
