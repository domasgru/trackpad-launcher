import Foundation

/// Normalised position: x 0 is the left edge, 1 the right edge; y 0 is the TOP edge, 1 the bottom edge.
/// The multitouch adapter maps the framework's convention onto this one; nothing else knows about it.
public struct SurfacePoint: Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Physical size of a trackpad's sensing surface in millimetres.
public struct SurfaceSize: Hashable, Sendable {
    public var widthMM: Double
    public var heightMM: Double

    public init(widthMM: Double, heightMM: Double) {
        self.widthMM = widthMM
        self.heightMM = heightMM
    }

    /// Distance in millimetres between two normalised points on this surface.
    public func distanceMM(_ a: SurfacePoint, _ b: SurfacePoint) -> Double {
        hypot((a.x - b.x) * widthMM, (a.y - b.y) * heightMM)
    }
}

/// The fixed zone where a thumb arms gestures.
package struct AnchorCorner: Sendable {
    private let handMode: HandMode
    private let surface: SurfaceSize

    package init(_ handMode: HandMode, surface: SurfaceSize) {
        self.handMode = handMode
        self.surface = surface
    }

    /// A contact landing here, while no thumb is anchored, becomes the anchored thumb.
    package func admits(_ p: SurfacePoint) -> Bool {
        fromEdge(p) < GestureRules.cornerWidth && p.y < GestureRules.cornerHeight
    }

    /// An anchored thumb stays anchored while inside the zone grown by `anchorReleaseMarginMM`.
    package func holds(_ p: SurfacePoint) -> Bool {
        fromEdge(p) * surface.widthMM < GestureRules.cornerWidth * surface.widthMM + GestureRules.anchorReleaseMarginMM
            && p.y * surface.heightMM < GestureRules.cornerHeight * surface.heightMM + GestureRules.anchorReleaseMarginMM
    }

    /// Distance from the anchor-side edge as a fraction of the width.
    private func fromEdge(_ p: SurfacePoint) -> Double {
        handMode == .right ? p.x : 1 - p.x
    }
}
