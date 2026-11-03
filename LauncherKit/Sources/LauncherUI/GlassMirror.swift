import AppKit
import LauncherCore
import QuartzCore

/// The one file that knows how AppKit mirrors Liquid Glass: each glass view gets a private element layer on the render
/// server, and an additive animation on that layer survives AppKit's re-sync. Found once by class name and frame, then
/// kept by identity. It only reads the layer tree and adds and removes public `CAAnimation`s.
struct GlassMirror {
    /// How far an element's frame may differ from its view's and still be that view's. Not a look number.
    private static let frameTolerance = 0.5
    private static let elementClassName = "CASDFElementLayer"

    private let root: CALayer
    private let matches: [(element: LiquidElement?, view: NSGlassEffectView, layer: CALayer)]

    /// nil when the class is missing, the element count differs from the views', or any view matches no single element.
    static func matched(in container: NSGlassEffectContainerView, views: [(LiquidElement?, NSGlassEffectView)])
        -> GlassMirror?
    {
        guard let root = container.layer else { return nil }
        let elements = elementLayers(under: root)
        guard let indices = match(elements: elements.map(\.frame), views: views.map(\.1.frame)) else { return nil }
        return GlassMirror(
            root: root,
            matches: zip(views, indices).map { (element: $0.0, view: $0.1, layer: elements[$1]) })
    }

    /// Each view matched to exactly one element by frame within 0.5 pt, else nil. Pure, so tests drive the fallback.
    static func match(elements: [CGRect], views: [CGRect]) -> [Int]? {
        guard elements.count == views.count else { return nil }
        var taken: Set<Int> = []
        var indices: [Int] = []
        for view in views {
            let hits = elements.indices.filter { isNear(elements[$0], view) }
            guard hits.count == 1, taken.insert(hits[0]).inserted else { return nil }
            indices.append(hits[0])
        }
        return indices
    }

    /// Every matched layer still in the container's tree, at its view's frame.
    var isLive: Bool {
        matches.allSatisfy { Self.isDescendant($0.layer, of: root) && Self.isNear($0.layer.frame, $0.view.frame) }
    }

    func layer(for element: LiquidElement) -> CALayer {
        matches.first { $0.element == element }!.layer
    }

    /// Drops every track the liquid staged, on every matched layer.
    func removeLiquidAnimations() {
        for match in matches {
            for key in match.layer.animationKeys() ?? [] where key.hasPrefix(LiquidKeyframes.keyPrefix) {
                match.layer.removeAnimation(forKey: key)
            }
        }
    }

    private static func isNear(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < frameTolerance && abs(a.minY - b.minY) < frameTolerance
            && abs(a.width - b.width) < frameTolerance && abs(a.height - b.height) < frameTolerance
    }

    private static func isDescendant(_ layer: CALayer, of root: CALayer) -> Bool {
        var current: CALayer? = layer
        while let next = current {
            if next === root { return true }
            current = next.superlayer
        }
        return false
    }

    private static func elementLayers(under layer: CALayer) -> [CALayer] {
        let own = NSStringFromClass(type(of: layer)) == elementClassName ? [layer] : []
        return own + (layer.sublayers ?? []).flatMap { elementLayers(under: $0) }
    }
}
