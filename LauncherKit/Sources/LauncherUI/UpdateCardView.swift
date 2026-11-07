import LauncherCore
import SwiftUI

/// The update card: *Update available* above *Update now*, with a tray-and-arrow picture clipped at its right side and
/// a thin border. It cannot be dismissed and shows no version, progress or error.
struct UpdateCardView: View {
    let card: UpdateCard
    let updateNow: () -> Void

    private static let border = Color(red: 0xde / 255, green: 0xde / 255, blue: 0xde / 255)
    /// The picture's place within the card's padded content.
    private static let picture = (x: CGFloat(203), y: CGFloat(-8))

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: GroupStyle.cornerRadius)
        VStack(alignment: .leading, spacing: 8) {
            Text(card.text)
                .font(.system(size: 11))
                .lineSpacing(0)
                .frame(minHeight: 14)
            Button(card.buttonTitle, action: updateNow)
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 6))
                .disabled(!card.isButtonEnabled)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .padding(.horizontal, GroupStyle.sideInset)
        .background(alignment: .topLeading) {
            DriftingUpdatePicture()
                .frame(width: UpdatePictureView.width, height: UpdatePictureView.height)
                .offset(x: GroupStyle.sideInset + Self.picture.x, y: Self.picture.y)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .background(GroupStyle.fill, in: shape)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Self.border, lineWidth: 1))
    }
}
