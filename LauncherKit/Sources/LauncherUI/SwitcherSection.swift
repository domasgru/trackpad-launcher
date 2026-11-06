import AppKit
import LauncherCore
import SwiftUI

/// Three setting rows of the settings form: the swipe, the window swipe, then the thumb tap.
struct SwitcherSection: View {
    let launcher: Launcher
    let actions: LauncherActions

    var body: some View {
        SettingRow(
            illustration: "swipe", title: "Switch recent", corner: launcher.thumbCorner,
            isOn: Binding(get: { launcher.isSwipeOn }, set: { launcher.setSwipe(on: $0) }))
        VStack(alignment: .leading, spacing: 4) {
            SettingRow(
                illustration: "window-swipe", title: "Switch windows", corner: launcher.thumbCorner,
                isOn: Binding(get: { launcher.isWindowSwipeOn }, set: { launcher.setWindowSwipe(on: $0) }))
            if launcher.screenRecordingHint != nil {
                ScreenRecordingHintView(launcher: launcher, actions: actions)
                    .padding(.leading, SettingRow.titleInset)
            }
        }
        SettingRow(
            illustration: "thumb-tap", title: "Toggle recent", corner: launcher.thumbCorner,
            isOn: Binding(get: { launcher.isSwapOn }, set: { launcher.setSwap(on: $0) }))
    }
}

/// The screen recording hint, under the Switch windows switch: a warning triangle and the message as one paragraph,
/// then the button that asks macOS the first time and opens System Settings after.
struct ScreenRecordingHintView: View {
    let launcher: Launcher
    let actions: LauncherActions

    private static let warning = Color(red: 1, green: 0.8, blue: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(Text(Image(systemName: "exclamationmark.triangle.fill")).foregroundStyle(Self.warning)) \(Copy.screenRecordingHint)")
                .noticeText()
                .frame(maxWidth: 219, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button(Copy.openSettingsButton) {
                switch launcher.screenRecordingHint {
                case .ask: launcher.askForScreenRecording()
                case .openSettings: actions.openSettings(.screenRecording)
                case nil: break
                }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 6))
        }
    }
}

/// One switch, the form's own, with its illustration (the copy for the chosen thumb corner) before its title.
struct SettingRow: View {
    let illustration: String
    let title: String
    let corner: ThumbCorner
    let isOn: Binding<Bool>

    /// Between the illustration and the title. The frame has 10; 8 is what the row measured before it was named.
    static let titleGap: CGFloat = 8
    /// The title's distance from the row's leading edge.
    static let titleInset = Illustration.size.width + titleGap

    var body: some View {
        Toggle(isOn: isOn) {
            HStack(spacing: Self.titleGap) {
                Illustration(name: illustration, corner: corner)
                    .accessibilityHidden(true)
                Text(title)
            }
            .formRowContent()
        }
        .toggleStyle(.switch)
    }
}
