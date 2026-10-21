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

/// Two capsule segments in a capsule track; the selected one is filled with the accent colour. The right hand anchors
/// its thumb on the left, so *Left thumb* is `.right`.
struct ThumbPicker: View {
    let launcher: Launcher
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 0) {
            segment("Left thumb", .right)
            segment("Right thumb", .left)
        }
        .frame(height: 28)
        .background(Color.primary.opacity(0.08), in: Capsule())
        .accessibilityRepresentation {
            Picker("Thumb", selection: Binding(get: { launcher.handMode }, set: { launcher.setHandMode($0) })) {
                Text("Left thumb").tag(HandMode.right)
                Text("Right thumb").tag(HandMode.left)
            }
            .pickerStyle(.segmented)
        }
    }

    private func segment(_ title: String, _ handMode: HandMode) -> some View {
        let isSelected = launcher.handMode == handMode
        return Button {
            withAnimation(.snappy(duration: 0.25)) { launcher.setHandMode(handMode) }
        } label: {
            Text(title)
                .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if isSelected {
                        Capsule().fill(Color.accentColor).matchedGeometryEffect(id: "selection", in: selection)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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
            .toggleStyle(PillSwitchStyle())
        }
    }
}

/// The window's switch: a 54×24 capsule, accent-filled while on, with a 32×20 white capsule knob 2 pt inside it.
struct PillSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Capsule()
            .fill(configuration.isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.12)))
            .frame(width: 54, height: 24)
            .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
                    .frame(width: 32, height: 20)
                    .padding(2)
            }
            .animation(.snappy(duration: 0.2), value: configuration.isOn)
            .contentShape(Capsule())
            .onTapGesture { configuration.isOn.toggle() }
            .accessibilityRepresentation {
                Toggle(isOn: configuration.$isOn) { configuration.label }
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
