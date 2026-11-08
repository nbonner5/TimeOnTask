import SwiftUI
import AppKit

@main
struct TimeOnTaskApp: App {
    @NSApplicationDelegateAdaptor(TimeOnTaskDelegate.self) private var appDelegate
    @StateObject private var model = FocusModel()
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    var body: some Scene {
        Window("Time on Task", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 780, minHeight: 740)
        }
        .defaultSize(width: 860, height: 760)
        .windowStyle(.hiddenTitleBar)
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 14) {
                Text(model.displayedTime).font(.system(size: 30, weight: .medium, design: .monospaced))
                Text(model.status).font(.caption).foregroundStyle(.secondary)
                Button(model.armed ? "Pause session" : "Start session") { model.toggle() }
                Button("Reset session") { model.reset() }
                Picker("Focus mode", selection: Binding(get: { model.selectedProfileID }, set: { model.selectProfile($0) })) {
                    ForEach(model.profiles) { profile in Label(profile.name, systemImage: profile.symbol).tag(profile.id) }
                }
                Divider()
                ShowWindowButton()
                Button("Quit Time on Task") { NSApplication.shared.terminate(nil) }
            }.padding(20).frame(width: 310)
                .preferredColorScheme(appearance.colorScheme)
        } label: {
            Label(model.armed ? model.displayedTime : "Time on Task", systemImage: model.counting ? "timer" : "pause.circle")
            .help(model.status)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct ShowWindowButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Open Time on Task") {
            // Target the main scene, never a menu-bar panel or a system-owned window.
            openWindow(id: "main")
            NSApplication.shared.activate()
        }
    }
}


enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}


@MainActor
private final class TimeOnTaskDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // This is a regular Mac app with a menu bar companion, not a menu-only agent.
        NSApplication.shared.setActivationPolicy(.regular)
    }
}
