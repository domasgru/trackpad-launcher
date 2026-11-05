import AppKit
import LauncherCore
import SwiftUI

/// Three setting rows: the swipe, the window swipe, then the thumb tap.
struct SwitcherSection: View {
    let launcher: Launcher

    var body: some View {
        SettingRow(
            illustration: "swipe", title: "Switch recent", corner: launcher.thumbCorner,
            isOn: Binding(get: { launcher.isSwipeOn }, set: { launcher.setSwipe(on: $0) }))
        FormDivider()
        SettingRow(
            illustration: "window-swipe", title: "Switch windows", corner: launcher.thumbCorner,
            isOn: Binding(get: { launcher.isWindowSwipeOn }, set: { launcher.setWindowSwipe(on: $0) }))
        FormDivider()
        SettingRow(
            illustration: "thumb-tap", title: "Toggle recent", corner: launcher.thumbCorner,
            isOn: Binding(get: { launcher.isSwapOn }, set: { launcher.setSwap(on: $0) }))
    }
}

/// One switch with its illustration (the copy for the chosen thumb corner) 10 pt before its title.
struct SettingRow: View {
    let illustration: String
    let title: String
    let corner: ThumbCorner
    let isOn: Binding<Bool>

    var body: some View {
        FormRow {
            Illustration(name: illustration, corner: corner)
                .accessibilityHidden(true)
                .padding(.trailing, 10)
            SwitchRow(title: title, isOn: isOn)
        }
    }
}
