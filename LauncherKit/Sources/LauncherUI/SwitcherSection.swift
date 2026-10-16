import AppKit
import LauncherCore
import SwiftUI

/// Three setting rows: the swipe, the thumb tap, then the window swipe.
struct SwitcherSection: View {
    let launcher: Launcher

    var body: some View {
        VStack(spacing: 16) {
            SettingRow(
                illustration: "swipe", title: "Swipe to switch apps", handMode: launcher.handMode,
                isOn: Binding(get: { launcher.isSwipeOn }, set: { launcher.setSwipe(on: $0) }))
            SettingRow(
                illustration: "thumb-tap", title: "Thumb tap to swap apps", handMode: launcher.handMode,
                isOn: Binding(get: { launcher.isSwapOn }, set: { launcher.setSwap(on: $0) }))
            SettingRow(
                illustration: "window-swipe", title: "Swipe up or down to switch windows", handMode: launcher.handMode,
                isOn: Binding(get: { launcher.isWindowSwipeOn }, set: { launcher.setWindowSwipe(on: $0) }))
        }
    }
}

/// One switch with its illustration (mirrored in left-hand mode) and its title.
struct SettingRow: View {
    let illustration: String
    let title: String
    let handMode: HandMode
    let isOn: Binding<Bool>

    var body: some View {
        HStack {
            TemplateImage.view(illustration)
                .scaleEffect(x: handMode == .left ? -1 : 1, y: 1)
                .accessibilityHidden(true)
            Text(title)
                .font(.body)
            Spacer(minLength: 8)
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}
