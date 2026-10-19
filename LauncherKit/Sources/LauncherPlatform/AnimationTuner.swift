#if DEBUG
import AppKit
import LauncherCore
import Observation
import SwiftUI
import Synchronization

/// The tuning Debug builds' flights read. Starts as the shipped one; the tuner writes it.
let tunerOverride = Mutex(LaunchTuning.shipped)

/// Debug builds only: a floating window with a slider per `LaunchTuning` knob, for polishing the launch animation and
/// the launch bounce. Changes apply to the next gesture or bounce at once. The current tuning and named presets persist in user defaults. To
/// ship a tuning, copy its values into `LaunchTuning`'s defaults.
@MainActor final class AnimationTuner {
    private let panel: NSPanel

    init(preview: @escaping @MainActor () -> Void, previewBounce: @escaping @MainActor (Bool) -> Void) {
        let model = TunerModel()
        let content = NSHostingView(
            rootView: TunerView(model: model, preview: preview, previewBounce: previewBounce))
        panel = TunerPanel(
            contentRect: CGRect(x: 0, y: 0, width: 420, height: 760),
            styleMask: [.titled, .resizable, .utilityWindow, .miniaturizable], backing: .buffered, defer: false)
        panel.title = "Launch animation & bounce tuner"
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = content
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameTopLeftPoint(CGPoint(x: frame.maxX - 440, y: frame.maxY - 20))
        }
    }

    func show() {
        panel.orderFrontRegardless()
    }
}

/// Takes keyboard focus and activates the app on any click, so the preset name field receives typing even though
/// the app is a menu bar app that is otherwise never active.
private final class TunerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override init(
        contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        acceptsMouseMovedEvents = true
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            NSApp.activate()
            makeKey()
        }
        super.sendEvent(event)
    }
}

struct TuningPreset: Codable, Identifiable, Equatable {
    var name: String
    var tuning: LaunchTuning
    var id: String { name }
}

@MainActor @Observable final class TunerModel {
    private static let currentKey = "AnimationTuner.current"
    private static let presetsKey = "AnimationTuner.presets"
    private static let selectedKey = "AnimationTuner.selected"

    var tuning: LaunchTuning {
        didSet {
            tunerOverride.withLock { $0 = tuning }
            Self.store(tuning, key: Self.currentKey)
        }
    }

    private(set) var presets: [TuningPreset] {
        didSet { Self.store(presets, key: Self.presetsKey) }
    }

    /// The preset last loaded or saved; nil means the shipped tuning or an unsaved tweak.
    private(set) var selected: String? {
        didSet { UserDefaults.standard.set(selected, forKey: Self.selectedKey) }
    }

    var newName = ""

    init() {
        tuning = Self.load(LaunchTuning.self, key: Self.currentKey) ?? .shipped
        presets = Self.load([TuningPreset].self, key: Self.presetsKey) ?? []
        selected = UserDefaults.standard.string(forKey: Self.selectedKey)
        tunerOverride.withLock { $0 = tuning }
    }

    /// Plays `tuning` once at the pointer without loading it.
    func preview(_ tuning: LaunchTuning, play: @MainActor () -> Void) {
        tunerOverride.withLock { $0 = tuning }
        play()
        tunerOverride.withLock { $0 = self.tuning }
    }

    var isModified: Bool {
        guard let selected, let preset = presets.first(where: { $0.name == selected }) else {
            return tuning != .shipped
        }
        return preset.tuning != tuning
    }

    func resetToShipped() {
        tuning = .shipped
        selected = nil
    }

    func load(_ preset: TuningPreset) {
        tuning = preset.tuning
        selected = preset.name
    }

    func saveAsNew() {
        var name = newName.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            let used = Set(presets.map(\.name))
            name = (1...).lazy.map { "Preset \($0)" }.first { !used.contains($0) }!
        }
        if let index = presets.firstIndex(where: { $0.name == name }) {
            presets[index].tuning = tuning
        } else {
            presets.append(TuningPreset(name: name, tuning: tuning))
        }
        selected = name
        newName = ""
    }

    func updateSelected() {
        guard let selected, let index = presets.firstIndex(where: { $0.name == selected }) else { return }
        presets[index].tuning = tuning
    }

    func delete(_ preset: TuningPreset) {
        presets.removeAll { $0.name == preset.name }
        if selected == preset.name { selected = nil }
    }

    private static func store(_ value: some Encodable, key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}

struct TunerView: View {
    @Bindable var model: TunerModel
    let preview: @MainActor () -> Void
    /// On: bounces Finder's icon at the pointer, or restarts it with the current tuning. Off: ends it.
    let previewBounce: @MainActor (Bool) -> Void
    @State private var isPreviewingBounce = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Size & timing") {
                    knob("Icon size", \.iconSide, 16...128, step: 1, unit: "pt")
                    knob("Duration", \.duration, 0.1...2, step: 0.01, unit: "s")
                }
                Section("Pop") {
                    knob("Pop size", \.popSize, 0...0.6, step: 0.01, hint: "extra size at the peak; 0.15 = 15% bigger")
                    knob("Pop time", \.popTime, 0.005...0.15, step: 0.005, unit: "s", hint: "time to reach the peak")
                }
                Section("Rise") {
                    knob("Rise", \.rise, 0...200, step: 1, unit: "pt")
                    knob("Rise curve", \.riseCurve, 0.3...5, step: 0.05, hint: "1 = steady, >1 accelerates")
                }
                Section("Shrink") {
                    knob("Shrink", \.shrink, 0...1, step: 0.01, hint: "share of size lost")
                    knob("Shrink curve", \.shrinkCurve, 0.2...5, step: 0.05, hint: "<1 early, >1 late")
                }
                Section("Fade") {
                    knob("Fade curve", \.fadeCurve, 0.3...10, step: 0.05, hint: "higher stays opaque longer")
                }
                Section("Sway") {
                    knob("Max sway", \.maximumSway, 0...1.5, step: 0.01, hint: "sideways per point of rise")
                    knob("Min sway", \.minimumSway, 0...1, step: 0.01, hint: "share of max")
                    knob("Sway curve", \.swayCurve, 0...5, step: 0.05, hint: "higher veers later")
                }
                Section("Tilt") {
                    knob("Max tilt", \.maximumTilt, 0...45, step: 0.5, unit: "°")
                    knob("Tilt curve", \.tiltCurve, 0.2...5, step: 0.05)
                }
                Section {
                    Toggle("Simulate Reduce motion", isOn: $model.tuning.forceReduceMotion)
                }
                Section {
                    Toggle("Move like the cursor", isOn: $model.tuning.swipeFollowsCursor)
                    knob("Points per step", \.swipePointsPerStep, 20...300, step: 1, unit: "pt",
                         hint: "cursor travel per step; 100 = the icon pitch, lower reaches farther")
                    knob("Tracking speed", \.swipeTrackingSpeed, -1...3, step: 0.0625,
                         hint: "−1 = your System Settings value; default notch is 0.6875")
                } header: {
                    Text("Switcher swipe")
                } footer: {
                    Text("Applies from the next swipe. Off: 12 mm of finger per icon, no acceleration.")
                }
                bounceSection
                presetsSection
            }
            .formStyle(.grouped)

            HStack {
                Button("Reset to shipped") { model.resetToShipped() }
                Spacer()
                Button("Preview at pointer") { preview() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(12)
        }
        .frame(minWidth: 380, minHeight: 500)
    }

    private var bounceSection: some View {
        Section {
            Picker("Animation", selection: $model.tuning.bounce.style) {
                Text("Jump").tag(LaunchTuning.Bounce.Style.jump)
                Text("Inflate").tag(LaunchTuning.Bounce.Style.inflate)
            }
            .pickerStyle(.segmented)
            switch model.tuning.bounce.style {
            case .jump:
                knob("Jump height", \.bounce.height, 0...80, step: 1, unit: "pt")
                knob("Time up", \.bounce.timeUp, 0.05...1, step: 0.01, unit: "s")
                knob("Time down", \.bounce.timeDown, 0.05...1, step: 0.01, unit: "s")
                knob("Rest", \.bounce.rest, 0...1, step: 0.01, unit: "s", hint: "on the ground between jumps")
                knob("Squash", \.bounce.squash, 0...0.5, step: 0.01, hint: "height lost on landing; 0 = none")
            case .inflate:
                knob("Start size", \.bounce.inflateFrom, 1...56, step: 1, unit: "pt",
                     hint: "the icon's side when it appears")
                knob("Inflate time", \.bounce.inflateTime, 0.05...3, step: 0.01, unit: "s",
                     hint: "to the icon size, without slowing to a stop")
                knob("Easing", \.bounce.inflateCurve, 1.2...6, step: 0.1,
                     hint: "low: quick puff, long slow swell; high: rounder, settles sooner")
                knob("Keep growing", \.bounce.creep, 0.01...0.5, step: 0.01,
                     hint: "share of the icon size added after that")
                knob("Growing time", \.bounce.creepTime, 0.5...20, step: 0.1, unit: "s",
                     hint: "from the icon size until it stops; no pause between")
            }
            knob("Gap", \.bounce.gap, 0...60, step: 1, unit: "pt", hint: "between the pointer tip and the icons")
            knob("Offset", \.bounce.offset, -100...100, step: 1, unit: "pt", hint: "sideways from the tip")
            knob("Trailing", \.bounce.trailing, 0...1, step: 0.01, unit: "s",
                 hint: "time to catch up with the pointer; 0 = glued")
            knob("Spacing", \.bounce.spacing, 0...40, step: 1, unit: "pt", hint: "between icons")
            knob("Fade out", \.bounce.fadeOut, 0.05...1, step: 0.01, unit: "s", hint: "a quiet end")
            knob("Slide", \.bounce.slide, 0.05...1, step: 0.01, unit: "s", hint: "others closing up when one ends")
            knob("Pulse low", \.bounce.pulseLow, 0...1, step: 0.01, hint: "Reduce motion: dimmest opacity")
            knob("Pulse period", \.bounce.pulsePeriod, 0.3...4, step: 0.05, unit: "s", hint: "Reduce motion")
            Toggle("Preview bounce", isOn: $isPreviewingBounce)
                .onChange(of: isPreviewingBounce) { _, isOn in previewBounce(isOn) }
                .onChange(of: model.tuning) { if isPreviewingBounce { previewBounce(true) } }
                .onDisappear { if isPreviewingBounce { previewBounce(false) } }
        } header: {
            Text("Launch bounce")
        } footer: {
            Text("Applies from the next bounce. Preview keeps Finder's icon bouncing at the pointer, restarting it on every change, and floats it away when turned off.")
        }
    }

    private var presetsSection: some View {
        Section {
            HStack {
                Text("Current:")
                Text(model.selected ?? "Shipped").bold()
                if model.isModified { Text("(modified)").foregroundStyle(.orange) }
                Spacer()
                if model.selected != nil {
                    Button("Update") { model.updateSelected() }.disabled(!model.isModified)
                }
            }
            HStack {
                TextField("Name (optional)", text: $model.newName)
                    .onSubmit { model.saveAsNew() }
                Button("Save as new") { model.saveAsNew() }
            }
            HStack {
                Image(systemName: model.selected == nil ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(model.selected == nil ? Color.accentColor : .secondary)
                Text("Shipped")
                Spacer()
                Button { model.preview(.shipped, play: preview) } label: { Image(systemName: "play.fill") }
                    .help("Play once at the pointer without loading")
                Button("Load") { model.resetToShipped() }
            }
            ForEach(model.presets) { preset in
                HStack {
                    Image(systemName: model.selected == preset.name ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(model.selected == preset.name ? Color.accentColor : .secondary)
                    Text(preset.name)
                    Spacer()
                    Button { model.preview(preset.tuning, play: preview) } label: { Image(systemName: "play.fill") }
                        .help("Play once at the pointer without loading")
                    Button("Load") { model.load(preset) }
                    Button(role: .destructive) { model.delete(preset) } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                }
            }
        } header: {
            Text("Presets")
        }
    }

    private func knob(
        _ title: String, _ keyPath: WritableKeyPath<LaunchTuning, Double>, _ range: ClosedRange<Double>,
        step: Double, unit: String = "", hint: String? = nil
    ) -> some View {
        let value = Binding(
            get: { model.tuning[keyPath: keyPath] },
            set: { model.tuning[keyPath: keyPath] = ($0 / step).rounded() * step })
        let isShipped = model.tuning[keyPath: keyPath] == LaunchTuning.shipped[keyPath: keyPath]
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                TextField("", value: value, format: .number.precision(.fractionLength(0...3)))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                Text(unit).foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
                Button {
                    model.tuning[keyPath: keyPath] = LaunchTuning.shipped[keyPath: keyPath]
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .help("Shipped: \(LaunchTuning.shipped[keyPath: keyPath].formatted())")
                .opacity(isShipped ? 0.25 : 1)
                .disabled(isShipped)
            }
            Slider(value: value, in: range)
            if let hint { Text(hint).font(.caption).foregroundStyle(.secondary) }
        }
    }
}
#endif
