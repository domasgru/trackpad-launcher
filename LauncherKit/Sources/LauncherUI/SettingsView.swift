import AppKit
import LauncherCore
import SwiftUI

/// One 326 pt column, 16 pt inside the window, of rounded groups 10 pt apart: the update card, while a newer version is
/// known; the five gesture rows and the Animate app
/// launch switch; the switcher section; the thumb corner row; then, while any applies, the no trackpad notice or the tap-bound settings notice, the
/// Accessibility hint and the screen recording hint, one group each. Rows are at least 42 pt tall, with a hairline
/// between them. The illustrations are 45 × 28 pt. The guide naming the two marks sits over the first illustration for
/// the top-left corner only, where its arrows meet the thumb. *Quit Trackpad Launcher* and *Close* end it, aligned right.
struct SettingsView: View {
    let launcher: Launcher
    let updater: Updater?
    let actions: LauncherActions

    private var accessibilityButton: NoticeButton {
        NoticeButton(title: Copy.accessibilityButton) { actions.openSettings(.accessibility) }
    }

    var body: some View {
        VStack(spacing: 10) {
            if let card = updater?.card {
                UpdateCardView(
                    card: card, updateNow: { updater?.updateNow() }, cancel: { updater?.cancel() })
            }
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
                FormRow { ThumbCornerRow(launcher: launcher) }
            }
            if let notice = launcher.inactiveNotice {
                SettingsNotice(message: notice)
            }
            if launcher.showsAccessibilityHint {
                SettingsNotice(message: Copy.accessibilityHint, button: accessibilityButton)
            }
            if let hint = launcher.screenRecordingHint {
                SettingsNotice(
                    message: Copy.screenRecordingHint,
                    button: NoticeButton(title: Copy.screenRecordingButton) {
                        switch hint {
                        case .ask: launcher.askForScreenRecording()
                        case .openSettings: actions.openSettings(.screenRecording)
                        }
                    })
            }
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(Copy.quitButton, action: actions.quit)
                    .buttonStyle(TintedButtonStyle(tint: .red))
                    .disabled(updater?.isInstalling == true)
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
            GestureIllustration(gesture: row.gesture, corner: launcher.thumbCorner)
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
                chooseOther: { completion in
                    actions.chooseOtherApp { completion(launcher.setAssignment(.appBundle(at: $0), for: row.gesture)) }
                },
                pickAnimation: actions.pickAnimation)
        }
        // Above the next row, so the guide's arrows draw over it.
        .zIndex(row.gesture == .one ? 1 : 0)
    }

    private var showsGuide: Bool { row.gesture == .one && launcher.thumbCorner.showsGuide }
}

struct GestureIllustration: View {
    let gesture: LauncherCore.Gesture
    let corner: ThumbCorner

    var body: some View {
        Illustration(name: "gesture-\(gesture.fingerCount)", corner: corner)
            .accessibilityLabel("\(gesture.fingerCount)-finger gesture")
    }
}

/// The paper card with a gesture's marks on it: one @2x PNG from the Figma export, the same in light and dark.
struct Illustration: View {
    let name: String
    let corner: ThumbCorner

    private static let size = CGSize(width: 45, height: 28)

    var body: some View {
        BundleImage.view(corner.illustration(name), type: "png", size: Self.size)
    }
}

extension ThumbCorner {
    /// The illustrations are drawn with the thumb in the top-left corner. The other corners' copies are derived from
    /// them by `Scripts/corner-illustrations.swift`: `-inverse` top-right, `-bottom` bottom-left and
    /// `-bottom-inverse` bottom-right.
    func illustration(_ name: String) -> String {
        switch self {
        case .topLeft: name
        case .topRight: name + "-inverse"
        case .bottomLeft: name + "-bottom"
        case .bottomRight: name + "-bottom-inverse"
        }
    }

    /// Only the top-left illustration puts the thumb where the guide's arrows end.
    var showsGuide: Bool { self == .topLeft }
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

/// The thumb corner row's title and, at the trailing edge, its pop-up button listing the four corners, in System
/// Settings' style like the app pickers.
struct ThumbCornerRow: View {
    let launcher: Launcher

    var body: some View {
        HStack(spacing: 16) {
            Text(Copy.thumbCornerRow)
                .frame(maxWidth: .infinity, alignment: .leading)
            SettingsPopUp(
                options: ThumbCorner.allCases,
                title: Copy.thumbCornerTitle,
                selection: launcher.thumbCorner,
                select: { launcher.setThumbCorner($0) },
                accessibilityLabel: Copy.thumbCornerRow)
            .fixedSize()
        }
    }
}

/// A button's title and what it does.
struct NoticeButton {
    let title: String
    let perform: () -> Void
}

/// A message and, optionally, a button, in a group of its own. The no trackpad notice, the tap-bound settings notice,
/// the Accessibility hint and the screen recording hint share it.
struct SettingsNotice: View {
    let message: String
    let button: NoticeButton?

    init(message: String, button: NoticeButton? = nil) {
        self.message = message
        self.button = button
    }

    var body: some View {
        FormGroup {
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.system(size: 11))
                    .lineSpacing(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let button {
                    Button(button.title, action: button.perform)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 6))
                }
            }
            .padding(.vertical, 8)
            .frame(minHeight: 42)
        }
    }
}

/// A regular-size push button drawn in `tint`: the label in it, on a fifth-strength wash of it. Greyed while disabled.
struct TintedButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        Face(tint: tint, configuration: configuration)
    }

    /// A style does not grey itself, and reads the environment only through a view of its own.
    private struct Face: View {
        let tint: Color
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let shade = isEnabled ? tint : Color.secondary
            configuration.label
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(shade)
                .padding(.horizontal, 16)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(shade.mix(with: .black, by: 0.1).opacity(isEnabled && configuration.isPressed ? 0.3 : 0.2)))
                .contentShape(.rect(cornerRadius: 6))
        }
    }
}
