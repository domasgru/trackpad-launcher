import AppKit
import Testing
@testable import LauncherUI

/// A `GearView` put into a borderless window that is never ordered in; setting the content view is what moves it in.
@MainActor
final class GearBench {
    var reduceMotion: Bool
    let view: GearView
    let window: NSWindow

    init(reduceMotion: Bool) {
        _ = NSApplication.shared
        self.reduceMotion = reduceMotion
        let reader = ReduceMotionReader(reduceMotion)
        self.reader = reader
        view = GearView(image: nil, reduceMotion: { reader.value })
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200), styleMask: .borderless, backing: .buffered,
            defer: true)
        window.isReleasedWhenClosed = false
        enter()
    }

    final class ReduceMotionReader {
        var value: Bool
        init(_ value: Bool) { self.value = value }
    }

    private let reader: ReduceMotionReader

    func setReduceMotion(_ on: Bool) {
        reduceMotion = on
        reader.value = on
    }

    func enter() { window.contentView = view }
    func leave() { window.contentView = nil }

    func postDisplayOptionsChange() {
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: NSWorkspace.shared)
    }

    var turn: CABasicAnimation? { view.gearLayer.animation(forKey: GearView.animationKey) as? CABasicAnimation }

    var anyAnimation: Bool {
        view.gearLayer.animationKeys()?.isEmpty == false || view.layer?.animationKeys()?.isEmpty == false
    }
}

@MainActor @Suite(.serialized) struct GearViewTests {
    private func expectTurning(_ bench: GearBench) throws {
        let turn = try #require(bench.turn)
        #expect(bench.view.gearLayer.animationKeys() == [GearView.animationKey])
        #expect(turn.keyPath == "transform.rotation.z")
        #expect(turn.fromValue as? Double == 0)
        #expect(turn.toValue as? Double == 2 * Double.pi)
        #expect(turn.duration == GearView.period)
        #expect(turn.duration == 30)
        #expect(turn.repeatCount == .infinity)
        #expect(turn.timingFunction == CAMediaTimingFunction(name: .linear))
        #expect(CATransform3DIsIdentity(bench.view.gearLayer.transform))
        #expect(bench.view.layer?.animationKeys() == nil)
    }

    @Test func aGearInAWindowTurnsOnceAroundItsCentreEveryThirtySeconds() throws {
        let bench = GearBench(reduceMotion: false)
        try expectTurning(bench)
        let layer = bench.view.gearLayer
        #expect(layer.anchorPoint == CGPoint(x: 0.5, y: 0.5))
        #expect(layer.bounds == CGRect(x: 0, y: 0, width: 91, height: 91))
        #expect(layer.position == CGPoint(x: 45.5, y: 45.5))
        #expect(bench.view.hitTest(NSPoint(x: 45, y: 45)) == nil)
    }

    @Test func aGearStaysStillWhileReduceMotionIsOn() {
        let bench = GearBench(reduceMotion: true)
        #expect(!bench.anyAnimation)
        #expect(CATransform3DIsIdentity(bench.view.gearLayer.transform))
    }

    @Test func aGearFollowsReduceMotionLive() throws {
        let bench = GearBench(reduceMotion: false)
        bench.setReduceMotion(true)
        bench.postDisplayOptionsChange()
        #expect(!bench.anyAnimation)
        #expect(CATransform3DIsIdentity(bench.view.gearLayer.transform))

        bench.setReduceMotion(false)
        bench.postDisplayOptionsChange()
        try expectTurning(bench)
    }

    @Test func aRepeatedNotificationLeavesTheTurnRunning() throws {
        let bench = GearBench(reduceMotion: false)
        let first = try #require(bench.turn)
        bench.postDisplayOptionsChange()
        bench.postDisplayOptionsChange()
        #expect(bench.turn === first)
    }

    @Test func aGearStopsWhenItLeavesTheWindowAndTurnsAgainOnReturn() throws {
        let bench = GearBench(reduceMotion: false)
        bench.leave()
        #expect(!bench.anyAnimation)

        bench.enter()
        try expectTurning(bench)
    }

    @Test func aGearOutsideAWindowIgnoresReduceMotionChanges() {
        let bench = GearBench(reduceMotion: true)
        bench.leave()
        bench.setReduceMotion(false)
        bench.postDisplayOptionsChange()
        #expect(!bench.anyAnimation)
    }
}

@Suite struct GearAssetTests {
    @Test func theGearFileIs91PointsSquareAndCentred() throws {
        let url = CornerIllustrationFileTests.assets.appending(path: "gear.svg")
        let image = try #require(NSImage(contentsOf: url), "gear.svg missing")
        #expect(image.size == NSSize(width: 91, height: 91))

        let side = 364
        let rep = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let context = try #require(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()

        var total = 0.0, sumX = 0.0, sumY = 0.0
        for y in 0..<side {
            for x in 0..<side {
                let alpha = Double(rep.colorAt(x: x, y: y)?.alphaComponent ?? 0)
                total += alpha
                sumX += alpha * (Double(x) + 0.5)
                sumY += alpha * (Double(y) + 0.5)
            }
        }
        try #require(total > 0, "nothing was drawn")
        let scale = Double(side) / 91
        #expect(abs(sumX / total / scale - 45.5) < 0.5)
        #expect(abs(sumY / total / scale - 45.5) < 0.5)
    }
}
