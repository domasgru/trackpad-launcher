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
    private let matches: [(element: LiquidElement, view: NSGlassEffectView, layer: CALayer)]

    /// Only the views with an element animate, so only they need a layer. nil when the class is missing, the element
    /// count differs from the views', or any animating view matches no single element.
    static func matched(in container: NSGlassEffectContainerView, views: [(LiquidElement?, NSGlassEffectView)])
        -> GlassMirror?
    {
        guard let root = container.layer else { return nil }
        let elements = elementLayers(under: root)
        let animating = Set(views.indices.filter { views[$0].0 != nil })
        guard let indices = match(elements: elements.map(\.frame), views: views.map(\.1.frame), animating: animating)
        else { return nil }
        return GlassMirror(
            root: root,
            matches: views.indices.compactMap { index in
                guard let element = views[index].0, let hit = indices[index] else { return nil }
                return (element: element, view: views[index].1, layer: elements[hit])
            })
    }

    /// Each animating view matched to exactly one element by frame within 0.5 pt; the others stay nil, and may coincide
    /// with anything. Nil overall when the counts differ or an animating view has no single element. Pure, so tests
    /// drive the fallback.
    static func match(elements: [CGRect], views: [CGRect], animating: Set<Int>) -> [Int?]? {
        guard elements.count == views.count else { return nil }
        var taken: Set<Int> = []
        var indices: [Int?] = []
        for (index, view) in views.enumerated() {
            guard animating.contains(index) else {
                indices.append(nil)
                continue
            }
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

    /// nil when the element has no layer of its own, so a track on it is skipped.
    func layer(for element: LiquidElement) -> CALayer? {
        matches.first { $0.element == element }?.layer
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
