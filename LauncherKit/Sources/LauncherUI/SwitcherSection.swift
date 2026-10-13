import AppKit
import LauncherCore
import SwiftUI

/// Two setting rows: the swipe row with its illustration (mirrored in left-hand mode), then the thumb tap row.
struct SwitcherSection: View {
    let launcher: Launcher

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                TemplateImage.view("swipe")
                    .scaleEffect(x: launcher.handMode == .left ? -1 : 1, y: 1)
                    .accessibilityHidden(true)
                Text("Swipe to switch apps")
                    .font(.body)
                Spacer(minLength: 8)
                Toggle(
                    "Swipe to switch apps",
                    isOn: Binding(get: { launcher.isSwipeOn }, set: { launcher.setSwipe(on: $0) })
                )
                .toggleStyle(.switch)
                .labelsHidden()
            }
            HStack {
                Text("Thumb tap to swap apps")
                Spacer(minLength: 8)
                Toggle(
                    "Thumb tap to swap apps",
                    isOn: Binding(get: { launcher.isSwapOn }, set: { launcher.setSwap(on: $0) })
                )
                .toggleStyle(.switch)
                .labelsHidden()
            }
        }
    }
}
