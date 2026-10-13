import AppKit
import LauncherCore
import SwiftUI

/// One setting row: the swipe illustration (mirrored in left-hand mode), the title and the switch.
struct SwitcherSection: View {
    let launcher: Launcher

    var body: some View {
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
    }
}
