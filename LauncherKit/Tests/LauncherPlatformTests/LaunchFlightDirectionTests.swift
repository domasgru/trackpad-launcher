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
