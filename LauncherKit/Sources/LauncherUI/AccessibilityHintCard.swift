import LauncherCore
import SwiftUI

/// The Accessibility hint: a bordered card with the message, a filled button to the Accessibility page, and the gear
/// turning in its top-right corner, partly outside it.
struct AccessibilityHintCard: View {
    let actions: LauncherActions

    private static let messageWidth: CGFloat = 216

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Copy.accessibilityHint)
                .hintMessage(maxWidth: Self.messageWidth)
            Button(Copy.openSettingsButton) { actions.openSettings(.accessibility) }
                .buttonStyle(TintedButtonStyle(tint: .accentColor, fill: .solid))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, GroupStyle.sideInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pictureCardFrame(alignment: .topTrailing) {
            TurningGear()
                .frame(width: GearView.side, height: GearView.side)
                .offset(x: 19, y: -23)
        }
    }
}
