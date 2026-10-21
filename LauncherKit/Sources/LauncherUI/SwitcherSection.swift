import AppKit
import LauncherCore
import SwiftUI

/// Three setting rows: the swipe, the window swipe, then the thumb tap.
struct SwitcherSection: View {
    let launcher: Launcher

    var body: some View {
        VStack(spacing: 12) {
            SettingRow(
                illustration: "swipe", title: "Switch recent apps", handMode: launcher.handMode,
                isOn: Binding(get: { launcher.isSwipeOn }, set: { launcher.setSwipe(on: $0) }))
            SettingRow(
                illustration: "window-swipe", title: "Switch app windows", handMode: launcher.handMode,
                isOn: Binding(get: { launcher.isWindowSwipeOn }, set: { launcher.setWindowSwipe(on: $0) }))
            SettingRow(
                illustration: "thumb-tap", title: "Toggle recent apps", handMode: launcher.handMode,
                isOn: Binding(get: { launcher.isSwapOn }, set: { launcher.setSwap(on: $0) }))
        }
    }
}

/// One switch with its illustration (the inverse copy in left-hand mode) and its title, which wraps to two lines.
struct SettingRow: View {
    let illustration: String
    let title: String
    let handMode: HandMode
    let isOn: Binding<Bool>

    var body: some View {
        HStack(spacing: 12) {
            TemplateImage.view(handMode.illustration(illustration))
                .accessibilityHidden(true)
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}
