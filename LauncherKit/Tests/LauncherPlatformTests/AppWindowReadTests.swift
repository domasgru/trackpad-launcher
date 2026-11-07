import CoreGraphics
import LauncherCore
import Synchronization
import Testing

@testable import LauncherPlatform

/// The read's calls into one app, scripted: each call into the app costs time on the double's own clock, answers as
/// scripted, and is recorded with the timeout the read set before it. Elements are 0 for the app and 1... for windows.
final class ScriptedCalls: WindowCalls {
    struct Window: Sendable {
        var raw: RawWindow
        var attributes: Result<RawWindow, WindowCallError>?
        var number: Result<UInt32, WindowCallError>
        init(_ raw: RawWindow, number: Result<UInt32, WindowCallError>? = nil) {
            self.raw = raw
            self.number = number ?? .success(raw.number ?? 0)
        }
    }

    struct Script: Sendable {
        var windows: [Window] = []
        var windowsResult: WindowCallError?
        var onScreen: [UInt32] = []
        var listed: [ListedWindow] = []
        /// Milliseconds each call into the app takes.
        var windowsCost = 50
        var attributesCost = 50
        var numberCost = 50
    }

    struct Record: Sendable {
        var elapsed = 0
        var timeouts: [Float] = []
        var intoApp: [String] = []
        var listedCalls = 0
    }

    private let script: Script
    private let record = Mutex(Record())

    init(_ script: Script) { self.script = script }

    var timeouts: [Float] { record.withLock { $0.timeouts } }
    var intoApp: [String] { record.withLock { $0.intoApp } }
    var listedCalls: Int { record.withLock { $0.listedCalls } }

    func now() -> Uptime { Uptime(seconds: Double(record.withLock { $0.elapsed }) / 1000) }

    func setTimeout(_ seconds: Float, on element: Int) { record.withLock { $0.timeouts.append(seconds) } }

    func appElement(_ pid: pid_t) -> Int { 0 }

    private func spend(_ name: String, _ milliseconds: Int) {
        record.withLock {
            $0.intoApp.append(name)
            $0.elapsed += milliseconds
        }
    }

    func windows(of app: Int) -> Result<[Int], WindowCallError> {
        spend("windows", script.windowsCost)
        if let error = script.windowsResult { return .failure(error) }
        return .success(script.windows.indices.map { $0 + 1 })
    }

    func attributes(of window: Int) -> Result<RawWindow, WindowCallError> {
        spend("attributes", script.attributesCost)
        let scripted = script.windows[window - 1]
        var raw = scripted.raw
        raw.number = nil
        return scripted.attributes ?? .success(raw)
    }

    func number(of window: Int) -> Result<UInt32, WindowCallError> {
        spend("number", script.numberCost)
        return script.windows[window - 1].number
    }

    func onScreenNumbers(of pid: pid_t) -> [UInt32] { script.onScreen }

    func listedWindows(of pid: pid_t) -> [ListedWindow] {
        record.withLock { $0.listedCalls += 1 }
        return script.listed
    }
}

@Suite struct AppWindowReadTests {
    private static let frame = CGRect(x: 10, y: 20, width: 600, height: 400)

    private static func window(_ number: UInt32, _ title: String) -> ScriptedCalls.Window {
        ScriptedCalls.Window(
            RawWindow(
                number: number, title: title, role: "AXWindow", subrole: "AXStandardWindow", isMinimised: false,
                isFullScreen: false, frame: CGRect(x: Double(number), y: 0, width: 600, height: 400)))
    }

    private static func read(_ script: ScriptedCalls.Script) -> (
        read: WindowRead, elements: [WindowID: Int], calls: ScriptedCalls
    ) {
        let calls = ScriptedCalls(script)
        let budget = ReadBudget(from: calls.now(), within: .milliseconds(200))
        let (read, elements) = AppWindowReader.read(AppWindowReader.Target(pid: 1), budget: budget, calls: calls)
        return (read, elements, calls)
    }

    private static func titles(_ read: WindowRead) -> [String]? {
        if case .windows(let windows) = read { windows.visible.map(\.title) } else { nil }
    }

    private func close(_ timeouts: [Float], to expected: [Float]) -> Bool {
        timeouts.count == expected.count && zip(timeouts, expected).allSatisfy { abs($0 - $1) < 0.0001 }
    }

    @Test func callsOfFiftyMillisecondsEachLeaveTheNextOneWhatIsLeft() {
        let one = Self.read(.init(windows: [Self.window(7, "A")], onScreen: [7]))

        #expect(close(one.calls.timeouts, to: [0.2, 0.15, 0.1]))
        #expect(Self.titles(one.read) == ["A"])
    }

    @Test func aReadThatRunsOutOfTimeMakesNoFurtherCallAndIsUnanswered() {
        let two = Self.read(.init(windows: [Self.window(7, "A"), Self.window(8, "B")], onScreen: [7, 8]))

        #expect(close(two.calls.timeouts, to: [0.2, 0.15, 0.1, 0.05]))
        #expect(two.calls.intoApp == ["windows", "attributes", "number", "attributes"])
        #expect(two.read == .unanswered)
        #expect(two.elements.isEmpty)
    }

    @Test func aWindowListThatAnswersAfterTheDeadlineIsUnansweredAndNothingMoreIsAsked() {
        let late = Self.read(.init(windows: [Self.window(7, "A")], onScreen: [7], windowsCost: 210))

        #expect(late.read == .unanswered)
        #expect(late.calls.intoApp == ["windows"])
    }

    @Test func aReadThatEndsPastTheDeadlineIsUnansweredWhateverItFound() {
        let late = Self.read(.init(windows: [], windowsCost: 201))

        #expect(late.read == .unanswered)
    }

    @Test func noValueForTheWindowsIsNoWindows() {
        let none = Self.read(.init(windowsResult: .noValue))

        #expect(none.read == .windows(AppWindows(visible: [], minimised: [])))
    }

    @Test(arguments: [WindowCallError.cannotComplete, .other])
    func aWindowsCallThatFailsOtherwiseIsUnanswered(_ error: WindowCallError) {
        #expect(Self.read(.init(windowsResult: error)).read == .unanswered)
    }

    @Test func aWindowThatCannotCompleteItsAttributesMakesTheWholeReadUnansweredAndDropsTheFirstWindowToo() {
        var second = Self.window(8, "B")
        second.attributes = .failure(.cannotComplete)

        let read = Self.read(.init(windows: [Self.window(7, "A"), second], onScreen: [7, 8], attributesCost: 1, numberCost: 1))

        #expect(read.read == .unanswered)
        #expect(read.elements.isEmpty)
    }

    @Test func aWindowThatCannotCompleteItsNumberMakesTheWholeReadUnanswered() {
        var second = Self.window(8, "B")
        second.number = .failure(.cannotComplete)

        let read = Self.read(.init(windows: [Self.window(7, "A"), second], onScreen: [7, 8], attributesCost: 1, numberCost: 1))

        #expect(read.read == .unanswered)
    }

    @Test func aWindowWhoseAttributesFailOtherwiseIsLeftOutAndTheOthersAreListed() {
        var second = Self.window(8, "B")
        second.attributes = .failure(.other)

        let read = Self.read(.init(windows: [Self.window(7, "A"), second, Self.window(9, "C")], onScreen: [9, 8, 7], attributesCost: 1, numberCost: 1))

        #expect(Self.titles(read.read) == ["C", "A"])
    }

    @Test func aNumberThatFailsOtherwiseIsTakenFromTheListedWindowWithTheSameFrame() {
        var second = Self.window(8, "B")
        second.number = .failure(.other)
        let listed = [ListedWindow(number: 4242, frame: second.raw.frame!, name: "B")]

        let read = Self.read(
            .init(windows: [Self.window(7, "A"), second], onScreen: [4242, 7], listed: listed, attributesCost: 1, numberCost: 1))

        #expect(Self.titles(read.read) == ["B", "A"])
        #expect(read.elements[WindowID(rawValue: 4242)] == 2)
        #expect(read.calls.listedCalls == 1)
    }

    @Test func aNumberThatFailsOtherwiseAndMatchesNothingLeavesTheWindowOut() {
        var second = Self.window(8, "B")
        second.number = .failure(.other)

        let read = Self.read(
            .init(windows: [Self.window(7, "A"), second], onScreen: [8, 7], attributesCost: 1, numberCost: 1))

        #expect(Self.titles(read.read) == ["A"])
    }

    @Test func theReturnedElementsAreExactlyTheListedWindows() {
        var helper = Self.window(9, "Palette")
        helper.raw = RawWindow(
            number: 9, title: "Palette", role: "AXWindow", subrole: "AXFloatingWindow", isMinimised: false,
            isFullScreen: false, frame: helper.raw.frame)
        let read = Self.read(
            .init(windows: [Self.window(7, "A"), helper, Self.window(8, "B")], onScreen: [8, 9, 7], attributesCost: 1, numberCost: 1))

        #expect(Self.titles(read.read) == ["B", "A"])
        #expect(read.elements == [WindowID(rawValue: 8): 3, WindowID(rawValue: 7): 1])
    }
}
