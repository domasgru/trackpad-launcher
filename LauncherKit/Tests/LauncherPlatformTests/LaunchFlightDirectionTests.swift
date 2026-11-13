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

    /// The keyframes of a split's icon on `side`, started beside the pointer at the middle of the built-in display, as
    /// the overlay plays it: the icon whose app is not focused `splitStagger` late.
    private func splitKeyframes(_ side: SplitSide, draw: Double, focus: SplitSide) throws -> [Keyframe] {
        var flights = LaunchFlights()
        let start = LaunchFlight.start(at: middle, toward: side, on: .builtIn)
        let flight = flights.next(draw: draw, reduceMotion: false, toward: side)
            .delayed(by: side == focus ? 0 : LaunchFlight.splitStagger)
        return try #require(flight.staged(at: start, on: .builtIn)).keyframes()
    }

    /// The box around an icon's tilted square: its centre, side and tilt at a moment.
    private func box(centre: CGPoint, side: Double, degrees: Double) -> CGRect {
        let radians = degrees * .pi / 180
        let half = side / 2 * (abs(cos(radians)) + abs(sin(radians)))
        return CGRect(x: centre.x - half, y: centre.y - half, width: 2 * half, height: 2 * half)
    }

    private func box(_ keyframe: Keyframe) -> CGRect {
        box(centre: keyframe.screenPosition, side: keyframe.side, degrees: keyframe.rotationDegrees)
    }

    /// The icon's box at `time`, between the keyframes around it, as Core Animation plays them (linear).
    private func box(at time: Double, in frames: [Keyframe]) -> CGRect? {
        guard let next = frames.firstIndex(where: { $0.time >= time }) else { return nil }
        guard next > 0 else { return box(frames[0]) }
        let a = frames[next - 1], b = frames[next]
        let u = b.time > a.time ? (time - a.time) / (b.time - a.time) : 1
        func mix(_ x: Double, _ y: Double) -> Double { x + (y - x) * u }
        return box(
            centre: CGPoint(
                x: mix(a.screenPosition.x, b.screenPosition.x), y: mix(a.screenPosition.y, b.screenPosition.y)),
            side: mix(a.side, b.side), degrees: mix(a.rotationDegrees, b.rotationDegrees))
    }

    @Test(arguments: LaunchFlightTests.draws, [SplitSide.left, .right])
    func aSplitsTwoIconsStartSideBySideTheFocusedOneFirstAndPartWithoutEverTouching(
        draw: Double, focus: SplitSide
    ) throws {
        let left = try splitKeyframes(.left, draw: draw, focus: focus)
        let right = try splitKeyframes(.right, draw: draw, focus: focus)
        // The focused app's icon moves first: the other holds its start for the stagger.
        let (focused, waiting) = focus == .left ? (left, right) : (right, left)
        #expect(focused.count + 1 == waiting.count, "only the other icon holds a first keyframe")
        #expect(abs(waiting[1].time - LaunchFlight.splitStagger) < 1e-9 && focused[0].time == 0)
        // Side by side about the pointer at its height, 8 points apart as they start.
        let leftStart = try #require(left.first).screenPosition, rightStart = try #require(right.first).screenPosition
        #expect(LaunchFlight.splitGap == 8)
        let shift = (LaunchFlight.iconSide + 8) / 2
        #expect(leftStart == CGPoint(x: middle.x - shift, y: middle.y))
        #expect(rightStart == CGPoint(x: middle.x + shift, y: middle.y))
        #expect(box(try #require(right.first)).minX - box(try #require(left.first)).maxX == 8)

        // Every millisecond both icons show, their artwork stays apart. A macOS app icon draws its shape in the middle
        // 824 of its 1024 points, so a clear margin of 100/1024 of its side lies inside each square. The squares
        // themselves come within that margin of each other while the second icon swells.
        let margin = 100.0 / 1024
        let shown = min(try #require(left.last).time, try #require(right.last).time)
        var closest = Double.infinity
        for millisecond in 0...Int(shown * 1000) {
            let time = Double(millisecond) / 1000
            let l = try #require(box(at: time, in: left)), r = try #require(box(at: time, in: right))
            let artwork = (l.maxX - l.width * margin, r.minX + r.width * margin)
            #expect(artwork.0 < artwork.1, "the icons' artwork touches at \(time) s")
            closest = min(closest, artwork.1 - artwork.0)
        }
        #expect(closest > 5, "artwork at least 5 points apart, \(closest)")
        let leftEnd = try #require(left.last).screenPosition, rightEnd = try #require(right.last).screenPosition
        #expect(leftEnd.x < leftStart.x, "the left icon sways left")
        #expect(rightEnd.x > rightStart.x, "the right icon sways right")
    }

    @Test(arguments: LaunchFlightTests.draws)
    func aDelayedFlightShowsAtOnceRestsForTheDelayThenPlaysTheSameFlight(draw: Double) throws {
        var flights = LaunchFlights(), same = LaunchFlights()
        let delay = LaunchFlight.splitStagger
        let plain = try #require(
            same.next(draw: draw, reduceMotion: false, toward: .right).staged(at: middle, on: .builtIn)).keyframes()
        let delayed = try #require(
            flights.next(draw: draw, reduceMotion: false, toward: .right).delayed(by: delay)
                .staged(at: middle, on: .builtIn)).keyframes()

        #expect(delay > 0 && delay < 0.1, "slightly after")
        #expect(delayed.count == plain.count + 1)
        let rest = try #require(delayed.first)
        #expect(rest.time == 0 && rest.screenPosition == middle && rest.opacity == 1, "shown at once, at its start")
        for (moving, original) in zip(delayed.dropFirst(), plain) {
            #expect(abs(moving.time - (original.time + delay)) < 1e-9)
            #expect(moving.screenPosition == original.screenPosition)
            #expect(moving.side == original.side)
        }
    }

    @Test(arguments: [CGFloat(1), 1511])
    func atTheDisplaysEdgeASplitsPairSlidesInwardJustEnoughToStartWholeOnIt(pointerX: CGFloat) throws {
        let display = LaunchDisplay.builtIn
        let pointer = CGPoint(x: pointerX, y: 400)
        let peak = LaunchFlight.peakSide, centres = LaunchFlight.iconSide + LaunchFlight.splitGap
        let left = LaunchFlight.start(at: pointer, toward: .left, on: display)
        let right = LaunchFlight.start(at: pointer, toward: .right, on: display)

        #expect(right.x - left.x == centres, "still side by side")
        // The pair at its largest, the pop's peak.
        let pair = CGRect(x: left.x - peak / 2, y: pointer.y - peak / 2, width: centres + peak, height: peak)
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
