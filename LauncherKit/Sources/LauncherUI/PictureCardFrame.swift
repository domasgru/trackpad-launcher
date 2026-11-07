import SwiftUI

extension View {
    /// A bordered group, clipped to its rounded shape, with a picture behind its content at `alignment`. The picture
    /// is decoration: it takes no clicks and is hidden from accessibility.
    func pictureCardFrame<Picture: View>(
        alignment: Alignment, @ViewBuilder picture: () -> Picture
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: GroupStyle.cornerRadius)
        return
            background(alignment: alignment) {
                picture()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .background(GroupStyle.fill, in: shape)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color(red: 0xde / 255, green: 0xde / 255, blue: 0xde / 255), lineWidth: 1))
    }
}
