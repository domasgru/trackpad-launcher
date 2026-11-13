import AppKit
import LauncherCore
import SwiftUI

/// One column the window's 326 pt width, its parts 20 pt apart and 16 pt in from the window's edges: the update card,
/// while this opening's check has found a newer version; the Accessibility hint card, while the permission is missing; the settings form, a
/// SwiftUI grouped Form drawn as System Settings draws one, its sections the five gesture rows, the Animate app
/// launch switch and the Hold thumb switch, the switcher section, and the thumb corner group, with the Hide background apps switch below it: one
/// row, or once the Mac has mixed trackpads one cell with a title and two indented pop-up rows; the
/// no trackpad notice, while it applies, in a rounded group; then *Quit Trackpad Launcher* and *Close*, aligned
/// right. The form keeps the system's own fonts, insets and controls, and every row of the form is 46 pt tall
/// (`formRowContent()`), except the *Switch windows* row, which grows while the screen recording hint sits in it, and
/// the mixed trackpads cell, which is as tall as its three lines. The illustrations are 45 × 28 pt. The guide naming the two
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
        let drawn = launcher.drawnThumbCorner
        let gestureThumb = launcher.gestureThumbCorner
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
                        GestureRowView(row: row, thumb: gestureThumb, launcher: launcher, actions: actions)
                    }
                    Toggle(
                        isOn: Binding(
                            get: { launcher.isLaunchAnimationOn }, set: { launcher.setLaunchAnimation(on: $0) })
                    ) {
                        Text("Animate app launch").formRowContent()
                    }
                    .toggleStyle(.switch)
                    Toggle(
                        isOn: Binding(get: { launcher.isHoldThumbOn }, set: { launcher.setHoldThumb(on: $0) })
                    ) {
                        Text("Hold thumb").formRowContent()
                    }
                    .toggleStyle(.switch)
                }
                Section { SwitcherSection(launcher: launcher, corner: drawn, actions: actions) }
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
    let thumb: ThumbCorner?
    let launcher: Launcher
    let actions: LauncherActions

    /// A line of the trailing group, and the gap between two lines: their centres are 32 pt apart.
    private static let lineHeight: CGFloat = 16
    private static let lineSpacing: CGFloat = 16
    /// The design's 12 pt from the picker's chevrons to the plus button; the picker's frame reaches past them by its
    /// trailing inset.
    private static let itemSpacing = 12 - AppPicker.contentInsets.trailing

    var body: some View {
        HStack(spacing: 0) {
            GestureIllustration(gesture: row.gesture, thumb: thumb)
                .overlay(alignment: .topLeading) {
                    if showsGuide {
                        // Where the arrows end on the thumb and the tapping finger.
                        Guide().offset(x: 12, y: -4.37)
                    }
                }
            Spacer(minLength: 12)
            let layout = row.lineCount == 2
                ? AnyLayout(VStackLayout(alignment: .trailing, spacing: Self.lineSpacing))
                : AnyLayout(HStackLayout(spacing: Self.itemSpacing))
            layout {
                AppPicker(
                    current: row.app,
                    unavailable: nil,
                    installedApps: launcher.installedApps,
                    cachedIcon: actions.cachedIcon,
                    icon: actions.icon,
                    choose: { launcher.setAssignment($0, for: row.gesture) },
                    chooseNone: { launcher.setAssignment(nil, for: row.gesture) },
                    chooseOther: { completion in
                        actions.chooseOtherApp {
                            completion(launcher.setAssignment(.appBundle(at: $0), for: row.gesture))
                        }
                    },
                    pickAnimation: actions.pickAnimation
                )
                .frame(height: Self.lineHeight)
                if let slot = row.second {
                    SecondAppPicker(
                        slot: slot,
                        unavailable: row.firstBundleID,
                        installedApps: launcher.installedApps,
                        cachedIcon: actions.cachedIcon,
                        icon: actions.icon,
                        choose: { launcher.setSecondApp($0, for: row.gesture) },
                        chooseOther: { completion in
                            actions.chooseOtherApp {
                                completion(launcher.setSecondApp(.appBundle(at: $0), for: row.gesture))
                            }
                        },
                        remove: { launcher.removeSecondApp(for: row.gesture) },
                        pickAnimation: actions.pickAnimation
                    )
                    .frame(height: Self.lineHeight)
                }
            }
        }
        .formRowContent(lines: row.lineCount)
        // Above the next row, so the guide's arrows draw over it.
        .zIndex(row.gesture == .one ? 1 : 0)
    }

    private var showsGuide: Bool { row.gesture == .one && thumb?.showsGuide == true }
}

struct GestureIllustration: View {
    let gesture: LauncherCore.Gesture
    let thumb: ThumbCorner?

    var body: some View {
        Illustration(name: "gesture-\(gesture.fingerCount)", thumb: thumb)
            .accessibilityLabel("\(gesture.fingerCount)-finger gesture")
    }
}

/// The paper card with a gesture's marks on it, the same in light and dark. The small pictures are 4x PNGs (180 x 112
/// px for 45 x 28 pt). The top-left versions are drawn by hand; `Scripts/corner-illustrations.swift` derives the other
/// corners' versions and the gesture pictures without a thumb.
struct Illustration: View {
    let name: String
    /// The corner the thumb is drawn in; nil for the picture without one.
    let thumb: ThumbCorner?

    static let size = CGSize(width: 45, height: 28)

    /// The one rule that names a picture's file: the top-left version has the base name, the other corners
    /// `-inverse` (top right), `-bottom` (bottom left) and `-bottom-inverse` (bottom right), and no thumb `-no-thumb`.
    nonisolated static func file(_ name: String, thumb: ThumbCorner?) -> String {
        switch thumb {
        case .topLeft: name
        case .topRight: name + "-inverse"
        case .bottomLeft: name + "-bottom"
        case .bottomRight: name + "-bottom-inverse"
        case nil: name + "-no-thumb"
        }
    }

    var body: some View {
        BundleImage.view(Self.file(name, thumb: thumb), type: "png", size: Self.size)
    }
}

extension View {
    /// A settings form row's content: 26 pt, which the form's own 10 pt above and below makes a 46 pt row. An
    /// illustration, which is taller, stays centred and reaches into that padding. The height is set here because a
    /// grouped Form ignores `listRowInsets` on macOS 26, measured offscreen in a one-row form.
    func formRowContent() -> some View {
        formRowContent(lines: 1)
    }

    /// A row of `lines` lines of 16 pt controls, 16 pt apart: 26 pt for one, 56 pt for two, which with the form's
    /// own padding make rows of 46 and 76 pt.
    func formRowContent(lines: Int) -> some View {
        frame(height: lines == 1 ? 26 : 56)
    }

    /// The message of a hint: 11 pt, wrapping at `maxWidth` to as many lines as it needs.
    func hintMessage(maxWidth: CGFloat) -> some View {
        font(.system(size: 11))
            .frame(maxWidth: maxWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension ThumbCorner {
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

/// The thumb corner group's rows: one row, or once the Mac has mixed trackpads one cell holding a title and a pop-up
/// for each kind. A single cell, so the grouped form draws no divider between its lines.
struct ThumbCornerRows: View {
    let launcher: Launcher

    /// The cell's metrics come from the design (Figma node 2231:13555,
    /// `plans/048-external-trackpad-corner/design-spec.md`).
    private static let lineSpacing: CGFloat = 16
    /// Between the two pop-up lines. A pop-up's frame reaches 1.5 pt past its badge, so 18 pt leaves the 15 pt the
    /// design asks for between the two badges (measured on a screenshot of the running window).
    private static let pickerSpacing: CGFloat = 18
    private static let indent: CGFloat = 20
    /// The design's 16 pt is the edge-to-text distance, which the grouped form's own cell padding already supplies in
    /// part: measured, 4 pt more puts the title as far from the cell's top edge as the Hide background apps label is
    /// from its own.
    private static let topPadding: CGFloat = 4
    /// 15 pt from the last badge to the divider below it, as the design asks (measured).
    private static let bottomPadding: CGFloat = 6

    var body: some View {
        switch launcher.thumbCorners {
        case .single(let corner):
            CornerPicker(title: Copy.thumbCornerRow, corner: corner) { launcher.setThumbCorner($0) }
        case .perKind(let macBook, let external):
            VStack(alignment: .leading, spacing: Self.lineSpacing) {
                Text(Copy.thumbCornerGroupTitle)
                VStack(alignment: .leading, spacing: Self.pickerSpacing) {
                    IndentedLine {
                        CornerPicker(title: Copy.macBookTrackpadRow, corner: macBook, isFormRow: false) {
                            launcher.setThumbCorner($0)
                        }
                    }
                    IndentedLine {
                        CornerPicker(title: Copy.externalTrackpadRow, corner: external, isFormRow: false) {
                            launcher.setExternalThumbCorner($0)
                        }
                    }
                }
            }
            .padding(.top, Self.topPadding)
            .padding(.bottom, Self.bottomPadding)
        }
    }

    private struct IndentedLine<Content: View>: View {
        @ViewBuilder let content: Content

        var body: some View { content.padding(.leading, ThumbCornerRows.indent) }
    }
}

/// A form pop-up listing the four corners, its title at the leading edge.
struct CornerPicker: View {
    let title: String
    let corner: ThumbCorner
    /// True when the label is a whole form row, 46 pt tall through `formRowContent()`; false when it is one line of a
    /// cell that sets its own height.
    var isFormRow = true
    let choose: (ThumbCorner) -> Void

    var body: some View {
        Picker(selection: Binding(get: { corner }, set: choose)) {
            ForEach(ThumbCorner.allCases, id: \.self) { corner in
                Text(Copy.thumbCornerTitle(corner)).tag(corner)
            }
        } label: {
            if isFormRow { Text(title).formRowContent() } else { Text(title) }
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
