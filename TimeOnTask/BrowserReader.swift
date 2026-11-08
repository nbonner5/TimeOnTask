import AppKit

struct FocusBrowser: Identifiable, Sendable {
    enum Scripting: Sendable { case chromium, safari, activeTab }
    let id: String
    let name: String
    let scripting: Scripting

    static let supported: [FocusBrowser] = [
        .init(id: "com.apple.Safari", name: "Safari", scripting: .safari),
        .init(id: "com.google.Chrome", name: "Google Chrome", scripting: .chromium),
        .init(id: "com.brave.Browser", name: "Brave", scripting: .chromium),
        .init(id: "com.microsoft.edgemac", name: "Microsoft Edge", scripting: .chromium),
        .init(id: "com.vivaldi.Vivaldi", name: "Vivaldi", scripting: .chromium),
        .init(id: "com.operasoftware.Opera", name: "Opera", scripting: .chromium),
        .init(id: "org.chromium.Chromium", name: "Chromium", scripting: .chromium),
        .init(id: "company.thebrowser.Browser", name: "Arc", scripting: .activeTab),
        .init(id: "company.thebrowser.dia", name: "Dia", scripting: .activeTab)
    ]
    static func find(_ id: String) -> FocusBrowser? { supported.first { $0.id == id } }
    var installed: Bool { NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil }
    var running: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty }

    // Use fixed, known bundle IDs. Do not interpolate user-entered AppleScript.
    var scriptSource: String {
        let tab = scripting == .safari ? "current tab" : "active tab"
        let privateCheck = scripting == .chromium ? "if mode of front window is \"incognito\" then return \"\"" : ""
        return """
        with timeout of 2 seconds
            tell application id "\(id)"
                if (count of windows) is 0 then return ""
                \(privateCheck)
                return URL of \(tab) of front window
            end tell
        end timeout
        """
    }
}

final class BrowserReader: @unchecked Sendable {
    private let queue = DispatchQueue(label: "TimeOnTask.Browser")
    func read(_ browser: FocusBrowser, completion: @escaping @Sendable (String?, String?) -> Void) {
        queue.async {
            // Do not launch a closed browser just to poll it.
            guard browser.running else { completion(nil, "Open \(browser.name), then connect."); return }
            var error: NSDictionary?
            guard let script = NSAppleScript(source: browser.scriptSource) else {
                completion(nil, "Could not prepare \(browser.name) integration."); return
            }
            let result = script.executeAndReturnError(&error)
            if let error {
                let denied = (error[NSAppleScript.errorNumber] as? Int) == -1743
                completion(nil, denied ? "Permission denied. Enable \(browser.name) under Time on Task in System Settings → Privacy & Security → Automation, then reconnect." : "\(browser.name) is unavailable or its tab could not be read. Reconnect to try again.")
            } else { completion(result.stringValue, nil) }
        }
    }
}
