import AppKit
import LauncherCore
import SwiftUI

/// One 326 pt column, 16 pt inside the window, of rounded groups 10 pt apart: the five gesture rows and the Animate app
/// launch switch; the switcher section; the thumb picker; then, while any applies, the trackpad settings notice, the
/// Accessibility hint and the screen recording hint, one group each. Rows are at least 42 pt tall, with a hairline
/// between them. The illustrations are 45 × 28 pt. The guide naming the two marks sits over the first illustration in
/// right-hand mode, where its arrows meet the thumb. *Quit Trackpad Launcher* and *Close* end it, aligned right.
struct SettingsView: View {
    let launcher: Launcher
    let actions: LauncherActions

    var body: some View {
        VStack(spacing: 10) {
            FormGroup {
                ForEach(launcher.rows) { row in
                    GestureRowView(row: row, launcher: launcher, actions: actions)
                    FormDivider()
                }
                FormRow {
                    SwitchRow(
                        title: "Animate app launch",
                        isOn: Binding(
                            get: { launcher.isLaunchAnimationOn }, set: { launcher.setLaunchAnimation(on: $0) }))
                }
            }
            FormGroup { SwitcherSection(launcher: launcher) }
            FormGroup {
                ThumbPicker(launcher: launcher)
                    .padding(.vertical, 8)
            }
            if case .inactive(let cause) = launcher.activity {
                SettingsNotice(
                    message: Copy.inactiveNotice(for: cause), button: Copy.trackpadSettingsButton,
                    open: { actions.openSettings(.trackpad) })
            }
            if !launcher.isAccessibilityGranted {
                SettingsNotice(
                    message: Copy.accessibilityHint, button: Copy.accessibilityButton,
                    open: { actions.openSettings(.accessibility) })
            }
            if let hint = launcher.screenRecordingHint {
                SettingsNotice(message: Copy.screenRecordingHint, button: Copy.screenRecordingButton) {
                    switch hint {
                    case .ask: launcher.askForScreenRecording()
                    case .openSettings: actions.openSettings(.screenRecording)
                    }
                }
            }
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(Copy.quitButton, action: actions.quit)
                    .buttonStyle(TintedButtonStyle(tint: .red))
                Button("Close") { launcher.closeWindow() }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 6))
            }
            .padding(.top, 10)
        }
        // The labels only: the controls keep the system's own fonts.
        .font(.system(size: 13, weight: .medium))
        .padding(16)
        .frame(width: 326)
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// A rounded group of rows: 10 pt in from its sides, on the faintest fill.
struct FormGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, 10)
            .background(Color(nsColor: .quaternarySystemFill), in: .rect(cornerRadius: 12))
    }
}

/// One row of a group: at least 42 pt tall, its content centred.
struct FormRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) { content }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, minHeight: 42)
    }
}

/// The hairline between two rows of a group.
struct FormDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .quinaryLabel))
            .frame(height: 1)
    }
}

/// A title and its switch, the switch at the trailing edge.
struct SwitchRow: View {
    let title: String
    let isOn: Binding<Bool>

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }
}

/// A gesture row reads the model and sends one intent.
struct GestureRowView: View {
    let row: GestureRow
    let launcher: Launcher
    let actions: LauncherActions

    var body: some View {
        FormRow {
            GestureIllustration(gesture: row.gesture, handMode: launcher.handMode)
                .overlay(alignment: .topLeading) {
                    if showsGuide {
                        // Where the arrows end on the thumb and the tapping finger.
                        Guide().offset(x: 12, y: -4.37)
                    }
                }
            Spacer(minLength: 12)
            AppPicker(
                current: row.app,
                installedApps: launcher.installedApps,
                cachedIcon: actions.cachedIcon,
                icon: actions.icon,
                choose: { launcher.setAssignment($0, for: row.gesture) },
                chooseOther: { actions.chooseOtherApp { launcher.setAssignment(.appBundle(at: $0), for: row.gesture) } })
        }
        // Above the next row, so the guide's arrows draw over it.
        .zIndex(row.gesture == .one ? 1 : 0)
    }

    /// Right-hand mode only: the left hand's illustrations put the thumb top-right, away from the arrows.
    private var showsGuide: Bool { row.gesture == .one && launcher.handMode == .right }
}

struct GestureIllustration: View {
    let gesture: LauncherCore.Gesture
    let handMode: HandMode

    var body: some View {
        Illustration(name: "gesture-\(gesture.fingerCount)", handMode: handMode)
            .accessibilityLabel("\(gesture.fingerCount)-finger gesture")
    }
}

/// The paper card with a gesture's marks on it: one @2x PNG from the Figma export, the same in light and dark.
struct Illustration: View {
    let name: String
    let handMode: HandMode

    private static let size = CGSize(width: 45, height: 28)

    var body: some View {
        BundleImage.view(handMode.illustration(name), type: "png", size: Self.size)
    }
}

extension HandMode {
    /// The illustrations draw the thumb in the top-left corner; the left hand's copies, with the thumb top-right,
    /// are `-inverse`, which `Scripts/inverse-illustrations.swift` draws from them.
    func illustration(_ name: String) -> String { self == .left ? name + "-inverse" : name }
}

enum BundleImage {
    /// Read from disk once per resource, not on every redraw of the rows.
    private static var loaded: [String: NSImage] = [:]

    /// A missing resource draws nothing rather than failing: the window stays usable.
    static func nsImage(_ name: String, type: String = "svg") -> NSImage? {
        let key = "\(name).\(type)"
        if let image = loaded[key] { return image }
        guard let url = Bundle.main.url(forResource: name, withExtension: type),
              let image = NSImage(contentsOf: url)
        else { return nil }
        loaded[key] = image
        return image
    }

    /// At the image's own size unless `size` is given; an SVG scales without blurring. A template image takes the
    /// foreground style.
    @ViewBuilder static func view(
        _ name: String, type: String = "svg", size: CGSize? = nil, template: Bool = false
    ) -> some View {
        if let image = nsImage(name, type: type) {
            Image(nsImage: image).renderingMode(template ? .template : .original).resizable()
                .frame(width: (size ?? image.size).width, height: (size ?? image.size).height)
        }
    }
}

/// Handwritten *Hold* and *Tap* with arrows to the thumb and the tapping finger of the first illustration.
struct Guide: View {
    var body: some View {
        BundleImage.view("guide", template: true)
            .foregroundStyle(.primary)
            .allowsHitTesting(false)
            .accessibilityLabel("The filled dot is the thumb you hold, the ringed dots are fingers that tap")
    }
}

/// The system segmented control at the regular size (24 pt), filling the group's width in two equal segments, the
/// chosen one in the accent colour: SwiftUI's segmented picker keeps its fitting width on macOS, so this wraps
/// `NSSegmentedControl`. The right hand anchors its thumb on the left, so *Left thumb* is `.right`.
struct ThumbPicker: NSViewRepresentable {
    let launcher: Launcher

    private static let segments: [(title: String, handMode: HandMode)] = [
        ("Left thumb", .right), ("Right thumb", .left),
    ]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: Self.segments.map(\.title), trackingMode: .selectOne,
            target: context.coordinator, action: #selector(Coordinator.changed(_:)))
        control.segmentDistribution = .fillEqually
        control.controlSize = .regular
        control.selectedSegmentBezelColor = .controlAccentColor
        control.setAccessibilityLabel("Thumb")
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.choose = { [launcher] in launcher.setHandMode(Self.segments[$0].handMode) }
        control.selectedSegment = Self.segments.firstIndex { $0.handMode == launcher.handMode } ?? 0
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView control: NSSegmentedControl, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? control.fittingSize.width, height: control.fittingSize.height)
    }

    @MainActor final class Coordinator: NSObject {
        var choose: (Int) -> Void = { _ in }

        @objc func changed(_ control: NSSegmentedControl) { choose(control.selectedSegment) }
    }
}

/// A hint plus a button, in a group of its own. The trackpad settings notice, the Accessibility hint and the screen
/// recording hint share it.
struct SettingsNotice: View {
    let message: String
    let button: String
    let open: () -> Void

    var body: some View {
        FormGroup {
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.system(size: 11))
                    .lineSpacing(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Button(button, action: open)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 6))
            }
            .padding(.vertical, 8)
            .frame(minHeight: 42)
        }
    }
}

/// A regular-size push button drawn in `tint`: the label in it, on a fifth-strength wash of it.
struct TintedButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 16)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(tint.mix(with: .black, by: 0.1).opacity(configuration.isPressed ? 0.3 : 0.2)))
            .contentShape(.rect(cornerRadius: 6))
    }
}
