import Foundation

/// Which hand holds the anchored thumb. One global setting; default `.right`.
public enum HandMode: String, Codable, Sendable, CaseIterable {
    case right
    case left

    /// The words the hint uses for the anchor corner.
    public var cornerName: String { self == .right ? "top-left" : "top-right" }
}
