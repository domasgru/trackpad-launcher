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
    private let corner: ThumbCorner
    private let surface: SurfaceSize

    package init(_ corner: ThumbCorner, surface: SurfaceSize) {
        self.corner = corner
        self.surface = surface
    }

    /// A contact landing here, while no thumb is anchored, becomes the anchored thumb.
    package func admits(_ p: SurfacePoint) -> Bool {
        fromSideEdge(p) < GestureRules.cornerWidth && fromTopOrBottomEdge(p) < GestureRules.cornerHeight
    }

    /// An anchored thumb stays anchored while inside the zone grown by `anchorReleaseMarginMM`.
    package func holds(_ p: SurfacePoint) -> Bool {
        fromSideEdge(p) * surface.widthMM < GestureRules.cornerWidth * surface.widthMM + GestureRules.anchorReleaseMarginMM
            && fromTopOrBottomEdge(p) * surface.heightMM
                < GestureRules.cornerHeight * surface.heightMM + GestureRules.anchorReleaseMarginMM
    }

    /// Distance from the corner's side edge as a fraction of the width.
    private func fromSideEdge(_ p: SurfacePoint) -> Double {
        corner.fractionFromSideEdge(x: p.x)
    }

    /// Distance from the corner's top or bottom edge as a fraction of the height.
    private func fromTopOrBottomEdge(_ p: SurfacePoint) -> Double {
        corner.fractionFromTopOrBottomEdge(y: p.y)
    }
}

/// Remembers which edge contacts landed in the band, so the recognizer never sees them. With a top corner the band is
/// the bottom edge and the side edge opposite the thumb corner below the `edgeBandTop` line: where the heel of the hand
/// rests. With a bottom corner it is the bottom edge outside the anchor corner's width, and no side edge. An edge
/// contact is a resting palm, not a finger, for as long as it stays down. Call once per frame, in frame order.
package struct EdgeContacts: Sendable {
    private let corner: ThumbCorner
    private let surface: SurfaceSize
    private var edgeContactIDs: Set<TouchID> = []
    private var previouslyDown: Set<TouchID> = []

    package init(_ corner: ThumbCorner, surface: SurfaceSize) {
        self.corner = corner
        self.surface = surface
    }

    /// The same frame with its edge contacts removed from `touches`, the rest in their original order.
    package mutating func fingers(in frame: TouchFrame) -> TouchFrame {
        let down = Set(frame.touches.map(\.id))
        for touch in frame.touches where touch.isLanding(after: previouslyDown) {
            if isInBand(touch.position) {
                edgeContactIDs.insert(touch.id)
            } else {
                edgeContactIDs.remove(touch.id)
            }
        }
        edgeContactIDs.formIntersection(down)
        previouslyDown = down
        return TouchFrame(time: frame.time, touches: frame.touches.filter { !edgeContactIDs.contains($0.id) }, press: frame.press)
    }

    private func isInBand(_ p: SurfacePoint) -> Bool {
        let fromBottomEdgeMM = (1 - p.y) * surface.heightMM
        if corner.isBottom {
            return fromBottomEdgeMM < GestureRules.edgeBandMM
                && corner.fractionFromSideEdge(x: p.x) >= GestureRules.cornerWidth
        }
        let fromHandSideEdgeMM = (1 - corner.fractionFromSideEdge(x: p.x)) * surface.widthMM
        let nearestBandEdgeMM = p.y > GestureRules.edgeBandTop ? min(fromBottomEdgeMM, fromHandSideEdgeMM) : fromBottomEdgeMM
        return nearestBandEdgeMM < GestureRules.edgeBandMM
    }
}
