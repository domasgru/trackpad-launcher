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
                .noticeText()
                .frame(maxWidth: Self.messageWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button(Copy.openSettingsButton) { actions.openSettings(.accessibility) }
                .buttonStyle(TintedButtonStyle(tint: .accentColor, face: .filled))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, GroupStyle.sideInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            TurningGear()
                .frame(width: 91, height: 91)
                .offset(x: 19, y: -23)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .background(GroupStyle.fill, in: shape)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Self.border, lineWidth: 1))
    }
}
