import Foundation

/// Which hand holds the anchored thumb. One global setting; default `.right`.
public enum HandMode: String, Codable, Sendable, CaseIterable {
    case right
    case left

    /// The words the hint uses for the anchor corner.
    public var cornerName: String { self == .right ? "top-left" : "top-right" }

    /// How far a normalised x lies from the edge on the hand's side of the pad, as a fraction of the width: the right
    /// edge for `.right`, the left edge for `.left`.
    func fractionFromHandSideEdge(x: Double) -> Double { self == .right ? 1 - x : x }

    /// How far a normalised x lies from the edge the thumb anchors against, the opposite of the hand-side edge.
    func fractionFromThumbSideEdge(x: Double) -> Double { 1 - fractionFromHandSideEdge(x: x) }
}
