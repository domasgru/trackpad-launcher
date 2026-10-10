#if DEBUG
import AppKit
import LauncherCore
import Observation
import SwiftUI
import Synchronization

/// The tuning Debug builds' flights read. Starts as the shipped one; the tuner writes it.
let tunerOverride = Mutex(LaunchTuning.shipped)

/// Debug builds only: a floating window with a slider per `LaunchTuning` knob, for polishing the launch animation.
/// Changes apply to the next gesture at once. The current tuning and named presets persist in user defaults. To
/// ship a tuning, copy its values into `LaunchTuning`'s defaults.
@MainActor final class AnimationTuner {
    private let panel: NSPanel

    init(preview: @escaping @MainActor () -> Void) {
        let model = TunerModel()
        let content = NSHostingView(rootView: TunerView(model: model, preview: preview))
        panel = TunerPanel(
            contentRect: CGRect(x: 0, y: 0, width: 420, height: 760),
            styleMask: [.titled, .resizable, .utilityWindow, .miniaturizable], backing: .buffered, defer: false)
        panel.title = "Launch animation tuner"
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
                Text(unit).foregroundStyle(.secondary).frame(width: 18, alignment: .leading)
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
