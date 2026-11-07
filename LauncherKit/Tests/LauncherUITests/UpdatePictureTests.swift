import AppKit
import Testing
@testable import LauncherUI

@MainActor @Suite(.serialized) struct UpdatePictureTests {
    private func expectDrifting(_ bench: UpdatePictureBench, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let key = UpdatePictureView.animationKey
        for (layer, drift) in [(bench.view.arrowLayer, bench.arrowDrift), (bench.view.maskLayer, bench.maskDrift)] {
            let drift = try #require(drift, sourceLocation: sourceLocation)
            #expect(layer.animationKeys() == [key], sourceLocation: sourceLocation)
            #expect(drift.keyPath == "position.y", sourceLocation: sourceLocation)
            #expect(drift.byValue as? Double == -4, sourceLocation: sourceLocation)
            #expect(drift.duration == 1.5, sourceLocation: sourceLocation)
            #expect(drift.autoreverses, sourceLocation: sourceLocation)
            #expect(drift.repeatCount == .infinity, sourceLocation: sourceLocation)
            #expect(drift.isRemovedOnCompletion == false, sourceLocation: sourceLocation)
            #expect(
                drift.timingFunction == CAMediaTimingFunction(name: .easeInEaseOut), sourceLocation: sourceLocation)
        }
        #expect(bench.view.trayLayer.animationKeys() == nil, sourceLocation: sourceLocation)
        #expect(bench.view.layer?.animationKeys() == nil, sourceLocation: sourceLocation)
    }

    @Test func theArrowAndItsHoleDriftTogetherAndTheTrayStaysStill() throws {
        try expectDrifting(UpdatePictureBench())
    }

    @Test func thePictureTakesNoClicks() {
        #expect(UpdatePictureBench().view.hitTest(NSPoint(x: 35, y: 40)) == nil)
    }

    @Test func theArrowStaysStillWhileReduceMotionIsOnFromTheStart() {
        #expect(!UpdatePictureBench(reduceMotion: true).anyAnimation)
    }

    @Test func theArrowFollowsReduceMotionLive() throws {
        let bench = UpdatePictureBench()
        bench.setReduceMotion(true)
        bench.postDisplayOptionsChange()
        #expect(!bench.anyAnimation)

        bench.setReduceMotion(false)
        bench.postDisplayOptionsChange()
        try expectDrifting(bench)
    }

    @Test func theArrowStopsWhenThePictureLeavesTheWindowAndDriftsAgainOnReturn() throws {
        let bench = UpdatePictureBench()
        bench.leave()
        #expect(!bench.anyAnimation)

        bench.enter()
        try expectDrifting(bench)
    }

    @Test func theArrowFollowsTheWindowsOnScreenState() throws {
        let bench = UpdatePictureBench()
        bench.setOnScreen(false)
        bench.postOcclusionChange()
        #expect(!bench.anyAnimation)

        bench.setOnScreen(true)
        bench.postOcclusionChange()
        try expectDrifting(bench)
    }

    @Test func aWindowOffScreenWhenThePictureArrivesStartsNothing() {
        #expect(!UpdatePictureBench(onScreen: false).anyAnimation)
    }

    @Test func repeatedNotificationsLeaveTheSameAnimationsInPlace() throws {
        let bench = UpdatePictureBench()
        let arrow = try #require(bench.arrowDrift)
        let mask = try #require(bench.maskDrift)

        bench.postDisplayOptionsChange()
        bench.postOcclusionChange()
        bench.postOcclusionChange()

        #expect(bench.arrowDrift === arrow)
        #expect(bench.maskDrift === mask)
    }

    @Test func aPictureOutsideAWindowIgnoresNotifications() {
        let bench = UpdatePictureBench()
        bench.leave()
        bench.postDisplayOptionsChange()
        bench.postOcclusionChange()
        #expect(!bench.anyAnimation)
    }
}

@MainActor @Suite struct UpdatePictureAssetTests {
    private func load(_ name: String) throws -> NSImage {
        let url = CornerIllustrationFileTests.assets.appending(path: "\(name).svg")
        return try #require(NSImage(contentsOf: url), "\(name).svg missing")
    }

    private static let scale = 4

    /// The pixels of `image` drawn into its size, with alpha at least a half, as the bounding box in points.
    private func drawnBox(of image: NSImage) throws -> (minX: Double, maxX: Double, minY: Double, maxY: Double) {
        let width = Int(image.size.width) * Self.scale
        let height = Int(image.size.height) * Self.scale
        let rep = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let context = try #require(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        var xs = Double.infinity...Double.infinity
        var ys = Double.infinity...Double.infinity
        var found = false
        for y in 0..<height {
            for x in 0..<width where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) >= 0.5 {
                let px = Double(x) / Double(Self.scale), py = Double(y) / Double(Self.scale)
                xs = found ? min(xs.lowerBound, px)...max(xs.upperBound, px + 0.25) : px...(px + 0.25)
                ys = found ? min(ys.lowerBound, py)...max(ys.upperBound, py + 0.25) : py...(py + 0.25)
                found = true
            }
        }
        try #require(found, "nothing was drawn")
        return (xs.lowerBound, xs.upperBound, ys.lowerBound, ys.upperBound)
    }

    @Test func trayAndArrowShareTheDesignsCanvasAndSitWhereTheDesignPutThem() throws {
        let tray = try load("update-tray")
        let arrow = try load("update-arrow")
        #expect(tray.size == NSSize(width: 71, height: 89))
        #expect(arrow.size == NSSize(width: 71, height: 89))

        let trayBox = try drawnBox(of: tray)
        #expect(abs(trayBox.minX - 0) < 0.6 && abs(trayBox.maxX - 71) < 0.6)
        #expect(abs(trayBox.minY - 21.3) < 0.6 && abs(trayBox.maxY - 85.8) < 0.6)

        let arrowBox = try drawnBox(of: arrow)
        #expect(abs(arrowBox.minX - 19.0) < 0.6 && abs(arrowBox.maxX - 52.0) < 0.6)
        #expect(abs(arrowBox.minY - 0) < 0.6 && abs(arrowBox.maxY - 58.8) < 0.6)
    }

    @Test func theHoleMaskIsSolidBesideTheShaftAndClearOnIt() throws {
        let mask = try #require(UpdatePictureView.knockout(load("update-arrow")))
        #expect(mask.size == NSSize(width: 71, height: 97))
        let rep = try #require(mask.representations.first as? NSBitmapImageRep)
        let scale = Double(rep.pixelsWide) / 71

        func alpha(x: Double, y: Double) -> Double {
            Double(rep.colorAt(x: Int(x * scale), y: Int(y * scale))?.alphaComponent ?? -1)
        }
        // The shaft runs down the middle of the arrow, 4 points below the mask's top.
        #expect(alpha(x: 35.5, y: 4 + 20) < 0.01)
        #expect(alpha(x: 10, y: 4 + 20) > 0.99)
        #expect(alpha(x: 35.5, y: 4 + 70) > 0.99)
        #expect(alpha(x: 35.5, y: 1) > 0.99)
    }

    @Test func theArrowsClipIsSolidAboveTheTrayAndClearInsideIt() throws {
        let clip = try #require(UpdatePictureView.knockout(load("update-tray")))
        let rep = try #require(clip.representations.first as? NSBitmapImageRep)
        let scale = Double(rep.pixelsWide) / 71

        func alpha(x: Double, y: Double) -> Double {
            Double(rep.colorAt(x: Int(x * scale), y: Int(y * scale))?.alphaComponent ?? -1)
        }
        #expect(alpha(x: 35.5, y: 4 + 10) > 0.99)
        #expect(alpha(x: 35.5, y: 4 + 50) < 0.01)
    }
}
