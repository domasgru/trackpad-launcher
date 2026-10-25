import AppKit
import LauncherCore
import SwiftUI

/// One 270 pt column of 28 pt rows 12 pt apart: five gesture rows, the switcher section, the Launch animations switch
/// and the thumb picker. The illustrations are 28 pt tall; the system switch and segmented control, 24 pt at the
/// regular size, are padded out to 28. Below them, while any applies, the trackpad settings notice, the Accessibility
/// hint and the screen recording hint. The guide naming the two marks sits over the first illustration while the first
/// gesture has no app, between it and the 132 pt picker, and only in right-hand mode, where its arrows meet the thumb.
/// Quit lives in the status item's right-click menu.
struct LauncherView: View {
    let launcher: Launcher
    let actions: LauncherActions

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                ForEach(launcher.rows) { row in
                    GestureRowView(row: row, launcher: launcher, actions: actions)
                }
                SwitcherSection(launcher: launcher)
                LaunchAnimationSwitch(launcher: launcher)
                    .padding(.vertical, 2)
                ThumbPicker(launcher: launcher)
                    .padding(.vertical, 2)
            }
            // The labels only: the controls keep the system's own fonts.
            .font(.system(size: 13, weight: .medium))
            if hasNotices {
                VStack(spacing: 16) {
                    if case .inactive(let cause) = launcher.activity {
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
            }
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .overlay(alignment: .topLeading) {
            if showsGuide {
                Guide()
                    .offset(x: 26, y: 7.63)
            }
        }
        .frame(width: 270)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var showsGuide: Bool {
        launcher.handMode == .right && launcher.rows.first?.app == .unassigned
    }

    private var hasNotices: Bool {
        if case .inactive = launcher.activity { return true }
        return !launcher.isAccessibilityGranted || launcher.screenRecordingHint != nil
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
            AppPicker(
                current: row.app,
                installedApps: launcher.installedApps,
                cachedIcon: actions.cachedIcon,
                icon: actions.icon,
                choose: { launcher.setAssignment($0, for: row.gesture) },
                chooseOther: { actions.chooseOtherApp { launcher.setAssignment(.appBundle(at: $0), for: row.gesture) } })
        }
    }
}

struct GestureIllustration: View {
    let gesture: LauncherCore.Gesture
    let handMode: HandMode

    var body: some View {
        Illustration(name: "gesture-\(gesture.fingerCount)", handMode: handMode)
            .accessibilityLabel("\(gesture.fingerCount)-finger gesture")
    }
}

/// The paper card with a gesture's marks on it. Both are the repo's bundle resources, which
/// `Scripts/illustrations.mjs` splits out of the Figma exports: the card is one bitmap shared by every illustration,
/// the marks are SVGs drawn in their own black on it, in light and dark.
struct Illustration: View {
    let name: String
    let handMode: HandMode

    private static let size = CGSize(width: 45, height: 28)

    var body: some View {
        ZStack {
            BundleImage.view("illustration-surface", type: "png", size: Self.size)
            BundleImage.view(handMode.illustration(name), size: Self.size)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

extension HandMode {
    /// The illustrations draw the thumb in the top-left corner; the left hand's copies, with the thumb top-right,
    /// are drawn separately as `-inverse`.
    func illustration(_ name: String) -> String { self == .left ? name + "-inverse" : name }
}

enum BundleImage {
    /// A missing resource draws nothing rather than failing: the window stays usable.
    static func nsImage(_ name: String, type: String = "svg") -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: type) else { return nil }
        return NSImage(contentsOf: url)
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

/// The system segmented control at the regular size (24 pt), filling the window's width in two equal segments:
/// SwiftUI's segmented picker keeps its fitting width on macOS, so this wraps `NSSegmentedControl`. The right hand
/// anchors its thumb on the left, so *Left thumb* is `.right`.
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
