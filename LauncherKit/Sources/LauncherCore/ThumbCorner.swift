import Foundation

/// The corner of the trackpad the thumb anchors in. One global setting; default `.topLeft`.
public enum ThumbCorner: Hashable, Sendable, CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    init(isLeft: Bool, isBottom: Bool) {
        switch (isLeft, isBottom) {
        case (true, false): self = .topLeft
        case (false, false): self = .topRight
        case (true, true): self = .bottomLeft
        case (false, true): self = .bottomRight
        }
    }

    /// Whether the corner is on the left edge.
    var isLeft: Bool { self == .topLeft || self == .bottomLeft }

    /// Whether the corner is on the bottom edge: the palm band's key.
    var isBottom: Bool { self == .bottomLeft || self == .bottomRight }

    /// How far a normalised x lies from the corner's side edge, as a fraction of the width.
    func fractionFromSideEdge(x: Double) -> Double { isLeft ? x : 1 - x }

    /// How far a normalised y lies from the corner's top or bottom edge, as a fraction of the height.
    /// `y` is 0 at the top edge and 1 at the bottom.
    func fractionFromTopOrBottomEdge(y: Double) -> Double { isBottom ? 1 - y : y }
}
