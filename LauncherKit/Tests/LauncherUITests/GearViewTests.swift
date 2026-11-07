import AppKit
import Testing
@testable import LauncherUI

@MainActor @Suite(.serialized) struct GearViewTests {
    private func expectTurning(_ bench: GearBench, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let turn = try #require(bench.turn, sourceLocation: sourceLocation)
        #expect(bench.view.gearLayer.animationKeys() == [GearView.animationKey], sourceLocation: sourceLocation)
        #expect(turn.keyPath == "transform.rotation.z", sourceLocation: sourceLocation)
        #expect(turn.fromValue as? Double == 0, sourceLocation: sourceLocation)
        #expect(turn.toValue as? Double == -2 * Double.pi, sourceLocation: sourceLocation)
        #expect(turn.duration == 30, sourceLocation: sourceLocation)
        #expect(turn.repeatCount == .infinity, sourceLocation: sourceLocation)
        // The bench's window is never ordered in, so it cannot see this one: see the comment in `GearView`.
        #expect(turn.isRemovedOnCompletion == false, sourceLocation: sourceLocation)
        #expect(turn.timingFunction == CAMediaTimingFunction(name: .linear), sourceLocation: sourceLocation)
        #expect(CATransform3DIsIdentity(bench.view.gearLayer.transform), sourceLocation: sourceLocation)
        #expect(bench.view.layer?.animationKeys() == nil, sourceLocation: sourceLocation)
    }

    @Test func aGearInAWindowTurnsOnceAroundItsCentreEveryThirtySeconds() throws {
        let bench = GearBench(reduceMotion: false)
        try expectTurning(bench)
        let layer = bench.view.gearLayer
        #expect(layer.anchorPoint == CGPoint(x: 0.5, y: 0.5))
        #expect(layer.bounds == CGRect(x: 0, y: 0, width: 91, height: 91))
        #expect(layer.position == CGPoint(x: 45.5, y: 45.5))
    }

    @Test func aGearTakesNoClicks() {
        let bench = GearBench(reduceMotion: false)
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
