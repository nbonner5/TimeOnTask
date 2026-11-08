import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var model: FocusModel
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    @State private var newRule = ""
    @State private var ruleError = false
    @State private var modeManagerRequest: ModeManagerRequest?
    private enum ModeManagerRequest: String, Identifiable {
        case create, manage
        var id: String { rawValue }
    }

    private var accent: Color { model.profile.color.tint(for: colorScheme) }
    private var panel: Color { colorScheme == .dark ? .white.opacity(0.035) : .white.opacity(0.8) }
    private var row: Color { colorScheme == .dark ? .white.opacity(0.045) : .black.opacity(0.035) }
    private var separator: Color { Color.primary.opacity(0.08) }
    private var background: Color { colorScheme == .dark ? Color(red: 0.055, green: 0.075, blue: 0.085) : Color(red: 0.95, green: 0.965, blue: 0.955) }

    var body: some View {
        HStack(spacing: 0) {
            GeometryReader { geometry in
                ScrollView {
                    timerColumn.frame(minHeight: max(0, geometry.size.height - 56)).padding(28)
                }.scrollIndicators(.hidden)
            }.frame(width: 380)
            Rectangle().fill(separator).frame(width: 1)
            ScrollView { focusColumn.padding(28) }.frame(maxWidth: .infinity)
        }
        .background(background)
        .preferredColorScheme(appearance.colorScheme)
        .sheet(item: $modeManagerRequest) { request in
            FocusModeManager(model: model, startWithNew: request == .create)
        }
    }

    private var timerColumn: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 8) {
                Image("BrandIcon").renderingMode(.template).resizable().scaledToFit().frame(width: 32, height: 32).foregroundStyle(accent).accessibilityHidden(true)
                Text("TIME ON TASK").font(.system(size: 12, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(accent)
            }.accessibilityElement(children: .combine)
            VStack(alignment: .leading, spacing: 6) {
                Text(model.mode == .countdown ? "Timer" : "Stopwatch").font(.system(size: 36, weight: .semibold, design: .rounded))
                HStack(spacing: 8) {
                    FocusModeBadge(symbol: model.profile.symbol, color: model.profile.color, size: 28)
                    Text(model.profile.name).font(.title3).foregroundStyle(.secondary)
                }
            }
            Picker("Timer mode", selection: Binding(get: { model.mode }, set: { model.mode = $0 })) {
                ForEach(FocusModel.Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).disabled(!model.canEditTimer)
            Spacer(minLength: 0)
            if model.mode == .countdown && model.canEditTimer {
                DurationPicker(seconds: Binding(get: { model.durationSeconds }, set: { model.durationSeconds = $0 }), tint: accent)
                    .padding(.vertical, 16)
                Text("Select a segment. Type digits or use ↑ ↓.\nUse ← → or Tab to move between segments.")
                    .font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity).multilineTextAlignment(.center)
            } else {
                ZStack {
                    Circle().stroke(separator, lineWidth: 7)
                    if model.mode == .countdown {
                        Circle().trim(from: 0, to: model.progress).stroke(accent, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                    }
                    VStack(spacing: 12) {
                        Text(model.mode == .countdown ? "REMAINING" : "ACCUMULATED")
                            .font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1.5).foregroundStyle(.secondary)
                        Text(model.displayedTime).font(.system(size: 37, weight: .light, design: .monospaced)).contentTransition(.numericText())
                        Label(model.counting ? "Counting" : model.armed ? "Waiting for focus" : model.completed ? "Complete" : model.elapsed > 0 ? "Paused" : "Ready", systemImage: model.counting ? "circle.fill" : "pause.fill")
                            .font(.caption).foregroundStyle(model.counting ? accent : .secondary)
                    }
                }.frame(width: 252, height: 252).frame(maxWidth: .infinity)
                if model.mode == .countdown {
                    Text("Goal · \(DurationPicker.description(model.durationSeconds))").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            Spacer(minLength: 0)
            HStack {
                Button { model.toggle() } label: {
                    Label(model.armed ? "Pause" : model.completed ? "New timer" : model.elapsed > 0 ? "Resume" : "Start", systemImage: model.armed ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 14).background(accent, in: Capsule())
                }.buttonStyle(.plain).foregroundStyle(colorScheme == .dark ? .black : .white)
                Button { model.reset() } label: { Image(systemName: "arrow.counterclockwise").frame(width: 42, height: 42).background(separator, in: Circle()) }
                    .buttonStyle(.plain).help("Reset this session").accessibilityLabel("Reset session")
            }
            Text(model.status).font(.caption).foregroundStyle(.secondary).frame(height: 38, alignment: .leading)
        }
    }

    private var focusColumn: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Focus modes").font(.title2.weight(.semibold))
                    Spacer()
                    Button("Manage") { modeManagerRequest = .manage }
                }
                VStack(spacing: 10) {
                    ForEach(model.profiles) { profile in
                        Button { model.selectProfile(profile.id); newRule = ""; ruleError = false } label: {
                            HStack(spacing: 10) {
                                FocusModeBadge(symbol: profile.symbol, color: profile.color)
                                Text(profile.name).font(.callout.weight(.medium)).lineLimit(2).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                if model.selectedProfileID == profile.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(profile.color.tint(for: colorScheme))
                                }
                            }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                .background(model.selectedProfileID == profile.id ? profile.color.tint(for: colorScheme).opacity(0.09) : panel, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.selectedProfileID == profile.id ? profile.color.tint(for: colorScheme).opacity(0.55) : separator, lineWidth: 1))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityAddTraits(model.selectedProfileID == profile.id ? .isSelected : [])
                    }
                }
                Button("New focus mode", systemImage: "plus") { modeManagerRequest = .create }
                Text("Each mode keeps its own rules, timer, and progress. Switching modes pauses your session.").font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel("APPS", icon: "macwindow")
                if model.apps.isEmpty { Text("Add an editor, design tool, or another app you work in.").font(.callout).foregroundStyle(.secondary) }
                ForEach(model.apps.keys.sorted(), id: \.self) { id in
                    HStack(spacing: 10) {
                        ApplicationIcon(bundleIdentifier: id)
                        Text(model.apps[id] ?? id).font(.callout)
                        Spacer()
                        removeButton(model.apps[id] ?? id) { model.removeApp(id) }
                    }.padding(10).background(row, in: RoundedRectangle(cornerRadius: 8))
                }
                Button("Add application…", systemImage: "plus") { model.chooseApp() }
                if let message = model.appSelectionMessage { Text(message).font(.caption).foregroundStyle(.orange) }
            }.padding(18).background(panel, in: RoundedRectangle(cornerRadius: 16))
            browsersPanel
            websitesPanel
            Picker("Appearance", selection: $appearance) {
                ForEach(AppAppearance.allCases) { value in Text(value.rawValue).tag(value) }
            }.pickerStyle(.menu)
            Text("Stored on this Mac. No browsing history is saved.\nReading and thinking count; inactivity detection is off.").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var browsersPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("BROWSERS", icon: "network")
            ForEach(model.browsers) { browser in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        ApplicationIcon(bundleIdentifier: browser.id)
                        Text(browser.name).font(.callout.weight(.medium))
                        Spacer()
                        removeButton(browser.name) { model.removeBrowser(browser) }
                    }
                    if let message = model.browserMessages[browser.id] {
                        Text(message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Button(model.connectingBrowser == browser.id ? "Connecting…" : model.connectedBrowsers.contains(browser.id) ? "Reconnect" : "Connect \(browser.name)") { model.connectBrowser(browser) }
                        .disabled(model.connectingBrowser != nil)
                }
                if browser.id != model.browsers.last?.id { Divider() }
            }
            Menu {
                let available = FocusBrowser.supported.filter { $0.installed && !model.profile.browsers.contains($0.id) }
                ForEach(available) { browser in Button(browser.name) { model.addBrowser(browser) } }
                if available.isEmpty { Text("No other supported browsers installed") }
            } label: { Label("Add browser", systemImage: "plus") }
            Text("Safari and supported Chromium browsers. Each browser needs Automation permission. Firefox requires an extension.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(18).background(panel, in: RoundedRectangle(cornerRadius: 16))
    }

    private var websitesPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("WEBSITES", icon: "globe")
            Text("Shared by every browser in this focus mode.").font(.caption).foregroundStyle(.secondary)
            if model.rules.isEmpty {
                Text("Add the websites that count toward this focus mode.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(model.rules) { rule in
                HStack {
                    Label(rule.text, systemImage: "link").font(.system(size: 12, design: .monospaced))
                    Spacer(); removeButton(rule.text) { model.removeRule(rule) }
                }.padding(10).background(row, in: RoundedRectangle(cornerRadius: 8))
            }
            HStack {
                TextField("e.g. youtube.com or wikipedia.org", text: $newRule).textFieldStyle(.roundedBorder).onSubmit(addRule)
                Button(action: addRule) { Image(systemName: "plus") }.accessibilityLabel("Add website")
            }
            if ruleError { Text("Enter a website like youtube.com, without a page path or wildcard.").font(.caption).foregroundStyle(.orange) }
            Text("Includes the www version of each website. Add other subdomains separately. Private Chromium windows are excluded; other browsers may expose private tabs through Automation.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(18).background(panel, in: RoundedRectangle(cornerRadius: 16))
    }
    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(1.3).foregroundStyle(.secondary)
    }
    private func removeButton(_ title: String, remove: @escaping () -> Void) -> some View {
        Button(action: remove) { Image(systemName: "xmark").font(.caption2).foregroundStyle(.secondary) }
            .buttonStyle(.plain).help("Remove \(title)").accessibilityLabel("Remove \(title)")
    }
    private func addRule() { if model.addRule(newRule) { newRule = ""; ruleError = false } else { ruleError = true } }
}

private struct ApplicationIcon: View {
    let bundleIdentifier: String
    @State private var image: NSImage?
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().interpolation(.high).scaledToFit() }
            else { Image(systemName: "app.fill").resizable().scaledToFit().foregroundStyle(.secondary) }
        }.frame(width: 28, height: 28).accessibilityHidden(true)
        .task(id: bundleIdentifier) {
            image = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier).map { NSWorkspace.shared.icon(forFile: $0.path) }
        }
    }
}
