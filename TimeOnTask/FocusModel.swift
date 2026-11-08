import AppKit
import SwiftUI

@MainActor
final class FocusModel: ObservableObject {
    typealias Mode = SessionMode
    @Published private(set) var workspace: FocusWorkspace
    @Published private(set) var armed = false
    @Published private(set) var counting = false
    @Published private(set) var status = "Ready when you are"
    @Published private(set) var connectedBrowsers = Set<String>()
    @Published private(set) var browserMessages: [String: String] = [:]
    @Published private(set) var connectingBrowser: String?
    @Published var appSelectionMessage: String?
    private var clock = FocusClock()
    private var timer: Timer?
    private let reader = BrowserReader()
    private var reading = false
    private var generation = 0
    private var suspended = false
    private var observers: [NSObjectProtocol] = []
    private var lastSave = 0.0
    private let storageKey = "TimeOnTask.workspace.v2"

    var profile: FocusProfile { workspace.selected }
    var profiles: [FocusProfile] { workspace.profiles }
    var selectedProfileID: UUID { workspace.selectedID }
    var elapsed: Double { profile.elapsed }
    var apps: [String: String] { profile.apps }
    var rules: [WebsiteRule] { profile.rules }
    var browsers: [FocusBrowser] { profile.browsers.compactMap(FocusBrowser.find) }
    var canEditTimer: Bool { !armed && elapsed == 0 }
    var mode: Mode {
        get { profile.mode }
        set { guard canEditTimer else { return }; workspace.selected.mode = newValue; save() }
    }
    var durationSeconds: Int {
        get { profile.durationSeconds }
        set { guard canEditTimer else { return }; workspace.selected.durationSeconds = FocusDuration(seconds: newValue).seconds; save() }
    }

    init() {
        workspace = FocusWorkspace.restore(current: UserDefaults.standard.data(forKey: storageKey), legacy: UserDefaults.standard.data(forKey: "FocusTimer.session.v1"))
        clock.elapsed = workspace.selected.elapsed
        let center = NSWorkspace.shared.notificationCenter
        observe(center, NSWorkspace.didActivateApplicationNotification) { model in model.invalidate(); model.refresh() }
        observe(center, NSWorkspace.willSleepNotification) { model in model.suspended = true; model.invalidate(); model.status = "Paused · Mac is asleep"; model.save() }
        observe(center, NSWorkspace.sessionDidResignActiveNotification) { model in model.suspended = true; model.invalidate(); model.status = "Paused · User session inactive"; model.save() }
        observe(center, NSWorkspace.didWakeNotification) { model in model.suspended = false; model.invalidate(); model.refresh() }
        observe(center, NSWorkspace.sessionDidBecomeActiveNotification) { model in model.suspended = false; model.invalidate(); model.refresh() }
        observe(NotificationCenter.default, NSApplication.willTerminateNotification) { $0.save() }
        let ticker = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(ticker, forMode: .common); timer = ticker
        save()
    }
    private func observe(_ center: NotificationCenter, _ name: Notification.Name, action: @escaping @MainActor (FocusModel) -> Void) {
        observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let self { action(self) } }
        })
    }
    var displayedTime: String {
        let value = mode == .countdown ? max(0, Double(durationSeconds) - elapsed) : elapsed
        let seconds = mode == .countdown ? Int(ceil(value)) : Int(value)
        return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }
    var progress: Double { min(1, elapsed / Double(durationSeconds)) }
    var completed: Bool { mode == .countdown && elapsed >= Double(durationSeconds) }
    func toggle() {
        if completed { reset() }
        armed.toggle(); invalidate(); refresh(); save()
    }
    func reset() {
        armed = false; clock = FocusClock(); workspace.selected.elapsed = 0
        invalidate(); status = "Ready when you are"; save()
    }
    private func invalidate() { generation += 1; clock.interrupt(); counting = false }

    func selectProfile(_ id: UUID) {
        guard id != selectedProfileID, profiles.contains(where: { $0.id == id }) else { return }
        armed = false; invalidate(); workspace.selectedID = id
        clock = FocusClock(); clock.elapsed = elapsed; status = "Session paused · \(profile.name)"; save()
    }
    func createProfile(name: String, duplicate: Bool = false, symbol: String = "briefcase.fill", color: FocusColor = .mint) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        armed = false; invalidate(); workspace.add(name: name, duplicate: duplicate)
        workspace.selected.symbol = symbol; workspace.selected.color = color
        clock = FocusClock(); status = "Ready when you are"; save()
    }
    func updateProfile(_ id: UUID, name: String, symbol: String, color: FocusColor) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = workspace.profiles.firstIndex(where: { $0.id == id }) else { return }
        workspace.profiles[index].name = name
        workspace.profiles[index].symbol = symbol
        workspace.profiles[index].color = color
        save()
    }
    func duplicateProfile(_ id: UUID) {
        guard var copy = profiles.first(where: { $0.id == id }) else { return }
        copy.id = UUID(); copy.name += " copy"; copy.elapsed = 0
        workspace.profiles.append(copy); selectProfile(copy.id)
    }
    func deleteProfile(_ id: UUID) {
        guard profiles.count > 1, profiles.contains(where: { $0.id == id }) else { return }
        if id == selectedProfileID {
            armed = false; invalidate(); workspace.removeSelected()
            clock = FocusClock(); clock.elapsed = elapsed; status = "Session paused · \(profile.name)"
        } else { workspace.profiles.removeAll { $0.id == id } }
        save()
    }

    func connectBrowser(_ browser: FocusBrowser) {
        guard !reading else { return }
        guard browser.running else { browserMessages[browser.id] = "Open \(browser.name) first, then connect."; return }
        reading = true; connectingBrowser = browser.id
        reader.read(browser) { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }
                self.reading = false; self.connectingBrowser = nil
                if error == nil { self.connectedBrowsers.insert(browser.id) } else { self.connectedBrowsers.remove(browser.id) }
                self.browserMessages[browser.id] = error ?? "Connected"
                self.invalidate(); self.refresh()
            }
        }
    }
    func addBrowser(_ browser: FocusBrowser) {
        guard !profile.browsers.contains(browser.id) else { return }
        workspace.selected.browsers.append(browser.id)
        workspace.selected.apps.removeValue(forKey: browser.id)
        invalidate(); save()
    }
    func removeBrowser(_ browser: FocusBrowser) {
        workspace.selected.browsers.removeAll { $0 == browser.id }; invalidate(); save()
    }
    func addRule(_ text: String) -> Bool {
        guard let rule = WebsiteRule(text) else { return false }
        if !rules.contains(where: { $0.text == rule.text }) { workspace.selected.rules.append(rule) }
        invalidate(); save(); return true
    }
    func removeRule(_ rule: WebsiteRule) { workspace.selected.rules.removeAll { $0.id == rule.id }; invalidate(); save() }
    func chooseApp() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.application]; panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        appSelectionMessage = nil
        for url in panel.urls {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier, id != Bundle.main.bundleIdentifier else { continue }
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            switch ApplicationSelectionPolicy.destination(bundleIdentifier: id, supportedBrowserIDs: Set(FocusBrowser.supported.map(\.id))) {
            case .supportedBrowser:
                if let browser = FocusBrowser.find(id) { addBrowser(browser) }
            case .unsupportedBrowser:
                appSelectionMessage = "\(name) doesn't have a supported active-tab integration yet. It wasn't added. Firefox requires a browser extension."
            case .nativeApp:
                workspace.selected.apps[id] = name
            }
        }
        invalidate(); save()
    }
    func removeApp(_ id: String) { workspace.selected.apps.removeValue(forKey: id); invalidate(); save() }

    private func refresh() {
        guard armed, !suspended else {
            counting = false
            if !armed { status = completed ? "Session complete" : "Session paused" }
            return
        }
        guard let app = NSWorkspace.shared.frontmostApplication else { sample(false, "Paused · No active app"); return }
        if let browser = app.bundleIdentifier.flatMap(FocusBrowser.find) {
            guard profile.browsers.contains(browser.id) else { sample(false, "Paused · \(browser.name) isn't in this focus mode"); return }
            guard connectedBrowsers.contains(browser.id) else { sample(false, "Paused · Connect \(browser.name) to check websites"); return }
            guard !reading else { return }
            reading = true
            let token = generation
            reader.read(browser) { [weak self] address, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.reading = false
                    guard self.generation == token, self.armed, !self.suspended,
                          NSWorkspace.shared.frontmostApplication?.bundleIdentifier == browser.id else { return }
                    if let error {
                        self.connectedBrowsers.remove(browser.id); self.browserMessages[browser.id] = error
                        self.sample(false, "Paused · \(browser.name) connection unavailable"); return
                    }
                    guard let address, let url = URL(string: address), self.rules.contains(where: { $0.matches(url) }) else {
                        self.sample(false, "Paused · Website is outside this focus mode"); return
                    }
                    self.sample(true, "Focusing · \(url.host ?? browser.name)")
                }
            }
        } else {
            let allowed = app.bundleIdentifier.flatMap { apps[$0] } != nil
            sample(allowed, allowed ? "Focusing · \(app.localizedName ?? "App")" : "Paused · \(app.localizedName ?? "App") is outside this focus mode")
        }
    }
    private func sample(_ eligible: Bool, _ reason: String) {
        clock.sample(at: ProcessInfo.processInfo.systemUptime, eligible: eligible)
        workspace.selected.elapsed = mode == .countdown ? min(clock.elapsed, Double(durationSeconds)) : clock.elapsed
        counting = eligible; status = reason
        if completed {
            armed = false; counting = false; status = "Session complete · Nice work"; clock.interrupt(); NSSound(named: "Glass")?.play(); save()
        } else if ProcessInfo.processInfo.systemUptime - lastSave > 5 { save() }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(workspace) { UserDefaults.standard.set(data, forKey: storageKey) }
        lastSave = ProcessInfo.processInfo.systemUptime
    }
}
