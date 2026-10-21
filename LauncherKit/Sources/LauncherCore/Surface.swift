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

/// The fixed zone where a thumb arms gestures. Along its top edge and its thumb-side edge runs the corner strip, where a
/// thumb sits partly off the pad: a contact landing there is an edge contact, never the anchored thumb.
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

    /// A landing here is in the corner strip: inside the zone and closer than `edgeBandMM` to the top edge or to the
    /// thumb-side edge. Only the landing point is judged; an anchored thumb that drifts into the strip stays anchored.
    package func isInStrip(_ p: SurfacePoint) -> Bool {
        guard admits(p) else { return false }
        let fromTopEdgeMM = p.y * surface.heightMM
        let fromThumbSideEdgeMM = fromEdge(p) * surface.widthMM
        return min(fromTopEdgeMM, fromThumbSideEdgeMM) < GestureRules.edgeBandMM
    }

    /// Distance from the anchor-side edge as a fraction of the width.
    private func fromEdge(_ p: SurfacePoint) -> Double {
        handMode.fractionFromThumbSideEdge(x: p.x)
    }
}

/// Remembers which edge contacts landed in a band, so the recognizer never sees them. The bands are the bottom edge and
/// the hand-side edge below the `edgeBandTop` line, where the heel of the hand rests, and the anchor corner's corner
/// strip, where a thumb sits partly off the pad. An edge contact is a resting palm or a half-off thumb, not a finger,
/// for as long as it stays down. Call once per frame, in frame order.
package struct EdgeContacts: Sendable {
    private let handMode: HandMode
    private let surface: SurfaceSize
    private let anchorCorner: AnchorCorner
    private var edgeContactIDs: Set<TouchID> = []
    private var previouslyDown: Set<TouchID> = []

    package init(_ handMode: HandMode, surface: SurfaceSize) {
        self.handMode = handMode
        self.surface = surface
        anchorCorner = AnchorCorner(handMode, surface: surface)
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
        let fromHandSideEdgeMM = handMode.fractionFromHandSideEdge(x: p.x) * surface.widthMM
        let nearestBandEdgeMM = p.y > GestureRules.edgeBandTop ? min(fromBottomEdgeMM, fromHandSideEdgeMM) : fromBottomEdgeMM
        return nearestBandEdgeMM < GestureRules.edgeBandMM || anchorCorner.isInStrip(p)
    }
}
