import LauncherCore
import SwiftUI

/// The Accessibility hint: a bordered card with the message, a filled button to the Accessibility page, and the gear
/// turning in its top-right corner, partly outside it.
struct AccessibilityHintCard: View {
    let actions: LauncherActions

    private static let messageWidth: CGFloat = 216
    private static let border = Color(red: 0xde / 255, green: 0xde / 255, blue: 0xde / 255)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: GroupStyle.cornerRadius)
        VStack(alignment: .leading, spacing: 8) {
            Text(Copy.accessibilityHint)
                .hintMessage(maxWidth: Self.messageWidth)
            Button(Copy.openSettingsButton) { actions.openSettings(.accessibility) }
                .buttonStyle(TintedButtonStyle(tint: .accentColor, fill: .solid))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, GroupStyle.sideInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            TurningGear()
                .frame(width: GearView.side, height: GearView.side)
                .offset(x: 19, y: -23)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .background(GroupStyle.fill, in: shape)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Self.border, lineWidth: 1))
    }
}
