import Foundation

/// The corner of the trackpad the thumb anchors in. One global setting; default `.topLeft`.
public enum ThumbCorner: Hashable, Sendable, CaseIterable {
    case topLeft
    case topRight

    /// How far a normalised x lies from the corner's side edge, as a fraction of the width.
    func fractionFromSideEdge(x: Double) -> Double { self == .topLeft ? x : 1 - x }

    /// How far a normalised x lies from the side edge opposite the corner, as a fraction of the width.
    func fractionFromOppositeSideEdge(x: Double) -> Double { 1 - fractionFromSideEdge(x: x) }
}
