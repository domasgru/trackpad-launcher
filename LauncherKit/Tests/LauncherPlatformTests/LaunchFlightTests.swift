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
                side: iconSide * (m.m11 * m.m11 + m.m12 * m.m12).squareRoot(),
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
    static let displays: [LaunchDisplay] = [.builtIn, .external]

    private func stage(
        draw: Double, reduceMotion: Bool, at pointer: CGPoint = middleOfBuiltIn,
        among displays: [LaunchDisplay] = displays, tuning: LaunchTuning = .shipped, sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> LaunchStage {
        var flights = LaunchFlights()
        let flight = flights.next(draw: draw, reduceMotion: reduceMotion, tuning: tuning)
        return try #require(flight.staged(at: pointer, among: displays), sourceLocation: sourceLocation)
    }

    /// The index of the pop's peak: the largest keyframe, where the deflating flight starts.
    private func peak(of keyframes: [Keyframe]) throws -> Int {
        try #require(keyframes.indices.max { keyframes[$0].side < keyframes[$1].side })
    }

    /// The first keyframe whose screen y is above the start's.
    private func firstRising(of keyframes: [Keyframe]) throws -> Keyframe {
        try #require(keyframes.first { $0.screenPosition.y > keyframes[0].screenPosition.y }, "never rises")
    }

    /// A keyframe's angle from straight up, in degrees, by its screen displacement from `start`.
    private func angle(of keyframe: Keyframe, from start: CGPoint) -> Double {
        let dx = keyframe.screenPosition.x - start.x
        let dy = keyframe.screenPosition.y - start.y
        return atan2(abs(dx), dy) * 180 / .pi
    }

    private func isRight(_ keyframe: Keyframe, of start: CGPoint) -> Bool {
        keyframe.screenPosition.x > start.x
    }

    @Test(arguments: draws)
    func iconStaysOnThePointerThroughThePopThenLeansToItsSideFromItsFirstRisingMoment(draw: Double) throws {
        let keyframes = try stage(draw: draw, reduceMotion: false).keyframes()
        let start = keyframes[0].screenPosition
        let peak = try peak(of: keyframes)
        let first = try firstRising(of: keyframes)
        let firstIndex = try #require(keyframes.firstIndex { $0.time == first.time })

        for keyframe in keyframes[...peak] {
            #expect(keyframe.screenPosition == start, "left the pointer during the pop, at \(keyframe.time) s")
        }
        #expect(isRight(first, of: start) == (draw >= 0), "wrong side for draw \(draw)")
        #expect(angle(of: first, from: start) >= 0.38, "angle \(angle(of: first, from: start))")
        for keyframe in keyframes[firstIndex...] {
            #expect(isRight(keyframe, of: start) == (draw >= 0), "crossed sides at \(keyframe.time) s")
        }
    }

    @Test(arguments: [(1.0, 4.0), (0.5, 2.2), (0.0, 0.4), (-1.0, 4.0)])
    func theSlantIsTheSwaysShareOfMaxSlantInAngle(draw: Double, degrees: Double) throws {
        let keyframes = try stage(draw: draw, reduceMotion: false).keyframes()
        let start = keyframes[0].screenPosition
        let first = try firstRising(of: keyframes)

        #expect(abs(angle(of: first, from: start) - degrees) <= 0.02, "angle \(angle(of: first, from: start))")
        #expect(isRight(first, of: start) == (draw >= 0))
    }

    @Test(arguments: [1.0, -1.0])
    func withNoSwayTheIconRisesAlongAStraightSlantedLineAndDoesNotTilt(draw: Double) throws {
        var tuning = LaunchTuning.shipped
        tuning.maximumSway = 0
        let keyframes = try stage(draw: draw, reduceMotion: false, tuning: tuning).keyframes()
        let start = keyframes[0].screenPosition
        let rising = keyframes.filter { $0.screenPosition.y > start.y }

        #expect(!rising.isEmpty)
        for keyframe in rising {
            #expect(abs(angle(of: keyframe, from: start) - 4) <= 1e-6, "angle at \(keyframe.time) s")
            #expect(isRight(keyframe, of: start) == (draw > 0))
        }
        for keyframe in keyframes {
            #expect(keyframe.rotationDegrees == 0, "tilted at \(keyframe.time) s")
        }
    }

    @Test func withNoSwayTheSideRuleStillHolds() throws {
        var tuning = LaunchTuning.shipped
        tuning.maximumSway = 0
        var flights = LaunchFlights()
        let sides = try [0.6, 0.6, 0.6].map { draw in
            let keyframes = try #require(
                flights.next(draw: draw, reduceMotion: false, tuning: tuning)
                    .staged(at: Self.middleOfBuiltIn, among: Self.displays)
            ).keyframes()
            return isRight(try firstRising(of: keyframes), of: keyframes[0].screenPosition)
        }

        #expect(sides == [true, true, false])
    }

    @Test func aSideNeverComesUpThreeTimesInARowFromTheFirstRisingMoment() throws {
        var flights = LaunchFlights()
        for expectedRight in [true, true, false] {
            let staged = try #require(
                flights.next(draw: 0.6, reduceMotion: false, tuning: .shipped)
                    .staged(at: Self.middleOfBuiltIn, among: Self.displays))
            let keyframes = try staged.keyframes()
            let start = keyframes[0].screenPosition

            #expect(isRight(try firstRising(of: keyframes), of: start) == expectedRight)
            #expect(isRight(try #require(keyframes.last), of: start) == expectedRight)
        }
    }

    @Test(arguments: [1.0, -1.0])
    func theDriftShareOfTheRiseOnlyGrowsAndNeverPassesAThird(draw: Double) throws {
        let keyframes = try stage(draw: draw, reduceMotion: false).keyframes()
        let start = keyframes[0].screenPosition
        let rising = keyframes.filter { $0.screenPosition.y > start.y }
        let ratios = rising.map { abs($0.screenPosition.x - start.x) / ($0.screenPosition.y - start.y) }

        for (previous, next) in zip(ratios, ratios.dropFirst()) {
            #expect(next >= previous - 1e-12, "ratio fell from \(previous) to \(next)")
        }
        #expect(try #require(ratios.last) <= 1.0 / 3)
    }

    @Test(arguments: draws)
    func underReduceMotionTheTunersSimulationAlsoFadesInPlaceWithoutSlant(draw: Double) throws {
        var forced = LaunchTuning.shipped
        forced.forceReduceMotion = true
        forced.maximumSlant = 20
        let systemSetting = try stage(draw: draw, reduceMotion: true).keyframes()
        let simulated = try stage(draw: draw, reduceMotion: false, tuning: forced).keyframes()

        for keyframes in [systemSetting, simulated] {
            for keyframe in keyframes {
                #expect(keyframe.screenPosition == Self.middleOfBuiltIn, "moved at \(keyframe.time) s")
                #expect(keyframe.side == 60)
                #expect(keyframe.rotationDegrees == 0)
            }
            #expect(try #require(keyframes.last).opacity == 0)
        }
    }

    @Test func aBounceEndingSlantsFromTheSpotItsInflatedIconIsAt() throws {
        let spot = CGPoint(x: 900, y: 500)
        var flights = LaunchFlights()
        let flight = flights.next(draw: 1, reduceMotion: false, tuning: .shipped).sized(1.4)
        let keyframes = try #require(flight.staged(at: spot, among: Self.displays)).keyframes()
        let peak = try peak(of: keyframes)
        let first = try firstRising(of: keyframes)

        #expect(keyframes[0].side == 84)
        for keyframe in keyframes[...peak] {
            #expect(keyframe.screenPosition == spot)
        }
        #expect(abs(angle(of: first, from: spot) - 4) <= 0.02)
        #expect(isRight(first, of: spot))

        var noPop = LaunchTuning.shipped
        noPop.popSize = 0
        var otherFlights = LaunchFlights()
        let unpopped = try #require(
            otherFlights.next(draw: 1, reduceMotion: false, tuning: noPop).sized(1.4)
                .staged(at: spot, among: Self.displays)
        ).keyframes()
        #expect(abs(angle(of: unpopped[1], from: spot) - 4) <= 0.02)
        #expect(isRight(unpopped[1], of: spot))
    }

    @Test func withMaxSlantZeroTheIconVeersAloneAndAtTwentyItLeansWithoutChangingTheRise() throws {
        var flat = LaunchTuning.shipped
        flat.maximumSlant = 0
        let flatFrames = try stage(draw: 1, reduceMotion: false, tuning: flat).keyframes()
        let flatStart = flatFrames[0].screenPosition
        let flatEnd = try #require(flatFrames.last).screenPosition
        #expect(angle(of: try firstRising(of: flatFrames), from: flatStart) <= 0.02)
        #expect(flatEnd.x > flatStart.x)
        #expect(abs((flatEnd.x - flatStart.x) / (flatEnd.y - flatStart.y) - 0.26) <= 1e-9)

        var steep = LaunchTuning.shipped
        steep.maximumSlant = 20
        for draw in [1.0, -1.0] {
            let frames = try stage(draw: draw, reduceMotion: false, tuning: steep).keyframes()
            let first = try firstRising(of: frames)
            #expect(abs(angle(of: first, from: frames[0].screenPosition) - 20) <= 0.02)
            #expect(isRight(first, of: frames[0].screenPosition) == (draw > 0))
        }

        let halfShare = try stage(draw: 0.5, reduceMotion: false, tuning: steep).keyframes()
        #expect(abs(angle(of: try firstRising(of: halfShare), from: halfShare[0].screenPosition) - 11) <= 0.02)

        let halfFlat = try stage(draw: 0.5, reduceMotion: false, tuning: flat).keyframes()
        #expect(halfShare.count == halfFlat.count)
        for (a, b) in zip(halfShare, halfFlat) {
            let riseA = a.screenPosition.y - halfShare[0].screenPosition.y
            let riseB = b.screenPosition.y - halfFlat[0].screenPosition.y
            #expect(abs(a.time - b.time) <= 1e-9)
            #expect(abs(riseA - riseB) <= 1e-9, "rise differs at \(a.time) s")
        }
    }

    @Test(arguments: modes, draws)
    func iconAppearsAtThePointerAtFullSizeAndFullyOpaqueAndNeverFadesIn(
        reduceMotion: Bool, draw: Double
    ) throws {
        let staged = try stage(draw: draw, reduceMotion: reduceMotion)
        let keyframes = try staged.keyframes()
        let first = try #require(keyframes.first)

        #expect(first.time == 0)
        #expect(first.screenPosition == Self.middleOfBuiltIn)
        #expect(first.side == 60)
        #expect(first.opacity == 1)
        #expect(first.rotationDegrees == 0)
        for (previous, next) in zip(keyframes, keyframes.dropFirst()) {
            #expect(next.side >= 60 || next.time > 0.1, "shrank below its start size during the pop, at \(next.time) s")
            #expect(next.opacity <= previous.opacity, "faded in at \(next.time) s")
        }
    }

    @Test(arguments: draws)
    func iconPopsInPlaceTo110To130PercentWithinTheFirst100Milliseconds(draw: Double) throws {
        let keyframes = try stage(draw: draw, reduceMotion: false).keyframes()
        let peak = try peak(of: keyframes)

        #expect((66...78).contains(keyframes[peak].side), "peak side \(keyframes[peak].side)")
        #expect(keyframes[peak].time <= 0.1, "peak at \(keyframes[peak].time) s")
        for (previous, next) in zip(keyframes[...peak], keyframes[...peak].dropFirst()) {
            #expect(next.side > previous.side, "did not swell at \(next.time) s")
            #expect(next.screenPosition == Self.middleOfBuiltIn, "moved while swelling, at \(next.time) s")
            #expect(next.rotationDegrees == 0, "tilted while swelling, at \(next.time) s")
            #expect(next.opacity == 1, "faded while swelling, at \(next.time) s")
        }
    }

    @Test(arguments: draws)
    func iconRisesFasterAndFasterToBetween60And80PointsAboveItsStart(draw: Double) throws {
        let keyframes = try stage(draw: draw, reduceMotion: false).keyframes()
        let rises = keyframes.map { $0.screenPosition.y - keyframes[0].screenPosition.y }
        let halfway = try #require(keyframes.lastIndex { $0.time <= LaunchTuning.shipped.duration / 2 + 1e-9 })
        let last = try #require(rises.last)

        #expect((60...80).contains(last))
        #expect(last - rises[halfway] > rises[halfway] - rises[0], "more height in the second half than in the first")
        let flight = try rises[peak(of: keyframes)...]
        let steps = zip(flight, flight.dropFirst()).map { $1 - $0 }
        for (step, nextStep) in zip(steps, steps.dropFirst()) {
            #expect(nextStep > step, "rise did not speed up")
        }
    }

    @Test(arguments: draws)
    func afterThePopIconShrinksSteadilyToNoMoreThan60PercentOfItsStartSize(draw: Double) throws {
        let keyframes = try stage(draw: draw, reduceMotion: false).keyframes()
        let flight = try keyframes[peak(of: keyframes)...]

        for (previous, next) in zip(flight, flight.dropFirst()) {
            #expect(next.side < previous.side, "did not shrink at \(next.time) s")
        }
        #expect(try #require(keyframes.last).side <= 36)
    }

    @Test(arguments: draws)
    func iconStaysNearlyOpaqueAtFirstThenFadesOutWhileStillClearlyLargerThanADot(draw: Double) throws {
        let keyframes = try stage(draw: draw, reduceMotion: false).keyframes()

        for keyframe in keyframes where keyframe.time <= 0.2 + 1e-9 {
            #expect(keyframe.opacity >= 0.9, "already fading at \(keyframe.time) s")
        }
        let gone = try #require(keyframes.first { $0.opacity == 0 }, "never fully invisible")
        #expect(gone.side >= 60 / 3)
    }

    @Test(arguments: modes, draws)
    func iconIsFullyInvisibleBetween300And400Milliseconds(reduceMotion: Bool, draw: Double) throws {
        let staged = try stage(draw: draw, reduceMotion: reduceMotion)
        let keyframes = try staged.keyframes()

        for animation in staged.animations {
            #expect(
                (0.3...0.4).contains(animation.duration), "\(animation.keyPath ?? "") lasts \(animation.duration) s")
        }
        for keyframe in keyframes where keyframe.time < 0.3 {
            #expect(keyframe.opacity > 0, "invisible too early, at \(keyframe.time) s")
        }
        let gone = try #require(keyframes.first { $0.opacity == 0 }, "never fully invisible")
        #expect(gone.time <= 0.4)
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
                flights.next(draw: draw, reduceMotion: false, tuning: .shipped).staged(at: Self.middleOfBuiltIn, among: Self.displays))
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
            #expect(keyframe.side == 60, "shrank at \(keyframe.time) s")
            #expect(keyframe.rotationDegrees == 0, "tilted at \(keyframe.time) s")
        }
    }

    @Test func reduceMotionFlightsDoNotCountTowardsASwayStreak() throws {
        var flights = LaunchFlights()
        var sides: [Bool] = []
        for reduceMotion in [false, true, false, true, false] {
            let flight = flights.next(draw: 0.6, reduceMotion: reduceMotion, tuning: .shipped)
            guard !reduceMotion else { continue }
            let keyframes = try #require(flight.staged(at: Self.middleOfBuiltIn, among: Self.displays)).keyframes()
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

    /// AppKit counts a display's top edge as inside it and its bottom edge as outside, whichever display is listed
    /// first.
    @Test(arguments: draws)
    func onTheEdgeTheDisplaysShareTheIconStaysOnTheDisplayBelow(draw: Double) throws {
        let edge = CGPoint(x: 700, y: 982)
        let sharedEdge = try stage(draw: draw, reduceMotion: false, at: edge)
        let sharedEdgeExternalFirst = try stage(draw: draw, reduceMotion: false, at: edge, among: [.external, .builtIn])
        let bottomEdge = try stage(draw: draw, reduceMotion: false, at: CGPoint(x: 700, y: 0))

        #expect(LaunchDisplay.builtIn.frame.contains(sharedEdge.frame))
        #expect(sharedEdge.frame.maxY == 982)
        #expect(LaunchDisplay.builtIn.frame.contains(sharedEdgeExternalFirst.frame), "external display listed first")
        #expect(sharedEdgeExternalFirst.frame.maxY == 982, "external display listed first")
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
