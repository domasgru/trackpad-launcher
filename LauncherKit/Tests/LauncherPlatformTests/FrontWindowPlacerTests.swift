import CoreGraphics
import Foundation
import LauncherCore
import Synchronization
import Testing

@testable import LauncherPlatform

private typealias Outcome = FrontWindowPlacer.Outcome
private typealias Window = ScriptedPlacing.Window
private typealias Write = ScriptedPlacing.Write

private func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> CGRect {
    CGRect(x: x, y: y, width: width, height: height)
}

private let primary = rect(0, 0, 1512, 982)
private let standardHalves = SplitHalves(visible: rect(0, 0, 1512, 949), primary: primary)
private let start = Uptime(seconds: 0)
private let freshBudget = ReadBudget(from: start, within: FrontWindowPlacer.budget)

private func place(
    _ calls: ScriptedPlacing, in halves: SplitHalves = standardHalves, side: SplitSide, previous: CGRect? = nil,
    isLatest: @escaping () -> Bool = { true }
) -> Outcome {
    FrontWindowPlacer.place(
        1, in: halves, side: side, previous: previous, budget: freshBudget, calls: calls, isLatest: isLatest)
}

private func window(_ frame: CGRect, minimumWidth: Double? = nil, maximumWidth: Double? = nil, fixed: Bool = false) -> Window {
    var window = Window(frame)
    window.minimumSize = minimumWidth.map { CGSize(width: $0, height: 0) }
    window.maximumSize = maximumWidth.map { CGSize(width: $0, height: .greatestFiniteMagnitude) }
    window.isFixed = fixed
    return window
}

private func position(_ x: Double, _ y: Double) -> Write { .position(CGPoint(x: x, y: y)) }
private func size(_ width: Double, _ height: Double) -> Write { .size(CGSize(width: width, height: height)) }

private func expectTimeouts(_ actual: [Float], _ expected: [Float], sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(actual.count == expected.count, sourceLocation: sourceLocation)
    for (a, e) in zip(actual, expected) { #expect(abs(a - e) < 0.0001, "\(actual)", sourceLocation: sourceLocation) }
}

@Suite struct SplitHalvesTests {
    fileprivate struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let visible: CGRect
        var primary = rect(0, 0, 1512, 982)
        let left: CGRect
        let right: CGRect
        var testDescription: String { name }
    }

    fileprivate static let cases = [
        Case(name: "notch display", visible: rect(0, 0, 1512, 949), left: rect(0, 33, 756, 949), right: rect(756, 33, 756, 949)),
        Case(name: "Dock at the bottom", visible: rect(0, 70, 1512, 879), left: rect(0, 33, 756, 879), right: rect(756, 33, 756, 879)),
        Case(
            name: "odd width", visible: rect(0, 0, 1511, 949), primary: rect(0, 0, 1511, 982),
            left: rect(0, 33, 756, 949), right: rect(756, 33, 755, 949)),
        Case(
            name: "fractional", visible: rect(0, 69.5, 1512, 879.5), left: rect(0, 33, 756, 879),
            right: rect(756, 33, 756, 879)),
        Case(
            name: "display to the right", visible: rect(1512, 0, 1920, 1055), left: rect(1512, -73, 960, 1055),
            right: rect(2472, -73, 960, 1055)),
        Case(
            name: "display above", visible: rect(-524, 982, 2560, 1415), left: rect(-524, -1415, 1280, 1415),
            right: rect(756, -1415, 1280, 1415)),
    ]

    @Test(arguments: cases) fileprivate func halvesOfTheUsableArea(_ c: Case) {
        let halves = SplitHalves(visible: c.visible, primary: c.primary)
        #expect(halves.left == c.left)
        #expect(halves.right == c.right)
        #expect(halves.right.minX == halves.left.maxX)
        #expect(halves.left.width - halves.right.width == 0 || halves.left.width - halves.right.width == 1)
        #expect(halves[.left] == halves.left && halves[.right] == halves.right)
    }

    @Test func theDisplayUnderThePointerIsFoundByItsNumber() {
        let displays: [LaunchDisplay] = [.builtIn, .external]
        #expect(LaunchDisplay.containing(CGPoint(x: 1000, y: 2410), among: displays)?.id == DisplayID(rawValue: 2))
        #expect(LaunchDisplay.containing(CGPoint(x: 700, y: 982), among: displays)?.id == DisplayID(rawValue: 1))
    }
}

@Suite struct FrontWindowPlacerSequenceTests {
    fileprivate struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let side: SplitSide
        let window: Window
        var halves = standardHalves
        let writes: [Write]
        let frame: CGRect
        var refusedSize = false
        var testDescription: String { name }
    }

    private static let narrow = SplitHalves(visible: rect(0, 0, 1400, 949), primary: rect(0, 0, 1400, 982))

    fileprivate static let cases = [
        Case(
            name: "left, resizable", side: .left, window: window(rect(200, 450, 500, 332)),
            writes: [position(0, 33), size(756, 949)], frame: rect(0, 33, 756, 949)),
        Case(
            name: "right, resizable", side: .right, window: window(rect(260, 390, 800, 332)),
            writes: [position(756, 33), size(756, 949)], frame: rect(756, 33, 756, 949)),
        Case(
            name: "right, minimum width 900", side: .right, window: window(rect(260, 390, 900, 332), minimumWidth: 900),
            writes: [position(756, 33), size(756, 949), position(612, 33)], frame: rect(612, 33, 900, 949)),
        Case(
            name: "right, minimum width 900 on 1400 points", side: .right,
            window: window(rect(260, 390, 900, 332), minimumWidth: 900), halves: narrow,
            writes: [position(700, 33), size(700, 949), position(500, 33)], frame: rect(500, 33, 900, 949)),
        Case(
            name: "left, fixed size", side: .left, window: window(rect(320, 300, 230, 362), fixed: true),
            writes: [position(0, 33), size(756, 949)], frame: rect(0, 33, 230, 362)),
        Case(
            name: "right, fixed size", side: .right, window: window(rect(320, 300, 230, 362), fixed: true),
            writes: [position(756, 33), size(756, 949), position(1282, 33)], frame: rect(1282, 33, 230, 362)),
        Case(
            name: "right, maximum width 500", side: .right, window: window(rect(320, 300, 500, 332), maximumWidth: 500),
            writes: [position(756, 33), size(756, 949), position(1012, 33)], frame: rect(1012, 33, 500, 949)),
    ]

    @Test(arguments: cases) fileprivate func aWindowTakesTheClosestSizeItAllowsAnchoredAtItsHalfsOuterCorner(_ c: Case) {
        let calls = ScriptedPlacing(c.window)

        let outcome = place(calls, in: c.halves, side: c.side)

        #expect(calls.writes() == c.writes)
        #expect(outcome == .placed(c.frame))
        #expect(calls.frame() == c.frame)
    }

    @Test func aFullScreenWindowLeavesFullScreenFirstThenIsPlaced() {
        var fullScreen = Window(rect(0, 0, 1512, 982))
        fullScreen.isFullScreen = true
        let calls = ScriptedPlacing(fullScreen)

        let outcome = place(calls, side: .right)

        #expect(calls.writes() == [.fullScreen(false), position(756, 33), size(756, 949)])
        #expect(outcome == .placed(rect(756, 33, 756, 949)))
    }

    @Test func aFullScreenWindowIsNeverAlreadyThere() {
        for previous in [nil, rect(0, 33, 756, 949)] {
            var fullScreen = Window(rect(0, 33, 756, 949))
            fullScreen.isFullScreen = true
            let calls = ScriptedPlacing(fullScreen)

            let outcome = place(calls, side: .left, previous: previous)

            #expect(calls.writes().first == .fullScreen(false))
            #expect(outcome != .alreadyThere)
        }
    }

    @Test func aWindowThatRefusesToLeaveFullScreenStaysWhereItWas() {
        var fullScreen = Window(rect(0, 0, 1512, 982))
        fullScreen.isFullScreen = true
        let calls = ScriptedPlacing(fullScreen, script: .init(errors: ["setFullScreen": .other]))

        let outcome = place(calls, side: .right)

        #expect(calls.writes() == [.fullScreen(false)])
        #expect(outcome == .refused)
        #expect(calls.frame() == rect(0, 0, 1512, 982))
        #expect(calls.intoApp().last == "setFullScreen")
    }
}

@Suite struct FrontWindowPlacerAlreadyThereTests {
    @Test func aWindowAlreadyInItsHalfIsLeftAlone() {
        for (side, frame) in [(SplitSide.left, rect(0, 33, 756, 949)), (.right, rect(756, 33, 756, 949))] {
            let calls = ScriptedPlacing(window(frame))
            #expect(place(calls, side: side) == .alreadyThere)
            #expect(calls.writes().isEmpty)
        }
    }

    @Test func aWindowTheUserMovedIsPlacedAgain() {
        let calls = ScriptedPlacing(window(rect(100, 200, 756, 949)))
        _ = place(calls, side: .left)
        #expect(calls.writes() == [position(0, 33), size(756, 949)])
    }

    @Test func aWindowStillWhereTheLastPlacingLeftItIsLeftAlone() {
        let cases: [(SplitSide, Window)] = [
            (.right, window(rect(612, 33, 900, 949), minimumWidth: 900)),
            (.right, window(rect(1012, 33, 500, 949), maximumWidth: 500)),
            (.left, window(rect(0, 33, 230, 362), fixed: true)),
        ]
        for (side, window) in cases {
            let calls = ScriptedPlacing(window)
            #expect(place(calls, side: side, previous: window.frame) == .alreadyThere)
            #expect(calls.writes().isEmpty)
        }
    }

    @Test func aRememberedWindowTheUserDraggedIsPlacedAgain() {
        let calls = ScriptedPlacing(window(rect(100, 200, 900, 949), minimumWidth: 900))
        _ = place(calls, side: .right, previous: rect(612, 33, 900, 949))
        #expect(calls.writes() == [position(756, 33), size(756, 949), position(612, 33)])
    }
}

@Suite struct FrontWindowPlacerBudgetTests {
    private func resizingWindow() -> Window { window(rect(260, 390, 900, 332), minimumWidth: 900) }

    @Test func everyCallGetsWhatIsLeftOfTheBudgetAndNoCallFollowsTheLastOfIt() {
        let calls = ScriptedPlacing(resizingWindow(), script: .init(defaultCost: 100))
        let outcome = place(calls, side: .right)
        expectTimeouts(calls.timeouts(), [0.5, 0.4, 0.3, 0.2, 0.1])
        #expect(calls.intoApp() == ["mainWindow", "state", "setPosition", "setSize", "size"])
        #expect(calls.writes() == [position(756, 33), size(756, 949)])
        #expect(outcome == .unanswered)
    }

    @Test func withNoTimeLeftForTheReadBackTheFrameAskedForIsAnswered() {
        let calls = ScriptedPlacing(resizingWindow(), script: .init(defaultCost: 99))
        let outcome = place(calls, side: .right)
        #expect(calls.intoApp().count == 6)
        #expect(abs((calls.timeouts().last ?? 0) - 0.005) < 0.0001)
        #expect(calls.writes().last == position(612, 33))
        #expect(outcome == .placed(rect(612, 33, 900, 949)))
    }

    @Test func theFrameMacOSLeftIsReadBackWithTimeToSpare() {
        let calls = ScriptedPlacing(resizingWindow(), script: .init(drift: CGPoint(x: 1, y: 0)))
        let outcome = place(calls, side: .right)
        #expect(calls.intoApp().count == 7)
        #expect(calls.intoApp().last == "state")
        #expect(outcome == .placed(rect(613, 33, 900, 949)))
    }

    @Test func aMainWindowCallThatTakesTheWholeBudgetEndsIt() {
        let calls = ScriptedPlacing(resizingWindow(), script: .init(costs: ["mainWindow": 600]))
        #expect(place(calls, side: .right) == .unanswered)
        #expect(calls.intoApp() == ["mainWindow"])
    }

    @Test func aCallThatCannotCompleteEndsItWithNoFurtherCall() {
        let state = ScriptedPlacing(resizingWindow(), script: .init(errors: ["state": .cannotComplete]))
        #expect(place(state, side: .right) == .unanswered)
        #expect(state.intoApp() == ["mainWindow", "state"])
        #expect(state.writes().isEmpty)

        let position = ScriptedPlacing(resizingWindow(), script: .init(errors: ["setPosition": .cannotComplete]))
        #expect(place(position, side: .right) == .unanswered)
        #expect(position.intoApp().last == "setPosition")
    }

    @Test func aRefusedPositionEndsItAndTheWindowStaysWhereItWas() {
        let calls = ScriptedPlacing(resizingWindow(), script: .init(errors: ["setPosition": .other]))
        #expect(place(calls, side: .right) == .refused)
        #expect(calls.intoApp().last == "setPosition")
        #expect(calls.frame() == rect(260, 390, 900, 332))
    }

    @Test func anAppWithNoWindowAtAllIsNoWindow() {
        let calls = ScriptedPlacing([1: .init(windows: [], main: nil)])
        #expect(place(calls, side: .right) == .noWindow)
        #expect(calls.intoApp() == ["mainWindow", "windows"])
    }
}

@Suite struct FrontWindowPlacerTicketTests {
    private final class Latest: Sendable {
        let value = Mutex(true)
        func stop() { value.withLock { $0 = false } }
        var isLatest: Bool { value.withLock { $0 } }
    }

    private func run(stoppingIn call: String?, window: Window = window(rect(260, 390, 800, 332))) -> (ScriptedPlacing, Outcome) {
        let latest = Latest()
        let calls = ScriptedPlacing(
            [1: .init(windows: [window])], hook: { _, name in if name == call { latest.stop() } })
        return (calls, place(calls, side: .right, isLatest: { latest.isLatest }))
    }

    @Test func aNewerPlacingStopsAnOlderOneBeforeItsNextCall() {
        let (position, positionOutcome) = run(stoppingIn: "setPosition")
        #expect(position.intoApp().last == "setPosition")
        #expect(position.writes() == [Write.position(CGPoint(x: 756, y: 33))])
        #expect(positionOutcome == .superseded)

        let (main, mainOutcome) = run(stoppingIn: "mainWindow")
        #expect(main.intoApp() == ["mainWindow"])
        #expect(mainOutcome == .superseded)

        var fullScreen = window(rect(0, 0, 1512, 982))
        fullScreen.isFullScreen = true
        let (exit, exitOutcome) = run(stoppingIn: "setFullScreen", window: fullScreen)
        #expect(exit.writes() == [.fullScreen(false)])
        #expect(exitOutcome == .superseded)
    }

    @Test func aPlacingThatIsNotTheLatestFromTheStartMakesNoCall() {
        let calls = ScriptedPlacing(window(rect(260, 390, 800, 332)))
        #expect(place(calls, side: .right, isLatest: { false }) == .superseded)
        #expect(calls.intoApp().isEmpty)
    }
}

@Suite struct FrontWindowPlacerWindowChoiceTests {
    private func resizable(_ x: Double = 50) -> Window { window(rect(x, 50, 500, 400)) }

    @Test func theMainWindowIsPlaced() {
        let calls = ScriptedPlacing([1: .init(windows: [resizable(), resizable(80)], main: 2)])
        _ = place(calls, side: .right)
        #expect(calls.touched() == [2])
    }

    @Test func withNoMainWindowTheFirstStandardWindowThatIsNotMinimisedIsPlaced() {
        var panel = resizable()
        panel.isStandard = false
        var minimised = resizable(60)
        minimised.isMinimised = true
        let calls = ScriptedPlacing([1: .init(windows: [panel, minimised, resizable(70)], main: nil)])
        _ = place(calls, side: .right)
        #expect(calls.touched() == [3])
    }

    @Test func aMinimisedOnlyWindowIsNoWindow() {
        var minimised = resizable()
        minimised.isMinimised = true
        let calls = ScriptedPlacing([1: .init(windows: [minimised], main: nil)])
        #expect(place(calls, side: .right) == .noWindow)
        #expect(calls.writes().isEmpty)
    }

    @Test func aMainWindowCallThatCannotCompleteEndsIt() {
        let calls = ScriptedPlacing(resizable(), script: .init(errors: ["mainWindow": .cannotComplete]))
        #expect(place(calls, side: .right) == .unanswered)
        #expect(calls.intoApp() == ["mainWindow"])
    }
}

@MainActor @Suite(.timeLimit(.minutes(1))) struct FrontWindowPlacerInstanceTests {
    private static let d1 = DisplayID(rawValue: 1)
    private static let d2 = DisplayID(rawValue: 2)
    private static let screens = PlacingScreens(
        primary: rect(0, 0, 1512, 982), visible: [d1: rect(0, 0, 1512, 949), d2: rect(1512, 0, 1920, 1055)])
    private static let safari = BundleID(rawValue: "com.test.safari")
    private static let notes = BundleID(rawValue: "com.test.notes")
    private static let mail = BundleID(rawValue: "com.test.mail")
    private static let calendar = BundleID(rawValue: "com.test.calendar")

    private func L(_ display: DisplayID) -> ScreenHalf { ScreenHalf(side: .left, display: display) }
    private func R(_ display: DisplayID) -> ScreenHalf { ScreenHalf(side: .right, display: display) }

    /// The work items' ends, in order, as the placer reports them.
    @MainActor private final class Finishes {
        let callback: @Sendable (BundleID, Outcome) -> Void
        private let stream: AsyncStream<(BundleID, Outcome)>
        private var pending: [(BundleID, Outcome)] = []

        init() {
            let (stream, continuation) = AsyncStream<(BundleID, Outcome)>.makeStream()
            self.stream = stream
            callback = { continuation.yield(($0, $1)) }
        }

        func outcome(of app: BundleID) async -> Outcome {
            while true {
                if let found = pending.firstIndex(where: { $0.0 == app }) { return pending.remove(at: found).1 }
                var next: (BundleID, Outcome)?
                for await arrived in stream {
                    next = arrived
                    break
                }
                guard let next else { return .noWindow }
                pending.append(next)
            }
        }
    }

    private func placer(_ calls: ScriptedPlacing, _ finishes: Finishes) -> FrontWindowPlacer {
        FrontWindowPlacer(
            calls: calls, screens: { Self.screens },
            process: { app in
                switch app {
                case Self.safari: 101
                case Self.notes: 102
                case Self.calendar: ProcessInfo.processInfo.processIdentifier
                default: nil
                }
            },
            finished: finishes.callback)
    }

    private func apps() -> [pid_t: ScriptedPlacing.App] {
        [101: .init(windows: [window(rect(260, 390, 800, 332))]), 102: .init(windows: [window(rect(300, 300, 500, 332))])]
    }

    @Test func aHeldAppDelaysNoOtherAppAndANewerPlacingOfItStopsTheOlder() async {
        let calls = ScriptedPlacing(apps())
        let finishes = Finishes()
        let placer = placer(calls, finishes)
        let held = calls.hold("mainWindow", pid: 101)
        var reached = held.reached.makeAsyncIterator()

        #expect(placer.place(Self.safari, in: R(Self.d1)))
        await reached.next()
        #expect(placer.place(Self.notes, in: L(Self.d1)))
        #expect(await finishes.outcome(of: Self.notes) == .placed(rect(0, 33, 756, 949)))
        #expect(calls.frame(pid: 102) == rect(0, 33, 756, 949))

        #expect(placer.place(Self.safari, in: L(Self.d1)))
        held.release()
        #expect(await finishes.outcome(of: Self.safari) == .superseded)
        #expect(await finishes.outcome(of: Self.safari) == .placed(rect(0, 33, 756, 949)))
        #expect(calls.intoApp(101) == ["mainWindow", "mainWindow", "state", "setPosition", "setSize", "size", "state"])
        #expect(calls.frame(pid: 101) == rect(0, 33, 756, 949))
    }

    @Test func aPlacingForADisplayThatIsGoneOrAnAppWithNoProcessOrThisProcessDispatchesNothing() {
        let calls = ScriptedPlacing(apps())
        let placer = placer(calls, Finishes())
        #expect(placer.place(Self.notes, in: L(DisplayID(rawValue: 3))) == false)
        #expect(placer.place(Self.mail, in: L(Self.d1)) == false)
        #expect(placer.place(Self.calendar, in: L(Self.d1)) == false)
        #expect(calls.calls.isEmpty)
    }

    @Test func aWindowIsPlacedOnTheDisplayTheHalfNames() async {
        let calls = ScriptedPlacing(apps())
        let finishes = Finishes()
        let placer = placer(calls, finishes)
        placer.place(Self.notes, in: L(Self.d2))
        _ = await finishes.outcome(of: Self.notes)
        #expect(calls.frame(pid: 102) == rect(1512, -73, 960, 1055))
    }

    @Test func aSecondPlacingIntoTheSameHalfLeavesAnOversizeWindowAloneButAnotherHalfMovesIt() async {
        var wide = window(rect(260, 390, 900, 332), minimumWidth: 900)
        wide.isStandard = true
        let calls = ScriptedPlacing([101: .init(windows: [wide])])
        let finishes = Finishes()
        let placer = placer(calls, finishes)
        let placed: [Write] = [position(756, 33), size(756, 949), position(612, 33)]

        placer.place(Self.safari, in: R(Self.d1))
        _ = await finishes.outcome(of: Self.safari)
        placer.place(Self.safari, in: R(Self.d1))
        #expect(await finishes.outcome(of: Self.safari) == .alreadyThere)
        #expect(calls.writes(101) == placed)

        calls.move(pid: 101, to: rect(100, 200, 900, 949))
        placer.place(Self.safari, in: R(Self.d1))
        _ = await finishes.outcome(of: Self.safari)
        #expect(Array(calls.writes(101).dropFirst(3)) == placed)

        placer.place(Self.safari, in: L(Self.d1))
        _ = await finishes.outcome(of: Self.safari)
        #expect(Array(calls.writes(101).dropFirst(6)) == [position(0, 33), size(756, 949)])
        #expect(calls.frame(pid: 101) == rect(0, 33, 900, 949))
    }

    @Test func aRaiseFollowsThePlacingQueuedBeforeItWithoutStoppingItAndRaisesTheWindowItPlaced() async {
        let calls = ScriptedPlacing([101: .init(windows: [window(rect(50, 50, 500, 400)), window(rect(80, 80, 500, 400))], main: 2)])
        let finishes = Finishes()
        let placer = placer(calls, finishes)
        let held = calls.hold("setSize", pid: 101)
        var reached = held.reached.makeAsyncIterator()

        #expect(placer.place(Self.safari, in: R(Self.d1)))
        await reached.next()
        #expect(placer.raise(Self.safari))
        held.release()

        #expect(await finishes.outcome(of: Self.safari) == .placed(rect(756, 33, 756, 949)))
        #expect(await finishes.outcome(of: Self.safari) == .raised)
        #expect(calls.raised(101) == [2])
        #expect(calls.touched(101) == [2])
        #expect(calls.intoApp(101).suffix(2) == ["mainWindow", "raise"])
    }

    @Test func aRaiseOfAnAppWithNoProcessOrOfThisProcessDispatchesNothingAndGoesOnAtOnce() {
        let calls = ScriptedPlacing(apps())
        let placer = placer(calls, Finishes())
        var wentOn = 0
        #expect(placer.raise(Self.mail) { wentOn += 1 } == false)
        #expect(placer.raise(Self.calendar) { wentOn += 1 } == false)
        #expect(wentOn == 2)
        #expect(calls.calls.isEmpty)
    }

    @Test func whatFollowsARaiseRunsOnTheMainActorOnlyOnceTheRaiseIsIn() async {
        let calls = ScriptedPlacing(apps())
        let placer = placer(calls, Finishes())
        let held = calls.hold("raise", pid: 101)
        var reached = held.reached.makeAsyncIterator()
        let (followed, follow) = AsyncStream<[Int]>.makeStream()

        #expect(placer.raise(Self.safari) { follow.yield(calls.raised(101)) })
        await reached.next()
        #expect(calls.raised(101).isEmpty)
        held.release()

        var raisedWhenFollowed = followed.makeAsyncIterator()
        #expect(await raisedWhenFollowed.next() == [1], "the raise was in before what follows it ran")
    }
}

@Suite struct FrontWindowPlacerRaiseTests {
    private func raise(_ calls: ScriptedPlacing) -> Outcome {
        FrontWindowPlacer.raise(1, budget: freshBudget, calls: calls)
    }

    @Test func withNoMainWindowTheFirstStandardWindowThatIsNotMinimisedIsRaisedAsItWouldBePlaced() {
        var panel = window(rect(50, 50, 500, 400))
        panel.isStandard = false
        var minimised = window(rect(60, 50, 500, 400))
        minimised.isMinimised = true
        let calls = ScriptedPlacing([1: .init(windows: [panel, minimised, window(rect(70, 50, 500, 400))], main: nil)])
        #expect(raise(calls) == .raised)
        #expect(calls.raised() == [3])
        #expect(calls.writes().isEmpty, "a raise moves and resizes nothing")
    }

    @Test func noWindowRaisesNothingAndARaiseThatCannotCompleteIsUnanswered() {
        var minimised = window(rect(50, 50, 500, 400))
        minimised.isMinimised = true
        let none = ScriptedPlacing([1: .init(windows: [minimised], main: nil)])
        #expect(raise(none) == .noWindow)
        #expect(none.raised().isEmpty)

        let hung = ScriptedPlacing(window(rect(50, 50, 500, 400)), script: .init(errors: ["raise": .cannotComplete]))
        #expect(raise(hung) == .unanswered)
        let refused = ScriptedPlacing(window(rect(50, 50, 500, 400)), script: .init(errors: ["raise": .other]))
        #expect(raise(refused) == .refused)
    }

    @Test func everyCallOfARaiseGetsWhatIsLeftOfTheBudget() {
        let calls = ScriptedPlacing(window(rect(50, 50, 500, 400)), script: .init(defaultCost: 100))
        #expect(raise(calls) == .raised)
        expectTimeouts(calls.timeouts(), [0.5, 0.4])

        let slow = ScriptedPlacing(window(rect(50, 50, 500, 400)), script: .init(defaultCost: 600))
        #expect(raise(slow) == .unanswered)
        #expect(slow.raised().isEmpty)
    }
}
