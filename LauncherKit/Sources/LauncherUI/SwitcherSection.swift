import AppKit
import LauncherCore
import SwiftUI

/// Three setting rows of the settings form: the swipe, the window swipe, then the thumb tap.
struct SwitcherSection: View {
    let launcher: Launcher

    var body: some View {
        SettingRow(
            illustration: "swipe", title: "Switch recent", corner: launcher.thumbCorner,
            isOn: Binding(get: { launcher.isSwipeOn }, set: { launcher.setSwipe(on: $0) }))
        SettingRow(
            illustration: "window-swipe", title: "Switch windows", corner: launcher.thumbCorner,
            isOn: Binding(get: { launcher.isWindowSwipeOn }, set: { launcher.setWindowSwipe(on: $0) }))
        SettingRow(
            illustration: "thumb-tap", title: "Toggle recent", corner: launcher.thumbCorner,
            isOn: Binding(get: { launcher.isSwapOn }, set: { launcher.setSwap(on: $0) }))
    }
}

/// One switch, the form's own, with its illustration (the copy for the chosen thumb corner) before its title.
struct SettingRow: View {
    let illustration: String
    let title: String
    let corner: ThumbCorner
    let isOn: Binding<Bool>

    var body: some View {
        Toggle(isOn: isOn) {
            HStack {
                Illustration(name: illustration, corner: corner)
                    .accessibilityHidden(true)
                Text(title)
            }
            .formRowContent()
        }
        .toggleStyle(.switch)
    }
}
