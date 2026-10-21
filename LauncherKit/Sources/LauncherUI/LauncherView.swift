import AppKit
import LauncherCore
import SwiftUI

/// Five gesture rows, the switcher section, the Launch animations switch, the thumb picker, a divider, then the legend
/// while gestures are active or the trackpad settings notice while they are not, and the Accessibility and screen
/// recording hints while each applies. Quit lives in the status item's right-click menu.
struct LauncherView: View {
    let launcher: Launcher
    let actions: LauncherActions

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                ForEach(launcher.rows) { row in
                    GestureRowView(row: row, launcher: launcher, actions: actions)
                }
            }
            SwitcherSection(launcher: launcher)
                .padding(.top, 24)
            LaunchAnimationSwitch(launcher: launcher)
                .padding(.top, 24)
            ThumbPicker(launcher: launcher)
                .padding(.top, 24)
            Divider()
                .padding(.top, 20)
            VStack(spacing: 16) {
                switch launcher.activity {
                case .active:
                    Legend()
                case .inactive(let cause):
                    SettingsNotice(
                        message: Copy.inactiveNotice(for: cause), button: "Trackpad settings…",
                        open: { actions.openSettings(.trackpad) })
                }
                if !launcher.isAccessibilityGranted {
                    SettingsNotice(
                        message: Copy.accessibilityHint,
                        button: "Grant access…", open: { actions.openSettings(.accessibility) })
                }
                if let hint = launcher.screenRecordingHint {
                    SettingsNotice(message: Copy.screenRecordingHint, button: Copy.screenRecordingButton(hint)) {
                        switch hint {
                        case .ask: launcher.askForScreenRecording()
                        case .openSettings: actions.openSettings(.screenRecording)
                        }
                    }
                }
            }
            .padding(.top, 12)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 16, trailing: 14))
        .frame(width: 252)
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// A gesture row reads the model and sends one intent.
struct GestureRowView: View {
    let row: GestureRow
    let launcher: Launcher
    let actions: LauncherActions

    var body: some View {
        HStack(spacing: 8) {
            GestureIllustration(gesture: row.gesture, handMode: launcher.handMode)
            Spacer(minLength: 0)
            AppMenuButton(
                current: row.app,
                installedApps: launcher.installedApps,
                cachedIcon: actions.cachedIcon,
                icon: actions.icon,
                choose: { launcher.setAssignment($0, for: row.gesture) },
                chooseOther: { actions.chooseOtherApp { launcher.setAssignment(.appBundle(at: $0), for: row.gesture) } })
                .fixedSize()
        }
    }
}

/// The illustrations are the repo's SVGs, shipped as bundle resources and drawn as template images so they
/// follow the label colour in light and dark.
struct GestureIllustration: View {
    let gesture: LauncherCore.Gesture
    let handMode: HandMode

    var body: some View {
        TemplateImage.view(handMode.illustration("gesture-\(gesture.fingerCount)"))
            .accessibilityLabel("\(gesture.fingerCount)-finger gesture")
    }
}

extension HandMode {
    /// The illustrations draw the thumb in the top-left corner; the left hand's copies, with the thumb top-right,
    /// are drawn separately as `-inverse`.
    func illustration(_ name: String) -> String { self == .left ? name + "-inverse" : name }
}

enum TemplateImage {
    /// A missing resource draws nothing rather than failing: the window stays usable.
    static func nsImage(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "svg"),
            let image = NSImage(contentsOf: url)
        else { return nil }
        image.isTemplate = true
        return image
    }

    /// At the SVG's own size unless `size` is given; an SVG scales without blurring.
    @ViewBuilder static func view(_ name: String, size: CGFloat? = nil) -> some View {
        if let image = nsImage(name) {
            Image(nsImage: image).renderingMode(.template).resizable()
                .frame(width: size ?? image.size.width, height: size ?? image.size.height)
                .foregroundStyle(.primary)
        }
    }
}

/// The system segmented control, filling the window's width in two equal segments: SwiftUI's segmented picker keeps
/// its fitting width on macOS, so this wraps `NSSegmentedControl`. The right hand anchors its thumb on the left, so
/// *Left thumb* is `.right`.
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
        control.controlSize = .large
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

struct LaunchAnimationSwitch: View {
    let launcher: Launcher

    var body: some View {
        HStack(spacing: 12) {
            Text("Launch animations")
            Spacer(minLength: 0)
            Toggle(
                "Launch animations",
                isOn: Binding(get: { launcher.isLaunchAnimationOn }, set: { launcher.setLaunchAnimation(on: $0) })
            )
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }
}

/// What the two marks in the illustrations mean, drawn larger than in the illustrations.
struct Legend: View {
    var body: some View {
        HStack(spacing: 24) {
            HStack(spacing: 7) {
                TemplateImage.view("thumb-mark", size: 11)
                Text("Hold")
            }
            HStack(spacing: 7) {
                TemplateImage.view("other-finger-mark", size: 14)
                Text("Tap")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A hint plus a button. The trackpad settings notice, the Accessibility hint and the screen recording hint share it.
struct SettingsNotice: View {
    let message: String
    let button: String
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .hintStyle()
            Button(button, action: open)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        }
    }
}

private extension View {
    func hintStyle() -> some View {
        // macOS body text: 13 pt, with SF Pro's loose leading (the roomier of its built-in line heights).
        font(.body.leading(.loose))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
