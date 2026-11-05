import AppKit
import LauncherCore
import SwiftUI

/// One column the window's 326 pt width, its parts 20 pt apart and 16 pt in from the window's edges, the form's sections
/// aside: the update card, while a newer version is known; the settings form, a SwiftUI grouped Form drawn as System
/// Settings draws one, spanning the window's width inside its own side margins, its sections the five gesture rows and
/// the Animate app launch switch, the switcher section, and the thumb corner row; the notices, while any applies, 10 pt
/// apart: the no trackpad notice or the tap-bound settings notice, the Accessibility hint and the screen recording hint,
/// one rounded group each; then *Quit Trackpad Launcher* and *Close*, aligned right. The form keeps the system's own
/// fonts, insets and controls. The illustrations are 45 × 28 pt, and every row of the form is as tall as a row with one.
/// The guide naming the two marks sits over the first illustration for the top-left corner only, where its arrows meet
/// the thumb.
struct SettingsView: View {
    let launcher: Launcher
    let updater: Updater?
    let actions: LauncherActions

    /// The update card's and the notices' labels. The form keeps the system's own fonts.
    private static let labelFont = Font.system(size: 13, weight: .medium)
    /// The window's edges to everything but the form, which spans the window's width.
    private static let inset: CGFloat = 16
    /// Between the column's parts: the update card, the form, the notices and the buttons.
    private static let partSpacing: CGFloat = 20
    /// Between two notices, as between the form's own sections.
    private static let noticeSpacing: CGFloat = 10
    /// A grouped Form's own room above its first section and below its last: SwiftUI's, not exposed and not changed by
    /// `contentMargins`, so measured in the settings window on macOS 26 (`plans/030-thumb-corner-popup-style`).
    private static let formMargins = (top: CGFloat(20), bottom: CGFloat(20))

    private var accessibilityButton: NoticeButton {
        NoticeButton(title: Copy.accessibilityButton) { actions.openSettings(.accessibility) }
    }

    private var hasNotices: Bool {
        launcher.inactiveNotice != nil || launcher.showsAccessibilityHint || launcher.screenRecordingHint != nil
    }

    var body: some View {
        VStack(spacing: Self.partSpacing) {
            if let card = updater?.card {
                UpdateCardView(card: card, updateNow: { updater?.updateNow() }, cancel: { updater?.cancel() })
                    // The labels only: the controls keep the system's own fonts.
                    .font(Self.labelFont)
                    .padding(.horizontal, Self.inset)
            }
            // The window's whole width: the form's own margins inset its sections.
            Form {
                Section {
                    ForEach(launcher.rows) { row in
                        GestureRowView(row: row, launcher: launcher, actions: actions)
                    }
                    Toggle(
                        isOn: Binding(
                            get: { launcher.isLaunchAnimationOn }, set: { launcher.setLaunchAnimation(on: $0) })
                    ) {
                        TitleRowLabel(title: "Animate app launch")
                    }
                    .toggleStyle(.switch)
                }
                Section { SwitcherSection(launcher: launcher) }
                Section { ThumbCornerRow(launcher: launcher) }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            // The column's spacing above and below the sections, not the form's own margins on top of it.
            .padding(.top, -Self.formMargins.top)
            .padding(.bottom, -Self.formMargins.bottom)
            // Under its neighbours, so the margins it lays over them never cover or take their clicks.
            .zIndex(-1)
            if hasNotices {
                VStack(spacing: Self.noticeSpacing) {
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
                }
                .font(Self.labelFont)
                .padding(.horizontal, Self.inset)
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
            .padding(.horizontal, Self.inset)
        }
        .padding(.vertical, Self.inset)
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

/// A gesture row reads the model and sends one intent.
struct GestureRowView: View {
    let row: GestureRow
    let launcher: Launcher
    let actions: LauncherActions

    var body: some View {
        HStack(spacing: 0) {
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

    static let size = CGSize(width: 45, height: 28)

    var body: some View {
        BundleImage.view(corner.illustration(name), type: "png", size: Self.size)
    }
}

/// The label of a form row with no illustration: as tall as one, so the row is as tall as the rows that have one.
struct TitleRowLabel: View {
    let title: String

    var body: some View {
        Text(title).frame(minHeight: Illustration.size.height)
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

/// The thumb corner row: the form's own pop-up listing the four corners.
struct ThumbCornerRow: View {
    let launcher: Launcher

    var body: some View {
        Picker(selection: Binding(get: { launcher.thumbCorner }, set: { launcher.setThumbCorner($0) })) {
            ForEach(ThumbCorner.allCases, id: \.self) { corner in
                Text(Copy.thumbCornerTitle(corner)).tag(corner)
            }
        } label: {
            TitleRowLabel(title: Copy.thumbCornerRow)
        }
        .pickerStyle(.menu)
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
