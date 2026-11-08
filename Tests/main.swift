import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
let local = WebsiteRule("localhost")!
check(local.matches(URL(string: "http://localhost:3000/editor")!), "localhost should accept development ports")
check(!local.matches(URL(string: "https://localhost.evil.com")!), "must reject hostname suffix spoofing")
check(!local.matches(URL(string: "https://localhost@evil.com")!), "must reject user-info spoofing")
check(!local.matches(URL(string: "file://localhost/work")!), "must reject non-web schemes")
let port = WebsiteRule("LOCALHOST:3000")!
check(port.matches(URL(string: "http://localhost:3000")!), "explicit port should match")
check(!port.matches(URL(string: "http://localhost:3001")!), "other port should not match")
check(WebsiteRule("example.com:443")!.matches(URL(string: "https://example.com")!), "default HTTPS port should match")
check(!WebsiteRule("example.com")!.matches(URL(string: "https://sub.example.com")!), "subdomains require explicit rules")
for input in ["", "*.example.com", "https://user:pass@example.com", "example.com/path", "example.com?x=1", "file://localhost", "localhost:99999", "localhost:0"] {
    check(WebsiteRule(input) == nil, "must reject invalid rule: \(input)")
}
var clock = FocusClock()
clock.sample(at: 10, eligible: true)
clock.sample(at: 10.5, eligible: true)
check(clock.elapsed == 0.5, "eligible interval should count")
clock.sample(at: 11, eligible: false)
clock.sample(at: 12, eligible: true)
check(clock.elapsed == 0.5, "ineligible transitions should not count")
clock.sample(at: 12.5, eligible: true)
check(clock.elapsed == 1, "resumed interval should count")
clock.sample(at: 100, eligible: true)
check(clock.elapsed == 1, "sleep or delayed sampling must not count")
clock.interrupt()
clock.sample(at: 101, eligible: true)
check(clock.elapsed == 1, "interrupt must clear the prior interval")
clock.sample(at: 100, eligible: true)
check(clock.elapsed == 1, "backward time must not subtract work")
print("Passed: hostname rules, ports, spoofing, eligibility transitions, interruptions, and timing gaps.")

check(FocusDuration(hours: 2, minutes: 3, seconds: 4).seconds == 7384, "custom duration must preserve hours, minutes, and seconds")
check(FocusDuration(seconds: 1).seconds == 1, "one-second timers must work")
check(FocusDuration(seconds: 0).seconds == 1, "zero-duration timers must be prevented")
check(FocusDuration(seconds: 90).minutes == 1 && FocusDuration(seconds: 90).remainderSeconds == 30, "seconds must decompose correctly")
check(FocusDuration(hours: 99, minutes: 59, seconds: 59).seconds == 359999, "long timers must work")
let legacy = Data(#"{"mode":"Countdown","minutes":45,"elapsed":125.5,"rules":["localhost:3000"],"apps":{"com.apple.dt.Xcode":"Xcode"}}"#.utf8)
var workspace = FocusWorkspace.restore(current: nil, legacy: legacy)
let originalID = workspace.selectedID
check(workspace.selected.durationSeconds == 2700 && workspace.selected.elapsed == 125.5, "migration must preserve duration and progress")
check(workspace.selected.rules[0].text == "localhost:3000", "migration must preserve website rules")
check(workspace.selected.apps["com.apple.dt.Xcode"] == "Xcode", "migration must preserve selected apps")
workspace.add(name: "Writing", duplicate: true)
check(workspace.selectedID != originalID && workspace.selected.elapsed == 0, "duplicating a mode must start a fresh session")
check(workspace.selected.apps["com.apple.dt.Xcode"] == "Xcode", "duplicating must copy the rules")
workspace.selected.apps.removeAll()
workspace.selected.rules = [WebsiteRule("example.com")!]
workspace.selected.elapsed = 60
workspace.selectedID = originalID
check(workspace.selected.apps.count == 1 && workspace.selected.elapsed == 125.5, "profiles must retain independent rules and progress")
let encoded = try! JSONEncoder().encode(workspace)
let restored = FocusWorkspace.restore(current: encoded, legacy: legacy)
check(restored.profiles.count == 2 && restored.selectedID == originalID && restored.selected.elapsed == 125.5, "all focus modes and selection must survive relaunch")
workspace.removeSelected()
check(workspace.profiles.count == 1 && workspace.selected.name == "Writing", "deleting a mode must select a remaining mode")
workspace.removeSelected()
check(workspace.profiles.count == 1, "the final mode must not be deletable")
check(FocusWorkspace.restore(current: Data("invalid".utf8), legacy: legacy).selected.elapsed == 125.5, "corrupt new data should fall back to legacy data")
print("Passed: custom durations, legacy migration, independent focus modes, duplication, deletion, and persistence.")

// These real desktop applications must remain selectable even when they handle
// web URLs. Browser classification must not depend on URL-scheme registration.
let supportedBrowserIDs: Set<String> = ["com.google.Chrome", "com.apple.Safari"]
for id in ["com.openai.codex", "com.apple.dt.Xcode", "com.microsoft.VSCode", "com.example.web-link-client"] {
    check(ApplicationSelectionPolicy.destination(bundleIdentifier: id, supportedBrowserIDs: supportedBrowserIDs) == .nativeApp, "regular app incorrectly blocked: \(id)")
}
check(ApplicationSelectionPolicy.destination(bundleIdentifier: "com.google.Chrome", supportedBrowserIDs: supportedBrowserIDs) == .supportedBrowser, "Chrome must keep website rules")
check(ApplicationSelectionPolicy.destination(bundleIdentifier: "org.mozilla.firefox", supportedBrowserIDs: supportedBrowserIDs) == .unsupportedBrowser, "Firefox must not silently bypass website rules")
check(ApplicationSelectionPolicy.destination(bundleIdentifier: "org.mozilla.firefox", supportedBrowserIDs: ["org.mozilla.firefox"]) == .supportedBrowser, "a future supported integration must take precedence")
print("Passed: native app selection, supported browser routing, and unsupported browser handling.")

var segment = TimeSegmentEntry()
check(segment.enter(2, at: 10, maximum: 59) == 2, "first digit must replace the segment")
check(segment.enter(7, at: 10.2, maximum: 59) == 27, "second digit must append")
check(segment.enter(4, at: 10.4, maximum: 59) == 4, "typing after two digits must start a new value")
check(segment.enter(8, at: 13, maximum: 59) == 8, "typing after a pause must replace the value")
check(segment.enter(9, at: 13.1, maximum: 59) == 59, "minutes and seconds must stay within bounds")
segment.reset()
check(segment.enter(0, at: 14, maximum: 99) == 0, "zero must be enterable")
check(segment.enter(5, at: 14.1, maximum: 99) == 5, "leading-zero entry must work")

var styled = FocusWorkspace(profile: FocusProfile(name: "Design"))
styled.selected.symbol = "paintpalette.fill"; styled.selected.color = .purple; styled.selected.elapsed = 93
let styledData = try! JSONEncoder().encode(styled)
let styledRestored = FocusWorkspace.restore(current: styledData, legacy: nil)
check(styledRestored.selected.color == .purple && styledRestored.selected.symbol == "paintpalette.fill" && styledRestored.selected.elapsed == 93, "mode appearance and progress must survive relaunch")
styled.add(name: "Design copy", duplicate: true)
check(styled.selected.color == .purple && styled.selected.symbol == "paintpalette.fill" && styled.selected.elapsed == 0, "duplicating must copy appearance into a fresh session")
var beforeAppearance = try! JSONSerialization.jsonObject(with: styledData) as! [String: Any]
var oldProfiles = beforeAppearance["profiles"] as! [[String: Any]]
oldProfiles[0].removeValue(forKey: "symbol"); oldProfiles[0].removeValue(forKey: "color")
beforeAppearance["profiles"] = oldProfiles
let oldWorkspace = FocusWorkspace.restore(current: try! JSONSerialization.data(withJSONObject: beforeAppearance), legacy: nil)
check(oldWorkspace.selected.name == "Design" && oldWorkspace.selected.elapsed == 93 && oldWorkspace.selected.symbol == "briefcase.fill" && oldWorkspace.selected.color == .mint, "existing modes must migrate without losing settings or progress")
print("Passed: segment digit entry, focus-mode icon/color persistence, duplication, and appearance migration.")

let youtube = WebsiteRule("youtube.com")!
check(youtube.matches(URL(string: "https://www.youtube.com/watch?v=example")!), "YouTube's www address must count for youtube.com")
check(WebsiteRule("www.youtube.com")!.matches(URL(string: "https://youtube.com")!), "www and bare domains must match in either direction")
check(WebsiteRule("https://WWW.YouTube.com/")!.text == "youtube.com", "new rules must normalize common pasted website addresses")
check(!youtube.matches(URL(string: "https://youtube.com.evil.com")!), "www normalization must not allow lookalike suffixes")
check(!youtube.matches(URL(string: "https://notyoutube.com")!), "website matching must retain domain boundaries")
check(!youtube.matches(URL(string: "https://m.youtube.com")!), "other subdomains must still need their own rules")
check(!WebsiteRule("127.0.0.1")!.matches(URL(string: "http://www.127.0.0.1")!), "IP rules must remain exact")
check(!WebsiteRule("localhost")!.matches(URL(string: "http://www.localhost")!), "local names must remain exact")
check(!WebsiteRule("youtube.com:443")!.matches(URL(string: "https://www.youtube.com:8443")!), "normalization must preserve port restrictions")
let savedWWWRule = try! JSONDecoder().decode(WebsiteRule.self, from: Data(#"{"text":"www.youtube.com","host":"www.youtube.com","port":null}"#.utf8))
check(savedWWWRule.matches(URL(string: "https://youtube.com")!), "existing saved www rules must work without being re-added")
check(FocusProfile(name: "New mode").rules.isEmpty, "new focus modes must not add developer websites")
check(FocusWorkspace().selected.rules.isEmpty, "a fresh workspace must start without website rules")
print("Passed: YouTube www matching, existing saved rules, hostname boundaries, ports, and empty website defaults.")
