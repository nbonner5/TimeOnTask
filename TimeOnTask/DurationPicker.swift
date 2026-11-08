import SwiftUI
import AppKit

struct DurationPicker: View {
    @Binding var seconds: Int
    var tint: Color
    @StateObject private var focus = SegmentFocusGroup()
    private var duration: FocusDuration { FocusDuration(seconds: seconds) }
    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            component("Hours", index: 0, value: duration.hours, maximum: 99) { seconds = FocusDuration(hours: $0, minutes: duration.minutes, seconds: duration.remainderSeconds).seconds }
            colon
            component("Minutes", index: 1, value: duration.minutes, maximum: 59) { seconds = FocusDuration(hours: duration.hours, minutes: $0, seconds: duration.remainderSeconds).seconds }
            colon
            component("Seconds", index: 2, value: duration.remainderSeconds, maximum: 59) { seconds = FocusDuration(hours: duration.hours, minutes: duration.minutes, seconds: $0).seconds }
        }.fixedSize(horizontal: true, vertical: true).frame(maxWidth: .infinity)
    }
    private var colon: some View {
        Text(":").font(.system(size: 32, weight: .light, design: .rounded))
            .foregroundStyle(.tertiary).frame(width: 10, height: 64).accessibilityHidden(true)
    }
    private func component(_ label: String, index: Int, value: Int, maximum: Int, set: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 8) {
            NumberSegment(value: value, maximum: maximum, label: label, index: index, tint: tint, focus: focus, changed: set)
                .frame(width: 80, height: 64)
            Text(label.lowercased()).font(.caption).foregroundStyle(.secondary)
        }
    }
    static func description(_ seconds: Int) -> String {
        let duration = FocusDuration(seconds: seconds)
        return "\(duration.hours) hr \(duration.minutes) min \(duration.remainderSeconds) sec"
    }
}

private final class SegmentFocusGroup: ObservableObject {
    private let controls = NSMapTable<NSNumber, DurationSegmentControl>(keyOptions: .strongMemory, valueOptions: .weakMemory)
    func register(_ control: DurationSegmentControl, at index: Int) { controls.setObject(control, forKey: NSNumber(value: index)) }
    @discardableResult func move(from index: Int, by offset: Int) -> Bool {
        guard let target = controls.object(forKey: NSNumber(value: index + offset)) else { return false }
        return target.window?.makeFirstResponder(target) ?? false
    }
}

private struct NumberSegment: NSViewRepresentable {
    let value: Int
    let maximum: Int
    let label: String
    let index: Int
    let tint: Color
    let focus: SegmentFocusGroup
    let changed: (Int) -> Void

    func makeNSView(context: Context) -> DurationSegmentControl {
        let view = DurationSegmentControl()
        focus.register(view, at: index)
        return view
    }
    func updateNSView(_ view: DurationSegmentControl, context: Context) {
        view.value = value; view.maximum = maximum; view.tint = NSColor(tint)
        view.changed = changed
        view.navigate = { offset in focus.move(from: index, by: offset) }
        view.setAccessibilityLabel(label)
        view.setAccessibilityValue(NSNumber(value: value))
        view.needsDisplay = true
    }
}

/// A number control, not a text editor: keyboard input without a text caret.
private final class DurationSegmentControl: NSControl {
    var value = 0
    var maximum = 59
    var tint = NSColor.controlAccentColor
    var changed: ((Int) -> Void)?
    var navigate: ((Int) -> Bool)?
    private var entry = TimeSegmentEntry()
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 80, height: 64) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        focusRingType = .none
        setAccessibilityElement(true)
        setAccessibilityRole(.incrementor)
        setAccessibilityHelp("Type digits to replace this value. Use Up and Down to adjust it, and Left, Right, or Tab to select another segment.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }
    override func becomeFirstResponder() -> Bool { entry.reset(); needsDisplay = true; return true }
    override func resignFirstResponder() -> Bool { entry.reset(); needsDisplay = true; return true }
    override func draw(_ dirtyRect: NSRect) {
        guard bounds.width > 2, bounds.height > 2 else { return }
        if window?.firstResponder === self {
            let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 12, yRadius: 12)
            tint.withAlphaComponent(0.14).setFill(); shape.fill()
            tint.withAlphaComponent(0.45).setStroke(); shape.lineWidth = 1; shape.stroke()
        }
        let text = String(format: "%02d", value)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 38, weight: .light),
            .foregroundColor: NSColor.labelColor
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attributes)
    }
    private func set(_ candidate: Int) {
        value = min(maximum, max(0, candidate)); changed?(value)
        setAccessibilityValue(NSNumber(value: value)); needsDisplay = true
        NSAccessibility.post(element: self, notification: .valueChanged)
    }
    private func adjust(_ delta: Int) { entry.reset(); set(value + delta) }
    override func accessibilityPerformIncrement() -> Bool { adjust(1); return true }
    override func accessibilityPerformDecrement() -> Bool { adjust(-1); return true }
    override func keyDown(with event: NSEvent) {
        if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty { super.keyDown(with: event); return }
        switch event.keyCode {
        case 126: adjust(1)
        case 125: adjust(-1)
        case 123: entry.reset(); _ = navigate?(-1)
        case 124: entry.reset(); _ = navigate?(1)
        case 48:
            entry.reset()
            let backwards = event.modifierFlags.contains(.shift)
            if navigate?(backwards ? -1 : 1) != true {
                if backwards { window?.selectPreviousKeyView(self) } else { window?.selectNextKeyView(self) }
            }
        case 51, 117: entry.reset(); set(0)
        case 36, 76: entry.reset(); window?.makeFirstResponder(nil)
        default:
            if let text = event.charactersIgnoringModifiers, text.count == 1, let digit = text.first?.wholeNumberValue {
                set(entry.enter(digit, at: ProcessInfo.processInfo.systemUptime, maximum: maximum))
            } else { super.keyDown(with: event) }
        }
    }
}
