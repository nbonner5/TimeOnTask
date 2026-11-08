import SwiftUI

extension FocusColor {
    func tint(for scheme: ColorScheme) -> Color {
        let rgb: (Double, Double, Double)
        switch (self, scheme == .dark) {
        case (.mint, false): rgb = (0.06, 0.43, 0.33)
        case (.mint, true): rgb = (0.42, 0.86, 0.71)
        case (.blue, false): rgb = (0.09, 0.36, 0.65)
        case (.blue, true): rgb = (0.51, 0.70, 1)
        case (.purple, false): rgb = (0.45, 0.25, 0.69)
        case (.purple, true): rgb = (0.77, 0.64, 0.96)
        case (.pink, false): rgb = (0.70, 0.15, 0.44)
        case (.pink, true): rgb = (0.96, 0.64, 0.78)
        case (.red, false): rgb = (0.74, 0.20, 0.18)
        case (.red, true): rgb = (1, 0.67, 0.64)
        case (.orange, false): rgb = (0.57, 0.30, 0.04)
        case (.orange, true): rgb = (1, 0.74, 0.50)
        case (.yellow, false): rgb = (0.46, 0.38, 0)
        case (.yellow, true): rgb = (0.91, 0.81, 0.38)
        case (.graphite, false): rgb = (0.30, 0.35, 0.39)
        case (.graphite, true): rgb = (0.73, 0.76, 0.79)
        }
        return Color(red: rgb.0, green: rgb.1, blue: rgb.2)
    }
}

struct FocusModeBadge: View {
    let symbol: String
    let color: FocusColor
    var size: CGFloat = 36
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Image(systemName: symbol).font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(color.tint(for: scheme))
            .frame(width: size, height: size)
            .background(color.tint(for: scheme).opacity(0.13), in: RoundedRectangle(cornerRadius: size * 0.27))
            .accessibilityHidden(true)
    }
}

struct FocusModeManager: View {
    @ObservedObject var model: FocusModel
    let startWithNew: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var editingID: UUID?
    @State private var name = ""
    @State private var symbol = "briefcase.fill"
    @State private var color: FocusColor = .mint
    @State private var confirmDelete = false
    @State private var saved = false
    private var validName: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus modes").font(.title2.weight(.semibold))
                    Text("A different space for every kind of work.").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(24)
            Divider()
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    List(selection: Binding<UUID?>(get: { editingID }, set: { id in
                        if let profile = model.profiles.first(where: { $0.id == id }) { load(profile) }
                    })) {
                        ForEach(model.profiles) { profile in
                            HStack(spacing: 10) {
                                FocusModeBadge(symbol: profile.symbol, color: profile.color, size: 32)
                                Text(profile.name).lineLimit(2)
                                Spacer(minLength: 0)
                            }.padding(.vertical, 5).tag(profile.id)
                        }
                    }.listStyle(.sidebar)
                    Divider()
                    Button("New focus mode", systemImage: "plus") { newDraft() }.frame(maxWidth: .infinity).padding(16)
                }.frame(width: 220)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(spacing: 14) {
                            FocusModeBadge(symbol: symbol, color: color, size: 60)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(name.isEmpty ? "New focus mode" : name).font(.title2.weight(.semibold)).lineLimit(2)
                                Text(editingID == nil ? "Choose a name, icon, and color." : "Personalize this focus mode.").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        TextField("Name", text: $name).textFieldStyle(.roundedBorder).onChange(of: name) { _, _ in saved = false }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Color").font(.headline)
                            HStack(spacing: 10) {
                                ForEach(FocusColor.allCases) { option in
                                    Button { color = option; saved = false } label: {
                                        Circle().fill(option.tint(for: scheme)).frame(width: 28, height: 28)
                                            .overlay { if color == option { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(scheme == .dark ? .black : .white) } }
                                            .padding(3).overlay(Circle().stroke(color == option ? option.tint(for: scheme) : .clear, lineWidth: 2))
                                    }.buttonStyle(.plain).help(option.name).accessibilityLabel("\(option.name) color").accessibilityAddTraits(color == option ? .isSelected : [])
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Icon").font(.headline)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                                ForEach(FocusSymbols.all, id: \.self) { option in
                                    Button { symbol = option; saved = false } label: {
                                        Image(systemName: option).font(.system(size: 19)).frame(maxWidth: .infinity).frame(height: 42)
                                            .foregroundStyle(symbol == option ? color.tint(for: scheme) : .primary)
                                            .background(symbol == option ? color.tint(for: scheme).opacity(0.15) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
                                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(symbol == option ? color.tint(for: scheme) : .clear, lineWidth: 1.5))
                                    }.buttonStyle(.plain).help(FocusSymbols.displayName(option)).accessibilityLabel("\(FocusSymbols.displayName(option)) icon").accessibilityAddTraits(symbol == option ? .isSelected : [])
                                }
                            }
                        }
                        HStack {
                            if let id = editingID {
                                Button("Duplicate", systemImage: "doc.on.doc") { model.duplicateProfile(id); load(model.profile) }
                                Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }.disabled(model.profiles.count == 1)
                            }
                            Spacer()
                            Button(editingID == nil ? "Create mode" : saved ? "Saved" : "Save changes") { save() }
                                .buttonStyle(.borderedProminent).tint(color.tint(for: scheme)).disabled(!validName || saved)
                        }
                        if editingID != nil { Text("Apps, websites, and session progress are kept when you change the name, icon, or color.").font(.caption).foregroundStyle(.secondary) }
                    }.padding(24)
                }.frame(width: 420)
            }
        }.frame(width: 641, height: 610)
        .onAppear { if startWithNew { newDraft() } else { load(model.profile) } }
        .alert("Delete \(name)?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete focus mode", role: .destructive) {
                if let editingID { model.deleteProfile(editingID); load(model.profile) }
            }
        } message: { Text("This removes its rules and saved session progress. Your other focus modes are kept.") }
    }
    private func load(_ profile: FocusProfile) {
        editingID = profile.id; name = profile.name; symbol = profile.symbol; color = profile.color; saved = false
    }
    private func newDraft() { editingID = nil; name = ""; symbol = "briefcase.fill"; color = .mint; saved = false }
    private func save() {
        guard validName else { return }
        if let editingID { model.updateProfile(editingID, name: name, symbol: symbol, color: color) }
        else { model.createProfile(name: name, symbol: symbol, color: color); editingID = model.selectedProfileID }
        saved = true
    }
}
