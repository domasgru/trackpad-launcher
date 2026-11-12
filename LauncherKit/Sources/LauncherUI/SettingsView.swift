import AppKit
import LauncherCore
import SwiftUI

/// One column the window's 326 pt width, its parts 20 pt apart and 16 pt in from the window's edges: the update card,
/// while this opening's check has found a newer version; the Accessibility hint card, while the permission is missing; the settings form, a
/// SwiftUI grouped Form drawn as System Settings draws one, its sections the five gesture rows and the Animate app
/// launch switch, the switcher section, and the thumb corner row with the Hide background apps switch below it; the
/// no trackpad notice, while it applies, in a rounded group; then *Quit Trackpad Launcher* and *Close*, aligned
/// right. The form keeps the system's own fonts, insets and controls, and every row of the form is 46 pt tall
/// (`formRowContent()`), except the *Switch windows* row, which grows while the screen recording hint sits in it. The illustrations are 45 × 28 pt. The guide naming the two
/// marks sits over the first illustration for the top-left corner only, where its arrows meet the thumb.
struct SettingsView: View {
    let launcher: Launcher
    /// Nil for a copy that never updates.
    let updater: Updater?
    let actions: LauncherActions

    /// The label of the screen recording button. The form keeps the system's own fonts.
    static let labelFont = Font.system(size: 13, weight: .medium)
    /// The window's edges to the column's parts, the form's sections included.
    private static let inset: CGFloat = 16
    /// Between the column's parts: the Accessibility hint card, the form, the no trackpad notice and the buttons.
    private static let partSpacing: CGFloat = 20
    /// A grouped Form's own room around its sections: SwiftUI's and not exposed. `contentMargins` leaves the top and
    /// bottom as they are and adds to the sides, so these are measured on macOS 26
    /// (`plans/030-thumb-corner-popup-style`, `plans/036-settings-form-padding`).
    private static let formMargins = (top: CGFloat(20), bottom: CGFloat(20), side: CGFloat(20))

    var body: some View {
        let corner = launcher.drawnThumbCorner
        VStack(spacing: Self.partSpacing) {
            if let card = UpdateCardPreview.card(updater?.card) {
                UpdateCardView(card: card, updateNow: { updater?.updateNow() }, arrowDrift: actions.arrowDrift)
                    .padding(.horizontal, Self.inset)
            }
            if launcher.showsAccessibilityHint {
                AccessibilityHintCard(actions: actions)
                    .padding(.horizontal, Self.inset)
            }
            Form {
                Section {
                    ForEach(launcher.rows) { row in
                        GestureRowView(row: row, corner: corner, launcher: launcher, actions: actions)
                    }
                    Toggle(
                        isOn: Binding(
                            get: { launcher.isLaunchAnimationOn }, set: { launcher.setLaunchAnimation(on: $0) })
                    ) {
                        Text("Animate app launch").formRowContent()
                    }
                    .toggleStyle(.switch)
                }
                Section { SwitcherSection(launcher: launcher, corner: corner, actions: actions) }
                Section {
                    ThumbCornerRows(launcher: launcher)
                    Toggle(
                        isOn: Binding(
                            get: { launcher.isHideBackgroundAppsOn }, set: { launcher.setHideBackgroundApps(on: $0) })
                    ) {
                        Text("Hide background apps").formRowContent()
                    }
                    .toggleStyle(.switch)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            // The column's spacing and inset around the sections, in place of the form's own margins.
            .padding(.top, -Self.formMargins.top)
            .padding(.bottom, -Self.formMargins.bottom)
            .padding(.horizontal, Self.inset - Self.formMargins.side)
            // Under its neighbours, so the margins it lays over them never cover or take their clicks.
            .zIndex(-1)
            if let notice = launcher.inactiveNotice {
                SettingsNotice(message: notice).padding(.horizontal, Self.inset)
            }
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(Copy.quitButton, action: actions.quit)
                    .buttonStyle(TintedButtonStyle(tint: .red))
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

/// What a rounded group looks like, shared by `FormGroup` and the Accessibility hint card.
enum GroupStyle {
    static let cornerRadius: CGFloat = 12
    static let sideInset: CGFloat = 10
    static let fill = Color(nsColor: .quaternarySystemFill)
}

/// A rounded group of rows: 10 pt in from its sides, on the faintest fill.
struct FormGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, GroupStyle.sideInset)
            .background(GroupStyle.fill, in: .rect(cornerRadius: GroupStyle.cornerRadius))
    }
}

/// One row of a group: at least 46 pt tall, as the settings form's rows are, its content centred.
struct FormRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) { content }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, minHeight: 46)
    }
}

/// A gesture row reads the model and sends one intent.
struct GestureRowView: View {
    let row: GestureRow
    let corner: ThumbCorner
    let launcher: Launcher
    let actions: LauncherActions

    var body: some View {
        HStack(spacing: 0) {
            GestureIllustration(gesture: row.gesture, corner: corner)
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
        .formRowContent()
        // Above the next row, so the guide's arrows draw over it.
        .zIndex(row.gesture == .one ? 1 : 0)
    }

    private var showsGuide: Bool { row.gesture == .one && corner.showsGuide }
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

extension View {
    /// A settings form row's content: 26 pt, which the form's own 10 pt above and below makes a 46 pt row. An
    /// illustration, which is taller, stays centred and reaches into that padding. The height is set here because a
    /// grouped Form ignores `listRowInsets` on macOS 26, measured offscreen in a one-row form.
    func formRowContent() -> some View {
        frame(height: 26)
    }

    /// The message of a hint: 11 pt, wrapping at `maxWidth` to as many lines as it needs.
    func hintMessage(maxWidth: CGFloat) -> some View {
        font(.system(size: 11))
            .frame(maxWidth: maxWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
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

/// The thumb corner group's rows: one row, or once the Mac has mixed trackpads a title and a row for each kind.
struct ThumbCornerRows: View {
    let launcher: Launcher

    var body: some View {
        switch launcher.thumbCorners {
        case .single(let corner):
            CornerPicker(title: Copy.thumbCornerRow, corner: corner, indented: false) { launcher.setThumbCorner($0) }
        case .perKind(let macBook, let external):
            Text(Copy.thumbCornerGroupTitle).formRowContent()
            CornerPicker(title: Copy.macBookTrackpadRow, corner: macBook, indented: true) { launcher.setThumbCorner($0) }
            CornerPicker(title: Copy.externalTrackpadRow, corner: external, indented: true) {
                launcher.setExternalThumbCorner($0)
            }
        }
    }
}

/// A form pop-up listing the four corners, its title at the leading edge.
struct CornerPicker: View {
    let title: String
    let corner: ThumbCorner
    let indented: Bool
    let choose: (ThumbCorner) -> Void

    var body: some View {
        Picker(selection: Binding(get: { corner }, set: choose)) {
            ForEach(ThumbCorner.allCases, id: \.self) { corner in
                Text(Copy.thumbCornerTitle(corner)).tag(corner)
            }
        } label: {
            Text(title).formRowContent().padding(.leading, indented ? 16 : 0)
        }
        .pickerStyle(.menu)
    }
}

/// A message in a group of its own: the no trackpad notice.
struct SettingsNotice: View {
    let message: String

    var body: some View {
        FormGroup {
            Text(message)
                .font(.system(size: 11))
                .lineSpacing(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 8)
                .frame(minHeight: 42)
        }
    }
}

/// A regular-size push button drawn in `tint`. Greyed while disabled.
struct TintedButtonStyle: ButtonStyle {
    enum Fill {
        /// The label in the tint, on a fifth-strength wash of it.
        case wash
        /// A white label on the solid tint.
        case solid
    }

    let tint: Color
    var fill: Fill = .wash

    func makeBody(configuration: Configuration) -> some View {
        Face(tint: tint, fill: fill, configuration: configuration)
    }

    /// A style does not grey itself, and reads the environment only through a view of its own.
    private struct Face: View {
        let tint: Color
        let fill: Fill
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let shade = isEnabled ? tint : Color.secondary
            let pressed = isEnabled && configuration.isPressed
            let label: Color
            let background: Color
            switch fill {
            case .wash:
                label = shade
                background = shade.mix(with: .black, by: 0.1).opacity(pressed ? 0.3 : 0.2)
            case .solid:
                label = .white
                background = pressed ? shade.mix(with: .black, by: 0.15) : shade
            }
            return configuration.label
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(label)
                .padding(.horizontal, 16)
                .frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(background))
                .contentShape(.rect(cornerRadius: 6))
        }
    }
}
