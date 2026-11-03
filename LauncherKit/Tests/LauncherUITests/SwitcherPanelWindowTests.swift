import AppKit
import LauncherCore
import QuartzCore
import Testing

@testable import LauncherUI

private nonisolated let hasDisplay: Bool = {
    var count: UInt32 = 0
    return CGGetActiveDisplayList(0, nil, &count) == .success && count > 0
}()

/// Runs against the real WindowServer, because AppKit's mirror of the glass views exists only there: in a logged-in GUI
/// session. It walks the container's layer tree by class name and frame itself, independently of `GlassMirror`.
@Suite(.serialized, .enabled(if: hasDisplay)) struct SwitcherPanelWindowTests {
    private static let tolerance = 0.5

    init() { _ = NSApplication.shared }

    private func allLayers(_ layer: CALayer) -> [CALayer] { [layer] + (layer.sublayers ?? []).flatMap(allLayers) }

    private func elements(of panel: SwitcherPanel) -> [CALayer] {
        allLayers(panel.container.layer!).filter { NSStringFromClass(type(of: $0)) == "CASDFElementLayer" }
    }

    private func glassViews(of panel: SwitcherPanel) -> [NSGlassEffectView] { [panel.band] + panel.beads + [panel.swellView] }

    private func isNear(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < Self.tolerance && abs(a.minY - b.minY) < Self.tolerance
            && abs(a.width - b.width) < Self.tolerance && abs(a.height - b.height) < Self.tolerance
    }

    private func element(at frame: CGRect, in panel: SwitcherPanel) -> CALayer? {
        let hits = elements(of: panel).filter { isNear($0.frame, frame) }
        return hits.count == 1 ? hits[0] : nil
    }

    private func liquidKeys(_ layer: CALayer) -> [String] {
        (layer.animationKeys() ?? []).filter { $0.hasPrefix("liquid.") }
    }

    private func spin(for seconds: Double, until done: () -> Bool = { false }) {
        let end = Date(timeIntervalSinceNow: seconds)
        while Date() < end && !done() {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
            CATransaction.flush()
        }
    }

    private func layout(_ count: Int) -> SwitcherRowLayout { SwitcherRowLayout(iconCount: count, displayWidth: 0) }

    /// A swipe's start: laid out, on screen, not yet checked.
    private func open(_ panel: SwitcherPanel, count: Int) {
        let images = (0..<count).map { _ in NSImage(size: NSSize(width: 80, height: 80)) }
        panel.lay(out: images, layout: layout(count), on: NSScreen.main!.frame, backingScale: 2)
        panel.present(appear: nil)
    }

    /// The opening frame, then the frame that steps to the second icon with its tracks.
    private func frames(count: Int) -> (open: LiquidFrame, step: LiquidFrame) {
        var liquid = Liquid(layout: layout(count), motion: .flowing)
        var selection = SwitcherSelection(count: count)
        let now = LiquidTime(seconds: CACurrentMediaTime())
        let open = liquid.follow(selection, at: now)
        selection.follow(12)
        return (open, liquid.follow(selection, at: now))
    }

    private func expectLayoutKept(_ panel: SwitcherPanel, count: Int, sourceLocation: SourceLocation = #_sourceLocation) {
        let layout = layout(count)
        #expect(panel.band.frame == NSRect(layout.band), sourceLocation: sourceLocation)
        for (index, bead) in panel.beads.enumerated() {
            #expect(bead.frame == NSRect(layout.bead(at: index)), sourceLocation: sourceLocation)
        }
        #expect(panel.swellView.frame == NSRect(layout.swell(at: 0)), sourceLocation: sourceLocation)
    }

    private func expectNoTracks(_ panel: SwitcherPanel, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(elements(of: panel).allSatisfy { liquidKeys($0).isEmpty }, sourceLocation: sourceLocation)
    }

    @Test func theMirrorIsMatchedEverySwipeCarriesTheTracksAndLeavesNoneBehind() throws {
        let panel = SwitcherPanel()

        open(panel, count: 5)
        #expect(panel.checkMirror())
        let five = frames(count: 5)
        panel.apply(five.open)
        panel.apply(five.step)
        CATransaction.flush()
        let swell = try #require(five.step.swell)
        #expect(panel.swellView.frame == NSRect(swell))
        let swellElement = try #require(element(at: NSRect(swell), in: panel))
        #expect(
            Set(liquidKeys(swellElement)) == ["liquid.swell.centreX", "liquid.swell.width", "liquid.swell.height"])
        let beadElements = try (0..<5).map { try #require(element(at: NSRect(layout(5).bead(at: $0)), in: panel)) }
        for (index, bead) in beadElements.enumerated() { #expect(liquidKeys(bead) == ["liquid.bead.\(index).height"]) }
        let others = elements(of: panel).filter { $0 !== swellElement && !beadElements.contains($0) }
        #expect(others.count == 6 && others.allSatisfy { liquidKeys($0).isEmpty })
        let before = Set(elements(of: panel).map(ObjectIdentifier.init))
        #expect(before.count == 12)

        panel.orderOut(nil)
        panel.emptied()
        expectNoTracks(panel)
        expectLayoutKept(panel, count: 5)

        open(panel, count: 4)
        let four = frames(count: 4)
        panel.apply(four.open)
        panel.apply(four.step)
        expectNoTracks(panel)
        #expect(panel.checkMirror())
        #expect(Set(elements(of: panel).map(ObjectIdentifier.init)) == before)
        expectNoTracks(panel)

        panel.orderOut(nil)
        panel.emptied()
        expectNoTracks(panel)
        expectLayoutKept(panel, count: 4)

        open(panel, count: 5)
        panel.apply(Liquid.opening(layout(5)))
        panel.orderOut(nil)
        panel.emptied()
        expectNoTracks(panel)
        expectLayoutKept(panel, count: 5)
        #expect(Set(elements(of: panel).map(ObjectIdentifier.init)) == before)
    }

    @Test func aCrestFrameGivesEachRealBeadItsHeightTrackAndNoSpareAny() throws {
        let panel = SwitcherPanel()
        open(panel, count: 5)
        #expect(panel.checkMirror())
        var liquid = Liquid(layout: layout(5), motion: .flowing)
        var selection = SwitcherSelection(count: 5)
        let now = LiquidTime(seconds: CACurrentMediaTime())
        panel.apply(liquid.follow(selection, at: now))
        selection.follow(3)
        let crest = liquid.follow(selection, at: now + 0.01)
        panel.apply(crest)
        CATransaction.flush()

        try #require(crest.tracks.filter { if case .bead = $0.channel.element { true } else { false } }.count == 5)
        for index in 0..<5 {
            let bead = try #require(element(at: NSRect(layout(5).bead(at: index)), in: panel))
            #expect(liquidKeys(bead) == ["liquid.bead.\(index).height"])
            let staged = try #require(bead.animation(forKey: "liquid.bead.\(index).height") as? CAKeyframeAnimation)
            let expected = try #require(crest.tracks.first { $0.channel == LiquidChannel(element: .bead(index), property: .height) })
            #expect((staged.values as? [NSNumber])?.map(\.doubleValue) == expected.offsets)
            #expect(staged.keyPath == "bounds.size.height")
        }
        let band = NSRect(layout(5).band)
        let spares = elements(of: panel).filter { isNear($0.frame, band) }
        #expect(spares.count == 6 && spares.allSatisfy { liquidKeys($0).isEmpty })
    }

    @Test(arguments: [3, 2, 1])
    func aShortRowAfterALongOneStillGetsItsSwellMotion(count: Int) throws {
        let panel = SwitcherPanel()
        open(panel, count: 5)
        #expect(panel.checkMirror())
        let long = frames(count: 5)
        panel.apply(long.open)
        panel.apply(long.step)
        panel.orderOut(nil)
        panel.emptied()

        open(panel, count: count)
        #expect(panel.checkMirror())
        let swipe = frames(count: count)
        panel.apply(swipe.open)
        panel.apply(swipe.step)
        CATransaction.flush()
        let swell = swipe.step.swell ?? layout(count).swell(at: 0)
        let swellTracks = swipe.step.tracks.filter { $0.channel.element == .swell }
        try #require(!swellTracks.isEmpty)
        let swellElement = try #require(element(at: NSRect(swell), in: panel))
        #expect(Set(liquidKeys(swellElement)) == Set(swellTracks.map { "liquid.swell.\($0.channel.property)" }))
        #expect(panel.swellView.frame == NSRect(swell))

        panel.orderOut(nil)
        panel.emptied()
        expectNoTracks(panel)
    }

    @Test func aRebuiltElementCostsNoSwipeItsMotionBecauseTheNextSwipeMatchesAgain() throws {
        let panel = SwitcherPanel()
        open(panel, count: 5)
        #expect(panel.checkMirror())
        let before = Set(elements(of: panel).map(ObjectIdentifier.init))

        panel.beads[2].isHidden = true
        CATransaction.flush()
        panel.beads[2].isHidden = false
        spin(for: 2) { elements(of: panel).count == 12 && Set(elements(of: panel).map(ObjectIdentifier.init)) != before }
        try #require(elements(of: panel).count == 12)
        try #require(Set(elements(of: panel).map(ObjectIdentifier.init)) != before)

        panel.orderOut(nil)
        open(panel, count: 5)
        #expect(panel.checkMirror())
        let swipe = frames(count: 5)
        panel.apply(swipe.open)
        panel.apply(swipe.step)
        CATransaction.flush()
        let swell = try #require(swipe.step.swell)
        #expect(panel.swellView.frame == NSRect(swell))
        let swellElement = try #require(element(at: NSRect(swell), in: panel))
        #expect(
            Set(liquidKeys(swellElement)) == ["liquid.swell.centreX", "liquid.swell.width", "liquid.swell.height"])
        let bead = try #require(element(at: NSRect(layout(5).bead(at: 2)), in: panel))
        #expect(liquidKeys(bead) == ["liquid.bead.2.height"])

        panel.orderOut(nil)
        panel.emptied()
        expectNoTracks(panel)
        expectLayoutKept(panel, count: 5)

        open(panel, count: 4)
        #expect(panel.checkMirror())
    }

    @Test(.enabled(if: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion))
    func openingAgainDuringTheFadeKeepsTheWindowAndTheNewTracks() throws {
        let panel = SwitcherPanel()
        open(panel, count: 5)
        #expect(panel.checkMirror())
        let first = frames(count: 5)
        panel.apply(first.open)
        panel.apply(first.step)

        panel.dismiss()
        try #require(panel.contentView?.layer?.animation(forKey: "fade") != nil)
        open(panel, count: 5)
        let checked = panel.checkMirror()
        let second = frames(count: 5)
        panel.apply(second.open)
        panel.apply(second.step)
        spin(for: 0.4)

        #expect(panel.isVisible && panel.isPresented)
        #expect(checked)
        let swell = try #require(second.step.swell)
        let swellElement = try #require(element(at: NSRect(swell), in: panel))
        #expect(
            Set(liquidKeys(swellElement)) == ["liquid.swell.centreX", "liquid.swell.width", "liquid.swell.height"])
        let staged = try #require(swellElement.animation(forKey: "liquid.swell.width") as? CAKeyframeAnimation)
        let newest = try #require(second.step.tracks.first { $0.channel.property == .width })
        #expect((staged.values as? [NSNumber])?.map(\.doubleValue) == newest.offsets)
        #expect(panel.swellView.frame == NSRect(swell))
    }
}

extension Liquid {
    /// The frame a swipe opens with.
    static func opening(_ layout: SwitcherRowLayout) -> LiquidFrame {
        var liquid = Liquid(layout: layout, motion: .flowing)
        return liquid.follow(SwitcherSelection(count: layout.iconCount), at: LiquidTime(seconds: CACurrentMediaTime()))
    }
}
