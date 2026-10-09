import AppKit
import Testing

@testable import LauncherPlatform

/// One sampled moment of a staged flight, read back from the keyframe animations Core Animation will play.
struct Keyframe {
    let time: Double
    /// The icon centre in global screen coordinates: the stage frame's origin plus the position value.
    let screenPosition: CGPoint
    /// The icon's position value, in the window's coordinates.
    let position: CGPoint
    let side: Double
    /// Counter-clockwise positive.
    let rotationDegrees: Double
    let opacity: Double
}

extension LaunchStage {
    /// The icon's start point in global screen coordinates.
    var screenIconCentre: CGPoint { CGPoint(x: frame.minX + iconCentre.x, y: frame.minY + iconCentre.y) }

    func keyframes(sourceLocation: SourceLocation = #_sourceLocation) throws -> [Keyframe] {
        func animation(_ keyPath: String) throws -> CAKeyframeAnimation {
            try #require(
                animations.first { $0.keyPath == keyPath }, "no \(keyPath) animation", sourceLocation: sourceLocation)
        }
        let position = try animation("position")
        let transform = try animation("transform")
        let opacity = try animation("opacity")
        let positions = try #require(position.values as? [NSValue], sourceLocation: sourceLocation).map(\.pointValue)
        let transforms = try #require(transform.values as? [NSValue], sourceLocation: sourceLocation)
            .map(\.caTransform3DValue)
        let opacities = try #require(opacity.values as? [NSNumber], sourceLocation: sourceLocation).map(\.doubleValue)
        let keyTimes = try #require(position.keyTimes, sourceLocation: sourceLocation).map(\.doubleValue)
        for other in [transform, opacity] {
            #expect(other.keyTimes?.map(\.doubleValue) == keyTimes, sourceLocation: sourceLocation)
            #expect(other.duration == position.duration, sourceLocation: sourceLocation)
        }
        try #require(
            [positions.count, transforms.count, opacities.count].allSatisfy { $0 == keyTimes.count },
            sourceLocation: sourceLocation)
        return keyTimes.indices.map { i in
            let m = transforms[i]
            return Keyframe(
                time: keyTimes[i] * position.duration,
                screenPosition: CGPoint(x: frame.minX + positions[i].x, y: frame.minY + positions[i].y),
                position: positions[i],
                side: 46 * (m.m11 * m.m11 + m.m12 * m.m12).squareRoot(),
                rotationDegrees: atan2(m.m12, m.m11) * 180 / .pi,
                opacity: opacities[i])
        }
    }
}

extension LaunchDisplay {
    /// This 14" MacBook Pro's display, as read in the planning probe.
    static let builtIn = LaunchDisplay(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), scale: 2)
    /// A 1x display arranged above the built-in one.
    static let external = LaunchDisplay(frame: CGRect(x: -524, y: 982, width: 2560, height: 1440), scale: 1)
}

@Suite struct LaunchFlightTests {
    static let draws: [Double] = [-1, -0.5, -0.01, 0, 0.01, 0.5, 1]
    static let modes = [false, true]
    static let middleOfBuiltIn = CGPoint(x: 700, y: 400)

    private func stage(
        draw: Double, reduceMotion: Bool, at pointer: CGPoint = middleOfBuiltIn,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> LaunchStage {
        var flights = LaunchFlights()
        let flight = flights.next(draw: draw, reduceMotion: reduceMotion)
        return try #require(
            flight.staged(at: pointer, among: [.builtIn, .external]), sourceLocation: sourceLocation)
    }

    @Test(arguments: modes, draws)
    func iconAppearsAtThePointerAtFullSizeAndFullyOpaqueAndNeverGrowsOrFadesIn(
        reduceMotion: Bool, draw: Double
    ) throws {
        let keyframes = try stage(draw: draw, reduceMotion: reduceMotion).keyframes()
        let first = try #require(keyframes.first)

        #expect(first.time == 0)
        #expect(first.screenPosition == Self.middleOfBuiltIn)
        #expect(first.side == 46)
        #expect(first.opacity == 1)
        #expect(first.rotationDegrees == 0)
        for (previous, next) in zip(keyframes, keyframes.dropFirst()) {
            #expect(next.side <= 46, "grew at \(next.time) s")
            #expect(next.opacity <= previous.opacity, "faded in at \(next.time) s")
        }
    }

    @Test(arguments: draws)
    func iconRisesFasterAndFasterToBetween30And60PointsAboveItsStart(draw: Double) throws {
        let keyframes = try stage(draw: draw, reduceMotion: false).keyframes()
        let rises = keyframes.map { $0.screenPosition.y - keyframes[0].screenPosition.y }
        let halfway = try #require(keyframes.firstIndex { $0.time >= 0.25 })
        try #require(abs(keyframes[halfway].time - 0.25) < 1e-9)
        let last = try #require(rises.last)

        #expect((30...60).contains(last))
        #expect(last - rises[halfway] > rises[halfway] - rises[0], "more height in the second half than in the first")
        let steps = zip(rises, rises.dropFirst()).map { $1 - $0 }
        for (i, (step, nextStep)) in zip(steps, steps.dropFirst()).enumerated() {
            #expect(nextStep > step, "rise did not speed up at \(keyframes[i + 2].time) s")
        }
    }

    @Test(arguments: draws)
    func iconShrinksSteadilyToNoMoreThanHalfItsStartSize(draw: Double) throws {
        let keyframes = try stage(draw: draw, reduceMotion: false).keyframes()

        for (previous, next) in zip(keyframes, keyframes.dropFirst()) {
            #expect(next.side < previous.side, "did not shrink at \(next.time) s")
        }
        #expect(try #require(keyframes.last).side <= 23)
    }

    @Test(arguments: draws)
    func iconStaysNearlyOpaqueAtFirstThenFadesOutWhileStillClearlyLargerThanADot(draw: Double) throws {
        let keyframes = try stage(draw: draw, reduceMotion: false).keyframes()

        for keyframe in keyframes where keyframe.time <= 0.2 + 1e-9 {
            #expect(keyframe.opacity >= 0.9, "already fading at \(keyframe.time) s")
        }
        let gone = try #require(keyframes.first { $0.opacity == 0 }, "never fully invisible")
        #expect(gone.side >= 46 / 3)
    }

    @Test(arguments: modes, draws)
    func iconIsFullyInvisibleBetween400And600Milliseconds(reduceMotion: Bool, draw: Double) throws {
        let staged = try stage(draw: draw, reduceMotion: reduceMotion)
        let keyframes = try staged.keyframes()

        for animation in staged.animations {
            #expect(
                (0.4...0.6).contains(animation.duration), "\(animation.keyPath ?? "") lasts \(animation.duration) s")
        }
        for keyframe in keyframes where keyframe.time < 0.4 {
            #expect(keyframe.opacity > 0, "invisible too early, at \(keyframe.time) s")
        }
        let gone = try #require(keyframes.first { $0.opacity == 0 }, "never fully invisible")
        #expect(gone.time <= 0.6)
    }

    @Test(arguments: draws)
    func iconVeersToTheDrawnSideByNoMoreThanAThirdOfItsRise(draw: Double) throws {
        let keyframes = try stage(draw: draw, reduceMotion: false).keyframes()
        let start = keyframes[0].screenPosition

        for keyframe in keyframes {
            let rise = keyframe.screenPosition.y - start.y
            let drift = keyframe.screenPosition.x - start.x
            #expect(abs(drift) <= rise / 3, "drift \(drift) against rise \(rise) at \(keyframe.time) s")
        }
        let end = try #require(keyframes.last).screenPosition
        #expect(end.y - start.y > 0)
        if draw < 0 {
            #expect(end.x - start.x < 0, "veered right for draw \(draw)")
        } else {
            #expect(end.x - start.x > 0, "did not veer right for draw \(draw)")
        }
    }

    /// The end drift and end rise of each flight one `LaunchFlights` draws, in order.
    private func ends(of draws: [Double]) throws -> [(drift: Double, rise: Double)] {
        var flights = LaunchFlights()
        return try draws.map { draw in
            let staged = try #require(
                flights.next(draw: draw, reduceMotion: false).staged(at: Self.middleOfBuiltIn, among: [.builtIn]))
            let keyframes = try staged.keyframes()
            let start = keyframes[0].screenPosition
            let end = try #require(keyframes.last).screenPosition
            return (end.x - start.x, end.y - start.y)
        }
    }

    @Test(arguments: [0.6, -0.6, 0])
    func tenFlightsFromTheSameDrawNeverVeerTheSameWayThreeTimesInARow(draw: Double) throws {
        let ends = try ends(of: Array(repeating: draw, count: 10))
        let sides = ends.map { $0.drift > 0 }

        for i in 2..<sides.count {
            #expect(Set(sides[(i - 2)...i]).count == 2, "flights \(i - 2)...\(i) all veer the same way")
        }
        #expect(Set(ends.map(\.drift)).count > 1, "all ten drifts are identical")
        for end in ends {
            #expect(end.rise > 0)
        }
    }

    @Test func otherwiseTheSideFollowsTheDraw() throws {
        let sides = try ends(of: [-0.6, 0.6, -0.6, 0.6]).map { $0.drift > 0 ? "right" : "left" }

        #expect(sides == ["left", "right", "left", "right"])
    }

    /// Counter-clockwise is positive in a y-up layer tree, so a top leaning toward +x is a negative rotation.
    @Test(arguments: draws)
    func iconLeansTowardItsDriftByNoMoreThan5Degrees(draw: Double) throws {
        let keyframes = try stage(draw: draw, reduceMotion: false).keyframes()

        for keyframe in keyframes {
            #expect(abs(keyframe.rotationDegrees) <= 5, "tilted \(keyframe.rotationDegrees)° at \(keyframe.time) s")
        }
        let last = try #require(keyframes.last)
        let drift = last.screenPosition.x - keyframes[0].screenPosition.x
        #expect(last.rotationDegrees != 0)
        #expect(last.rotationDegrees.sign != drift.sign, "leans away from its drift")
    }

    @Test(arguments: draws)
    func underReduceMotionTheIconNeverMovesShrinksOrTilts(draw: Double) throws {
        let keyframes = try stage(draw: draw, reduceMotion: true).keyframes()

        for keyframe in keyframes {
            #expect(keyframe.screenPosition == Self.middleOfBuiltIn, "moved at \(keyframe.time) s")
            #expect(keyframe.side == 46, "shrank at \(keyframe.time) s")
            #expect(keyframe.rotationDegrees == 0, "tilted at \(keyframe.time) s")
        }
    }

    @Test func reduceMotionFlightsDoNotCountTowardsASwayStreak() throws {
        var flights = LaunchFlights()
        var sides: [Bool] = []
        for reduceMotion in [false, true, false, true, false] {
            let flight = flights.next(draw: 0.6, reduceMotion: reduceMotion)
            guard !reduceMotion else { continue }
            let keyframes = try #require(flight.staged(at: Self.middleOfBuiltIn, among: [.builtIn])).keyframes()
            sides.append(try #require(keyframes.last).screenPosition.x > Self.middleOfBuiltIn.x)
        }

        #expect(sides == [true, true, false], "only the moving flights make a streak")
    }

    @Test(arguments: draws)
    func nearTheTopEdgeTheIconIsCutOffAtTheDisplaysTopEdge(draw: Double) throws {
        let pointer = CGPoint(x: 700, y: 975)
        let nearTop = try stage(draw: draw, reduceMotion: false, at: pointer)
        let middle = try stage(draw: draw, reduceMotion: false)

        #expect(LaunchDisplay.builtIn.frame.contains(nearTop.frame))
        #expect(nearTop.frame.maxY == 982)
        #expect(nearTop.scale == 2)
        #expect(nearTop.screenIconCentre == pointer)
        #expect(nearTop.frame.height < middle.frame.height)
    }

    @Test(arguments: draws)
    func onTheExternalDisplayTheIconStaysOnItAtItsScale(draw: Double) throws {
        let pointer = CGPoint(x: 1000, y: 2410)
        let staged = try stage(draw: draw, reduceMotion: false, at: pointer)

        #expect(LaunchDisplay.external.frame.contains(staged.frame))
        #expect(staged.frame.maxY == 2422)
        #expect(staged.scale == 1)
        #expect(staged.screenIconCentre == pointer)
    }

    /// AppKit counts a display's top edge as inside it and its bottom edge as outside.
    @Test(arguments: draws)
    func onTheEdgeTheDisplaysShareTheIconStaysOnTheDisplayBelow(draw: Double) throws {
        let sharedEdge = try stage(draw: draw, reduceMotion: false, at: CGPoint(x: 700, y: 982))
        let bottomEdge = try stage(draw: draw, reduceMotion: false, at: CGPoint(x: 700, y: 0))

        #expect(LaunchDisplay.builtIn.frame.contains(sharedEdge.frame))
        #expect(sharedEdge.frame.maxY == 982)
        #expect(LaunchDisplay.builtIn.frame.contains(bottomEdge.frame))
    }

    @Test(arguments: modes, draws)
    func awayFromTheEdgesNothingOfTheIconIsEverCut(reduceMotion: Bool, draw: Double) throws {
        let staged = try stage(draw: draw, reduceMotion: reduceMotion)
        let window = CGRect(origin: .zero, size: staged.frame.size).insetBy(dx: -1e-9, dy: -1e-9)

        #expect(LaunchDisplay.builtIn.frame.contains(staged.frame))
        for keyframe in try staged.keyframes() {
            let angle = keyframe.rotationDegrees * .pi / 180
            let half = keyframe.side / 2
            let corners = [(-half, -half), (half, -half), (half, half), (-half, half)].map { x, y in
                CGPoint(
                    x: keyframe.position.x + x * cos(angle) - y * sin(angle),
                    y: keyframe.position.y + x * sin(angle) + y * cos(angle))
            }
            #expect(corners.allSatisfy(window.contains), "cut at \(keyframe.time) s: \(corners)")
        }
    }
}
