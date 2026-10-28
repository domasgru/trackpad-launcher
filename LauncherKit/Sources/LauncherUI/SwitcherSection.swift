import AppKit
import LauncherCore
import SwiftUI

/// Three setting rows: the swipe, the window swipe, then the thumb tap.
struct SwitcherSection: View {
    let launcher: Launcher

    var body: some View {
        SettingRow(
            illustration: "swipe", title: "Switch recent", handMode: launcher.handMode,
            isOn: Binding(get: { launcher.isSwipeOn }, set: { launcher.setSwipe(on: $0) }))
        FormDivider()
        SettingRow(
            illustration: "window-swipe", title: "Switch windows", handMode: launcher.handMode,
            isOn: Binding(get: { launcher.isWindowSwipeOn }, set: { launcher.setWindowSwipe(on: $0) }))
        FormDivider()
        SettingRow(
            illustration: "thumb-tap", title: "Toggle recent", handMode: launcher.handMode,
            isOn: Binding(get: { launcher.isSwapOn }, set: { launcher.setSwap(on: $0) }))
    }
}

/// One switch with its illustration (the inverse copy in left-hand mode) 10 pt before its title.
struct SettingRow: View {
    let illustration: String
    let title: String
    let handMode: HandMode
    let isOn: Binding<Bool>

    var body: some View {
        FormRow {
            Illustration(name: illustration, handMode: handMode)
                .accessibilityHidden(true)
                .padding(.trailing, 10)
            SwitchRow(title: title, isOn: isOn)
        }
    }
}
