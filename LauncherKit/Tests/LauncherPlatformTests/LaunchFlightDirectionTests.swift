import AppKit
import Testing
import LauncherCore

@testable import LauncherPlatform

@Suite struct LaunchFlightDirectionTests {
    private let middle = LaunchFlightTests.middleOfBuiltIn

    /// The icon's end point relative to its start, for a flight staged at the middle of the built-in display.
    private func drift(
        _ flight: LaunchFlight, sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> CGFloat {
        let staged = try #require(
            flight.staged(at: middle, among: LaunchFlightTests.displays), sourceLocation: sourceLocation)
        let keyframes = try staged.keyframes(sourceLocation: sourceLocation)
        return try #require(keyframes.last).screenPosition.x - keyframes[0].screenPosition.x
    }

    @Test(arguments: LaunchFlightTests.draws)
    func aDirectedFlightEndsOnItsSideWhateverTheDrawAndDriftsAsFarAsAnUndirectedOne(draw: Double) throws {
        var flights = LaunchFlights()
        let left = try drift(flights.next(draw: draw, reduceMotion: false, toward: .left))
        let right = try drift(flights.next(draw: draw, reduceMotion: false, toward: .right))
        var undirected = LaunchFlights()
        let alike = try drift(undirected.next(draw: abs(draw), reduceMotion: false))

        #expect(left < 0)
        #expect(right > 0)
        #expect(abs(left) == abs(alike))
        #expect(abs(right) == abs(alike))
    }

    @Test func aDirectedFlightNeitherReadsNorFeedsTheStreak() throws {
        var flights = LaunchFlights()
        _ = flights.next(draw: -0.6, reduceMotion: false)
        _ = flights.next(draw: -0.6, reduceMotion: false)
        #expect(try drift(flights.next(draw: -0.6, reduceMotion: false, toward: .left)) < 0, "not flipped by the streak")

        var fed = LaunchFlights()
        _ = fed.next(draw: -0.6, reduceMotion: false)
        _ = fed.next(draw: -0.6, reduceMotion: false, toward: .left)
        #expect(try drift(fed.next(draw: -0.6, reduceMotion: false)) < 0, "the directed flight made no streak")
    }

    /// The keyframes of a split's icon on `side`, started beside the pointer at the middle of the built-in display.
    private func splitKeyframes(_ side: SplitSide, draw: Double) throws -> [Keyframe] {
        var flights = LaunchFlights()
        let start = LaunchFlight.start(at: middle, toward: side, on: .builtIn)
        let staged = try #require(
            flights.next(draw: draw, reduceMotion: false, toward: side).staged(at: start, on: .builtIn))
        return try staged.keyframes()
    }

    /// The box around an icon's tilted square at a keyframe.
    private func box(_ keyframe: Keyframe) -> CGRect {
        let radians = keyframe.rotationDegrees * .pi / 180
        let half = keyframe.side / 2 * (abs(cos(radians)) + abs(sin(radians)))
        return CGRect(
            x: keyframe.screenPosition.x - half, y: keyframe.screenPosition.y - half, width: 2 * half, height: 2 * half)
    }

    @Test(arguments: LaunchFlightTests.draws)
    func aSplitsTwoIconsStartSideBySideAndPartWithoutEverTouching(draw: Double) throws {
        let left = try splitKeyframes(.left, draw: draw)
        let right = try splitKeyframes(.right, draw: draw)
        let spacing = CGFloat(LaunchTuning.current.bounce.spacing)

        // Side by side about the pointer at its height, one bounce row's spacing apart at the pop's peak.
        let leftStart = try #require(left.first).screenPosition, rightStart = try #require(right.first).screenPosition
        let shift = (LaunchFlight.peakSide + spacing) / 2
        #expect(leftStart == CGPoint(x: middle.x - shift, y: middle.y))
        #expect(rightStart == CGPoint(x: middle.x + shift, y: middle.y))

        #expect(left.count == right.count)
        for (l, r) in zip(left, right) {
            #expect(box(l).maxX < box(r).minX, "the icons touch at \(l.time) s")
        }
        let leftEnd = try #require(left.last).screenPosition, rightEnd = try #require(right.last).screenPosition
        #expect(leftEnd.x < leftStart.x, "the left icon sways left")
        #expect(rightEnd.x > rightStart.x, "the right icon sways right")
    }

    @Test(arguments: [CGFloat(1), 1511])
    func atTheDisplaysEdgeASplitsPairSlidesInwardJustEnoughToStartWholeOnIt(pointerX: CGFloat) throws {
        let display = LaunchDisplay.builtIn
        let pointer = CGPoint(x: pointerX, y: 400)
        let peak = LaunchFlight.peakSide, spacing = CGFloat(LaunchTuning.current.bounce.spacing)
        let left = LaunchFlight.start(at: pointer, toward: .left, on: display)
        let right = LaunchFlight.start(at: pointer, toward: .right, on: display)

        #expect(right.x - left.x == peak + spacing, "still side by side")
        let pair = CGRect(x: left.x - peak / 2, y: pointer.y - peak / 2, width: 2 * peak + spacing, height: peak)
        #expect(pair.minX >= display.frame.minX && pair.maxX <= display.frame.maxX)
        #expect(pair.minX == display.frame.minX || pair.maxX == display.frame.maxX, "slid no further than needed")

        for (side, start) in [(SplitSide.left, left), (.right, right)] {
            var flights = LaunchFlights()
            let staged = try #require(flights.next(draw: 0.5, reduceMotion: false, toward: side).staged(at: start, on: display))
            #expect(try #require(staged.keyframes().first).screenPosition == start, "\(side) starts where placed")
        }
    }

    @Test(arguments: LaunchFlightTests.draws, [SplitSide.left, .right])
    func underReduceMotionADirectedIconFadesInPlace(draw: Double, side: SplitSide) throws {
        var flights = LaunchFlights()
        let staged = try #require(
            flights.next(draw: draw, reduceMotion: true, toward: side)
                .staged(at: middle, among: LaunchFlightTests.displays))

        for keyframe in try staged.keyframes() {
            #expect(keyframe.screenPosition == middle, "moved at \(keyframe.time) s")
            #expect(keyframe.rotationDegrees == 0, "tilted at \(keyframe.time) s")
        }
    }
}
