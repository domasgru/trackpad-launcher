import AppKit
import LauncherCore
import Testing

@testable import LauncherPlatform

/// One sampled moment of a bounce's transform keyframes.
private struct Sample {
    let time: Double
    let lift: Double
    let width: Double
    let height: Double
}

extension CAMediaTimingFunction {
    /// Starts fast and ends slow: the second control point sits above the diagonal, ending flat.
    var easesOut: Bool {
        var start: [Float] = [0, 0]
        var end: [Float] = [0, 0]
        getControlPoint(at: 1, values: &start)
        getControlPoint(at: 2, values: &end)
        return start == [0, 0] && end[1] == 1 && end[0] < 1
    }
}

private let displays:[LaunchDisplay] = [.builtIn, .external]
private let shipped = LaunchTuning.Bounce()

private func row(
    _ count: Int, at pointer: CGPoint, among displays: [LaunchDisplay] = displays,
    tuning: LaunchTuning.Bounce = shipped, sourceLocation: SourceLocation = #_sourceLocation
) throws -> BounceRow {
    try #require(
        BounceRow(count: count, pointer: pointer, among: displays, side: 60, tuning: tuning),
        sourceLocation: sourceLocation)
}

/// The jump style's motion, whatever style ships: these rows pin the jump, which the tuner can still switch to.
private func motion(_ tuning: LaunchTuning.Bounce = shipped, reduceMotion: Bool = false) -> BounceMotion {
    var jump = tuning
    jump.style = .jump
    return BounceMotion(tuning: jump, reduceMotion: reduceMotion)
}

private func samples(_ motion: BounceMotion, sourceLocation: SourceLocation = #_sourceLocation) throws -> [Sample] {
    let animation = try #require(motion.animations().first { $0.keyPath == "transform" }, sourceLocation: sourceLocation)
    let values = try #require(animation.values as? [NSValue], sourceLocation: sourceLocation).map(\.caTransform3DValue)
    let times = try #require(animation.keyTimes, sourceLocation: sourceLocation).map(\.doubleValue)
    return times.indices.map { i in
        let m = values[i]
        return Sample(time: times[i] * animation.duration, lift: m.m42, width: 60 * m.m11, height: 60 * m.m22)
    }
}

private func opacities(_ motion: BounceMotion, sourceLocation: SourceLocation = #_sourceLocation) throws -> (
    times: [Double], values: [Double], animation: CAKeyframeAnimation
) {
    let animation = try #require(motion.animations().first { $0.keyPath == "opacity" }, sourceLocation: sourceLocation)
    let values = try #require(animation.values as? [NSNumber], sourceLocation: sourceLocation).map(\.doubleValue)
    let times = try #require(animation.keyTimes, sourceLocation: sourceLocation).map { $0.doubleValue * animation.duration }
    return (times, values, animation)
}

@Suite struct BounceRowTests {
    static let middle = CGPoint(x: 700, y: 400)

    @Test func oneIconRestsCentredOnTheTipEightPointsAbove() throws {
        #expect(try row(1, at: Self.middle).rests == [CGPoint(x: 700, y: 408)])
    }

    @Test func severalIconsSitInOneRowNewestOnTheRight() throws {
        #expect(try row(2, at: Self.middle).rests == [CGPoint(x: 664, y: 408), CGPoint(x: 736, y: 408)])
        let five = try row(5, at: Self.middle).rests
        #expect(five.map(\.x) == [556, 628, 700, 772, 844])
        #expect(five.allSatisfy { $0.y == 408 })
    }

    @Test(arguments: [
        (1502.0, 1, 1512.0),
        (1482.0, 1, 1512.0),
        (1502.0, 5, 1512.0),
    ])
    func nearTheRightEdgeTheRowSlidesToStayOnTheDisplay(x: Double, count: Int, rightEdge: Double) throws {
        let rests = try row(count, at: CGPoint(x: x, y: 400)).rests
        #expect(rests.last.map { Double($0.x) + 30 } == rightEdge)
        #expect(zip(rests, rests.dropFirst()).allSatisfy { $1.x - $0.x == 72 })
        #expect(rests.allSatisfy { $0.y == 408 })
    }

    @Test func aRowHalfAnIconInIsNotSlidAndOnePointFurtherSlidesOnePoint() throws {
        #expect(try row(1, at: CGPoint(x: 1482, y: 400)).rests.first?.x == 1482)
        #expect(try row(1, at: CGPoint(x: 1483, y: 400)).rests.first?.x == 1482)
    }

    @Test func nearTheLeftEdgeTheLeftEdgeStopsAtTheDisplay() throws {
        let rests = try row(1, at: CGPoint(x: 10, y: 400)).rests
        #expect(rests.first.map { $0.x - 30 } == 0)
    }

    @Test(arguments: [970.0, 981.0])
    func onTheMenuBarTheRestsStayAboveThePointerOnItsOwnDisplay(y: Double) throws {
        let staged = try row(1, at: CGPoint(x: 700, y: y))
        #expect(staged.display == .builtIn)
        #expect(staged.rests.first.map { Double($0.y) } == y + 8)
    }

    @Test func aPointerOnAOneXDisplayRestsOnWholePoints() throws {
        let staged = try row(1, at: CGPoint(x: 1000, y: 2000))
        #expect(staged.display == .external)
        #expect(staged.rests == [CGPoint(x: 1000, y: 2008)])
    }

    @Test func restsAreSnappedToTheDisplaysPixels() throws {
        let rests = try row(2, at: CGPoint(x: 700.3, y: 400.2)).rests
        for rest in rests {
            #expect((rest.x * 2).truncatingRemainder(dividingBy: 1) == 0)
            #expect((rest.y * 2).truncatingRemainder(dividingBy: 1) == 0)
        }
    }

    @Test func withoutDisplaysThereIsNoRow() {
        #expect(BounceRow(count: 1, pointer: Self.middle, among: [], side: 60, tuning: shipped) == nil)
    }

    @Test func theSlideStartsAtTheOldRestAndEndsAtTheNewOneEasingOut() throws {
        let slide = try #require(
            BounceRow.slide(from: CGPoint(x: 664, y: 408), to: CGPoint(x: 700, y: 408), tuning: shipped))
        #expect(slide.keyPath == "position")
        #expect(slide.isAdditive)
        #expect((slide.fromValue as? NSValue)?.pointValue == CGPoint(x: -36, y: 0))
        #expect((slide.toValue as? NSValue)?.pointValue == .zero)
        #expect(slide.duration == 0.2)
        #expect(slide.timingFunction?.easesOut == true)
        #expect(BounceRow.slide(from: CGPoint(x: 700, y: 408), to: CGPoint(x: 700, y: 408), tuning: shipped) == nil)
    }

    @Test func gapOffsetAndSpacingMoveTheRowAndNothingElse() throws {
        var tuning = shipped
        tuning.gap = 20
        #expect(try row(1, at: Self.middle, tuning: tuning).rests == [CGPoint(x: 700, y: 420)])
        tuning = shipped
        tuning.offset = 15
        #expect(try row(1, at: Self.middle, tuning: tuning).rests == [CGPoint(x: 715, y: 408)])
        tuning = shipped
        tuning.spacing = 20
        let rests = try row(2, at: Self.middle, tuning: tuning).rests
        #expect(rests.map(\.x) == [660, 740])
    }
}

@Suite struct BounceMotionTests {
    @Test func theJumpRisesToAboutHalfTheIconSlowingThenFallsWithGravity() throws {
        let motion = motion()
        let samples = try samples(motion)
        let animation = try #require(motion.animations().first)
        #expect((0.65...0.75).contains(motion.period))
        #expect(animation.repeatCount == .infinity)
        #expect(animation.calculationMode == .linear)
        #expect(samples.first?.lift == 0)
        let moved = try #require(samples.first { $0.lift > 0 })
        #expect(moved.time <= 0.02)
        let topIndex = try #require(samples.indices.max { samples[$0].lift < samples[$1].lift })
        #expect((27.0...33.0).contains(samples[topIndex].lift))
        let rise = samples[...topIndex].map(\.lift)
        let riseSpeeds = zip(rise, rise.dropFirst()).map { $1 - $0 }
        #expect(zip(riseSpeeds, riseSpeeds.dropFirst()).allSatisfy { $1 < $0 })
        let fall = Array(samples[topIndex...].prefix { $0.lift > 0 }.map(\.lift)) + [0]
        let fallSpeeds = zip(fall, fall.dropFirst()).map { $0 - $1 }
        #expect(zip(fallSpeeds, fallSpeeds.dropFirst()).allSatisfy { $1 > $0 })
        #expect(samples.allSatisfy { $0.lift >= 0 })
        #expect(samples.last?.lift == 0)
    }

    @Test func shippedTheIconKeepsItsSizeAndShape() throws {
        for sample in try samples(motion()) {
            #expect(abs(sample.width - 60) < 1e-9)
            #expect(abs(sample.height - 60) < 1e-9)
        }
    }

    @Test func squashOnLandingKeepsTheAreaAndTheBottom() throws {
        var tuning = shipped
        tuning.squash = 0.2
        let samples = try samples(motion(tuning))
        let landed = try #require(samples.min { $0.height < $1.height })
        #expect(abs(landed.height - 48) < 1e-6)
        #expect(abs(landed.width - 75) < 1e-6)
        #expect(landed.lift == 0)
        #expect(samples.allSatisfy { abs($0.width * $0.height - 3600) < 1e-6 })
    }

    @Test func reduceMotionPulsesOpacityInPlace() throws {
        let motion = motion(reduceMotion: true)
        #expect(motion.animations().allSatisfy { $0.keyPath == "opacity" })
        let (times, values, animation) = try opacities(motion)
        #expect(animation.repeatCount == .infinity)
        #expect(animation.duration == 1.4)
        #expect(motion.period == 1.4)
        #expect(times.last.map { abs($0 - 1.4) < 1e-9 } == true)
        #expect(values.first == 1)
        #expect(values.allSatisfy { (0.5 - 1e-9...1).contains($0) })
        #expect(values.min().map { abs($0 - 0.5) < 1e-3 } == true)
    }

    @Test(arguments: [Float(1), 0.73, 0.5])
    func theQuietFadeFallsFromWhereItIsToNothingEasingOut(opacity: Float) throws {
        let fade = motion().quietFade(from: opacity)
        #expect(fade.keyPath == "opacity")
        #expect((fade.fromValue as? NSNumber)?.floatValue == opacity)
        #expect((fade.toValue as? NSNumber)?.floatValue == 0)
        #expect(fade.duration == 0.2)
        #expect(fade.timingFunction?.easesOut == true)
    }

    @Test func heightSetsTheTop() throws {
        var tuning = shipped
        tuning.height = 50
        #expect(try samples(motion(tuning)).map(\.lift).max() == 50)
    }

    @Test func timeUpSetsWhenTheTopIsReached() throws {
        var tuning = shipped
        tuning.timeUp = 0.5
        let samples = try samples(motion(tuning))
        let top = try #require(samples.max { $0.lift < $1.lift })
        #expect(abs(top.time - 0.5) < 1e-6)
    }

    @Test func timeDownSetsHowLongTheFallLasts() throws {
        var tuning = shipped
        tuning.timeDown = 0.5
        let samples = try samples(motion(tuning))
        let top = try #require(samples.max { $0.lift < $1.lift })
        let landing = try #require(samples.first { $0.time > top.time && $0.lift == 0 })
        #expect(abs(landing.time - top.time - 0.5) < 1e-6)
    }

    @Test func restSetsHowLongTheIconStaysOnTheGround() throws {
        var tuning = shipped
        tuning.rest = 0.3
        let samples = try samples(motion(tuning))
        let landing = try #require(samples.first { $0.time > 0.3 && $0.lift == 0 })
        #expect(abs((samples.last?.time ?? 0) - landing.time - 0.3) < 1e-6)
    }

    @Test func pulseKnobsSetTheRangeAndThePeriod() throws {
        var tuning = shipped
        tuning.pulseLow = 0.2
        tuning.pulsePeriod = 2
        let (times, values, animation) = try opacities(motion(tuning, reduceMotion: true))
        #expect(animation.duration == 2)
        #expect(abs((times.last ?? 0) - 2) < 1e-9)
        #expect(values.min().map { abs($0 - 0.2) < 1e-3 } == true)
    }

    @Test func fadeOutSetsTheFadesLength() {
        var tuning = shipped
        tuning.fadeOut = 0.5
        #expect(motion(tuning).quietFade(from: 1).duration == 0.5)
    }

    @Test func slideSetsTheSlidesLength() throws {
        var tuning = shipped
        tuning.slide = 0.4
        let slide = try #require(BounceRow.slide(from: .zero, to: CGPoint(x: 1, y: 0), tuning: tuning))
        #expect(slide.duration == 0.4)
    }
}

@Suite struct LaunchReportGateTests {
    private func admitted(_ reports: [LaunchProgress]) -> [LaunchProgress] {
        var gate = LaunchReportGate()
        return reports.filter { gate.admits($0) }
    }

    @Test func finishedLaunchingIsAdmittedOnceThenOneTerminalFact() {
        #expect(
            admitted([.finishedLaunching, .finishedLaunching, .windowShown, .windowShown, .ranOut, .wentNowhere])
                == [.finishedLaunching, .windowShown])
        #expect(admitted([.ranOut, .finishedLaunching, .windowShown]) == [.ranOut])
    }

    @Test(arguments: [LaunchProgress.windowShown, .wentNowhere, .ranOut])
    func eachTerminalFactIsAdmittedAloneAndNothingAfterIt(terminal: LaunchProgress) {
        let others: [LaunchProgress] = [.finishedLaunching, .windowShown, .wentNowhere, .ranOut]
        #expect(admitted([terminal] + others) == [terminal])
    }
}
