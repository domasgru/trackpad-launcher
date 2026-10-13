import AppKit
import LauncherCore
import SwiftUI

/// The swipe illustration, mirrored in left-hand mode, and the section's title.
struct SwitcherSection: View {
    let launcher: Launcher

    var body: some View {
        HStack {
            TemplateImage.view("swipe")
                .scaleEffect(x: launcher.handMode == .left ? -1 : 1, y: 1)
                .accessibilityHidden(true)
            Text("Swipe to switch apps")
                .font(.body)
            Spacer(minLength: 0)
        }
    }
}
