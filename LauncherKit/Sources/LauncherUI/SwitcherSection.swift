import AppKit
import LauncherCore
import SwiftUI

/// Three setting rows: the swipe, the window swipe, then the thumb tap.
struct SwitcherSection: View {
    let launcher: Launcher

    var body: some View {
        VStack(spacing: 12) {
            SettingRow(
                illustration: "swipe", title: "Switch recent", handMode: launcher.handMode,
                isOn: Binding(get: { launcher.isSwipeOn }, set: { launcher.setSwipe(on: $0) }))
            SettingRow(
                illustration: "window-swipe", title: "Switch windows", handMode: launcher.handMode,
                isOn: Binding(get: { launcher.isWindowSwipeOn }, set: { launcher.setWindowSwipe(on: $0) }))
            SettingRow(
                illustration: "thumb-tap", title: "Toggle recent", handMode: launcher.handMode,
                isOn: Binding(get: { launcher.isSwapOn }, set: { launcher.setSwap(on: $0) }))
        }
    }
}

/// One switch with its illustration (the inverse copy in left-hand mode) and its title.
struct SettingRow: View {
    let illustration: String
    let title: String
    let handMode: HandMode
    let isOn: Binding<Bool>

    var body: some View {
        HStack(spacing: 8) {
            Illustration(name: illustration, handMode: handMode)
                .accessibilityHidden(true)
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}
