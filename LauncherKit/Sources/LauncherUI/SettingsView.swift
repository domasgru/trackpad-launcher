import AppKit
import LauncherCore
import SwiftUI

/// One column, the window's 358 pt width and 16 pt in from its edges, so every group is 326 pt wide: the update card,
/// while this opening's check has found a newer version, and the Accessibility hint card, while the permission is
/// missing, 10 pt apart and 16 pt above the form; the settings form, a SwiftUI grouped Form drawn as System Settings
/// draws one, its sections 10 pt apart: the five gesture rows, the Animate app launch switch and the Hold thumb
/// switch, the switcher section, and the thumb corner group, with the Hide background apps switch below it: one
/// row, or once the Mac has mixed trackpads one cell with a title and two indented pop-up rows; the no trackpad
/// notice, while it applies, in a rounded group 10 pt below the form; then *Quit Trackpad Launcher* and *Close*,
/// aligned right, 20 pt below the last of them. The form keeps the system's own fonts, insets and controls. A
/// one-line row is 48 pt tall and a two-line row 86 pt (`formRow(height:)`), except the 1-finger gesture's, which is 70 pt
/// or 86 pt, the *Switch windows* row, which grows while the screen recording hint sits in it, and the mixed trackpads
/// cell, which is as tall as its three lines. The small illustrations are 45 x 28 pt. The first gesture's picture is
/// not row content: `FirstGestureArt` overlays the form at the gesture group's top-leading corner.
struct SettingsView: View {
    let launcher: Launcher
    /// Nil for a copy that never updates.
    let updater: Updater?
    let actions: LauncherActions

    /// The label of the screen recording button. The form keeps the system's own fonts.
    static let labelFont = Font.system(size: 13, weight: .medium)
    /// The window's edges to the column's parts, the form's sections included.
    private static let inset: CGFloat = 16
    /// Between the update card and the Accessibility hint card.
    private static let cardSpacing: CGFloat = 10
    /// From the last card to the form.
    private static let cardsToForm: CGFloat = 16
    /// From the form to the no trackpad notice.
    private static let noticeSpacing: CGFloat = 10
    /// From the last part above to the buttons.
    private static let buttonsSpacing: CGFloat = 20
    /// A grouped Form's own room around its sections: SwiftUI's and not exposed. `contentMargins` leaves the top and
    /// bottom as they are and adds to the sides, so these are measured on macOS 26
    /// (`plans/030-thumb-corner-popup-style`, `plans/036-settings-form-padding`).
    private static let formMargins = (top: CGFloat(20), bottom: CGFloat(20), side: CGFloat(20))
    /// A grouped Form's own padding above and below every row, measured on macOS 27.2: rows of 28, 50 and 66 pt content
    /// come out 48, 70 and 86 pt. A grouped Form ignores `listRowInsets`, so `formRow(height:)` takes this off.
    static let formRowPadding: CGFloat = 20
    /// The group's width, which the first gesture's picture is clipped to.
    static let groupWidth: CGFloat = 326
    /// The column's width: the groups and the inset on each side.
    static let columnWidth: CGFloat = groupWidth + 2 * inset
    /// The heights of the rows, `formRow(height:)`'s argument: a one-line row, the first gesture's row with one line,
    /// and a two-line row.
    static let oneLineRowHeight: CGFloat = 48
    static let firstGestureRowHeight: CGFloat = 70
    static let twoLineRowHeight: CGFloat = 86

    var body: some View {
        let drawn = launcher.drawnThumbCorner
        let gestureThumb = launcher.gestureThumbCorner
        let updateCard = UpdateCardPreview.card(updater?.card)
        VStack(spacing: 0) {
            if updateCard != nil || launcher.showsAccessibilityHint {
                WholeHeight {
                    VStack(spacing: Self.cardSpacing) {
                        if let card = updateCard {
                            UpdateCardView(
                                card: card, updateNow: { updater?.updateNow() }, arrowDrift: actions.arrowDrift)
                        }
                        if launcher.showsAccessibilityHint {
                            AccessibilityHintCard(actions: actions)
                        }
                    }
                }
                .padding(.horizontal, Self.inset)
                .padding(.bottom, Self.cardsToForm)
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
                        Text("Animate app launch").formRow(height: Self.oneLineRowHeight)
                    }
                    .toggleStyle(.switch)
                    Toggle(
                        isOn: Binding(get: { launcher.isHoldThumbOn }, set: { launcher.setHoldThumb(on: $0) })
                    ) {
                        Text("Hold thumb").formRow(height: Self.oneLineRowHeight)
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
                        Text("Hide background apps").formRow(height: Self.oneLineRowHeight)
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
            .overlay(alignment: .topLeading) {
                FirstGestureArt(
                    thumb: gestureThumb, showsTapHand: launcher.showsTapHand, showsHoldHand: launcher.showsHoldHand)
                    .padding(.leading, Self.inset)
            }
            // Under its neighbours, so the margins it lays over them never cover or take their clicks.
            .zIndex(-1)
            if let notice = launcher.inactiveNotice {
                SettingsNotice(message: notice)
                    .padding(.horizontal, Self.inset)
                    .padding(.top, Self.noticeSpacing)
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
            .padding(.top, Self.buttonsSpacing)
        }
        .padding(.vertical, Self.inset)
        .frame(width: Self.columnWidth)
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
            if row.gesture == .one {
                // Room for `FirstGestureArt`, which draws the picture over the form.
                Color.clear
                    .frame(width: Illustration.size.width, height: Illustration.size.height)
                    .accessibilityElement()
                    .accessibilityLabel("1-finger gesture")
            } else {
                GestureIllustration(gesture: row.gesture, thumb: thumb)
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
        .formRow(height: height)
    }

    /// 48 pt with one line, 86 pt with two; the first gesture's row is 70 pt with one line.
    private var height: CGFloat {
        if row.lineCount == 2 {
            SettingsView.twoLineRowHeight
        } else if row.gesture == .one {
            SettingsView.firstGestureRowHeight
        } else {
            SettingsView.oneLineRowHeight
        }
    }
}

/// Everything the first gesture shows at its leading side, drawn over the form from the gesture group's top-leading
/// corner, which every position is an offset from. Not row content: a grouped Form clips a row to its group, and the
/// overlay keeps its place when the first row grows. Only the picture is clipped; the hand guide reaches past the row
/// and the group. It takes no clicks.
struct FirstGestureArt: View {
    let thumb: ThumbCorner?
    let showsTapHand: Bool
    /// Only ever true together with `showsTapHand`.
    let showsHoldHand: Bool

    /// The picture's top-left corner from the group's, and its width.
    private static let picture = (x: CGFloat(-12), y: CGFloat(-1), width: CGFloat(137))
    /// The first row with one line, which is as far as the picture reaches down.
    private static let rowHeight = SettingsView.firstGestureRowHeight

    var body: some View {
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                BundleImage.view(Illustration.file("gesture-1", thumb: thumb), type: "png", width: Self.picture.width)
                    .offset(x: Self.picture.x, y: Self.picture.y)
            }
            .frame(width: SettingsView.groupWidth, height: Self.rowHeight, alignment: .topLeading)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: GroupStyle.cornerRadius))
            .accessibilityHidden(true)
            if showsTapHand {
                HandGuide(showsHoldHand: showsHoldHand)
            }
        }
        .frame(width: SettingsView.groupWidth, height: Self.rowHeight, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

/// The hands and labels over the first picture: the right hand taps the trackpad's centre, and, while the thumb is
/// held, the left hand holds its top-left corner.
struct HandGuide: View {
    let showsHoldHand: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showsHoldHand {
                BundleImage.view("left-hand", type: "png", width: 52.48)
                    .opacity(0.9)
                    .offset(x: -11.5, y: 10.5)
            }
            BundleImage.view("right-hand", type: "png", width: 60)
                .opacity(0.9)
                .offset(x: 55, y: 24)
            if showsHoldHand {
                HandLabel(text: "Hold", dot: .hold)
                    .offset(x: -11, y: 49)
            }
            HandLabel(text: "Tap", dot: .tap)
                .offset(x: 92, y: 55)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            showsHoldHand
                ? "The filled dot is the thumb you hold, the ringed dots are fingers that tap"
                : "The ringed dots are fingers that tap")
    }
}

/// A small light tooltip: a dot, then the word, in the macOS tooltip's 11 pt medium. The shadows sit on the background
/// shape alone, so the text and the dot are never rasterised through them.
struct HandLabel: View {
    /// The name of the dot's SVG in the bundle.
    enum Dot: String { case hold, tap }

    let text: String
    let dot: Dot

    var body: some View {
        HStack(spacing: 4) {
            BundleImage.view(dot.rawValue)
            Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(.black)
        }
        .padding(.leading, 6).padding(.trailing, 6).padding(.top, 3).padding(.bottom, 2)
        .frame(height: 18)
        .fixedSize()
        .background {
            RoundedRectangle(cornerRadius: 3)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.4), radius: 1)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
    }
}

/// Lays out its one child as it is, at a height rounded up to a whole point, so what sits below it, the first gesture's
/// art among it, starts on a pixel boundary whatever the child's text measures.
private struct WholeHeight<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View { WholeHeightLayout { content } }
}

private struct WholeHeightLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = subviews.first?.sizeThatFits(proposal) ?? .zero
        return CGSize(width: size.width, height: size.height.rounded(.up))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: nil))
    }
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
    /// A settings form row `height` pt tall, its content centred. The height is set here because a grouped Form ignores
    /// `listRowInsets` on macOS, and the form pads every row by `SettingsView.formRowPadding`, which this takes off. An
    /// illustration, which is taller than a one-line row's content, stays centred and reaches into that padding.
    func formRow(height: CGFloat) -> some View {
        frame(height: height - SettingsView.formRowPadding)
    }

    /// The message of a hint: 11 pt, wrapping at `maxWidth` to as many lines as it needs.
    func hintMessage(maxWidth: CGFloat) -> some View {
        font(.system(size: 11))
            .frame(maxWidth: maxWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
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

    /// `width` pt wide at the image's own aspect ratio.
    @ViewBuilder static func view(_ name: String, type: String, width: CGFloat) -> some View {
        if let image = nsImage(name, type: type) {
            Image(nsImage: image).resizable()
                .aspectRatio(image.size, contentMode: .fit)
                .frame(width: width)
        }
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
    /// True when the label is a whole form row, 48 pt tall through `formRow(height:)`; false when it is one line of a
    /// cell that sets its own height.
    var isFormRow = true
    let choose: (ThumbCorner) -> Void

    var body: some View {
        Picker(selection: Binding(get: { corner }, set: choose)) {
            ForEach(ThumbCorner.allCases, id: \.self) { corner in
                Text(Copy.thumbCornerTitle(corner)).tag(corner)
            }
        } label: {
            if isFormRow { Text(title).formRow(height: SettingsView.oneLineRowHeight) } else { Text(title) }
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
