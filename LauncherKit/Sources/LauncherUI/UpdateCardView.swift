import LauncherCore
import SwiftUI

/// The update card: *Update available* above *Update now*, with a tray-and-arrow picture clipped at its right side and
/// a thin border. It cannot be dismissed and shows no version, progress or error.
struct UpdateCardView: View {
    let card: UpdateCard
    let updateNow: () -> Void
    /// The arrow's drift, read whenever it starts.
    let arrowDrift: () -> ArrowDrift

    /// The picture's place within the card's padded content: the same distance from the card's trailing edge as when
    /// the card was 294 pt wide.
    private static let picture = (x: CGFloat(235), y: CGFloat(-8))

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.text)
                .font(.system(size: 11))
                .lineSpacing(0)
                .frame(minHeight: 14)
            Button(action: updateNow) { ButtonTitleView(title: card.buttonTitle) }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 6))
                .disabled(!card.isButtonEnabled)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .padding(.horizontal, GroupStyle.sideInset)
        .pictureCardFrame(alignment: .topLeading) {
            DriftingUpdatePicture(drift: arrowDrift)
                .frame(width: UpdatePictureView.width, height: UpdatePictureView.height)
                .offset(x: GroupStyle.sideInset + Self.picture.x, y: Self.picture.y)
        }
    }
}
