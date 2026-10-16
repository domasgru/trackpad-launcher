import CoreGraphics
import LauncherCore
import Testing

@testable import LauncherPlatform

/// Raw facts as the window probes recorded them for TextEdit with Alpha, Beta and Gamma open.
@Suite struct FrontmostAppWindowsSortTests {
    private static let size = CGSize(width: 656, height: 422)

    private static func standard(_ number: UInt32?, _ title: String, minimised: Bool = false, fullScreen: Bool = false)
        -> RawWindow
    {
        RawWindow(
            number: number, title: title, role: "AXWindow", subrole: minimised ? "AXDialog" : "AXStandardWindow",
            isMinimised: minimised, isFullScreen: fullScreen, frame: CGRect(origin: .zero, size: size))
    }

    private static let gamma = standard(6863, "Gamma.txt")
    private static let beta = standard(6864, "Beta.txt", minimised: true)
    private static let alpha = standard(6865, "Alpha.txt")

    private func titles(_ windows: [AppWindow]) -> [String] { windows.map(\.title) }

    @Test func visibleWindowsFollowTheWindowListAndAMinimisedOneComesAfterThemDespiteItsDialogSubrole() {
        let sorted = FrontmostAppWindows.sort([Self.gamma, Self.alpha, Self.beta], onScreen: [6863, 6865])
        #expect(titles(sorted.visible) == ["Gamma.txt", "Alpha.txt"])
        #expect(sorted.visible.map(\.id) == [WindowID(rawValue: 6863), WindowID(rawValue: 6865)])
        #expect(titles(sorted.minimised) == ["Beta.txt"])
    }

    @Test func theWindowListDecidesTheVisibleOrderWhateverTheElementOrder() {
        let sorted = FrontmostAppWindows.sort([Self.alpha, Self.beta, Self.gamma], onScreen: [6863, 6865])
        #expect(titles(sorted.visible) == ["Gamma.txt", "Alpha.txt"])
        #expect(titles(sorted.minimised) == ["Beta.txt"])
    }

    @Test func onAFullScreenSpaceOnlyTheFullScreenWindowIsListedAndItSaysSo() {
        let helper = RawWindow(
            number: 6903, title: "", role: "AXWindow", subrole: "AXUnknown", isMinimised: false, isFullScreen: false,
            frame: nil)
        let beta = Self.standard(6895, "Beta.txt", fullScreen: true)
        let sorted = FrontmostAppWindows.sort([helper, beta], onScreen: [6903, 6895])
        #expect(sorted.visible == [AppWindow(id: WindowID(rawValue: 6895), title: "Beta.txt", isFullScreen: true)])
        #expect(sorted.minimised.isEmpty)
    }

    @Test(arguments: ["AXFloatingWindow", "AXSystemFloatingWindow", "AXDialog"])
    func panelsPalettesAndDialogsOnScreenAreLeftOut(subrole: String) {
        let helper = RawWindow(
            number: 7000, title: "Fonts", role: "AXWindow", subrole: subrole, isMinimised: false, isFullScreen: false,
            frame: nil)
        let sorted = FrontmostAppWindows.sort([Self.gamma, helper], onScreen: [7000, 6863])
        #expect(titles(sorted.visible) == ["Gamma.txt"])
        #expect(sorted.minimised.isEmpty)
    }

    @Test func aStandardWindowNeitherOnScreenNorMinimisedIsOnAnotherSpaceAndLeftOut() {
        let sorted = FrontmostAppWindows.sort([Self.gamma, Self.alpha], onScreen: [6863])
        #expect(titles(sorted.visible) == ["Gamma.txt"])
    }

    @Test func aWindowWithNoNumberIsLeftOut() {
        let sorted = FrontmostAppWindows.sort(
            [Self.standard(nil, "Lost"), Self.standard(nil, "Lost too", minimised: true), Self.gamma],
            onScreen: [6863])
        #expect(titles(sorted.visible) == ["Gamma.txt"])
        #expect(sorted.minimised.isEmpty)
    }

    @Test func minimisedWindowsKeepTheAppsOrder() {
        let first = Self.standard(1, "First", minimised: true)
        let second = Self.standard(2, "Second", minimised: true)
        #expect(titles(FrontmostAppWindows.sort([first, second], onScreen: []).minimised) == ["First", "Second"])
        #expect(titles(FrontmostAppWindows.sort([second, first], onScreen: []).minimised) == ["Second", "First"])
    }
}

/// Probe 2's window list: Gamma at (210, 131), Beta at (181, 102), Alpha at (152, 73), each 656 × 422.
@Suite struct FrontmostAppWindowsNumberTests {
    private static let size = CGSize(width: 656, height: 422)
    private static let alphaFrame = CGRect(origin: CGPoint(x: 152, y: 73), size: size)

    private static func listed(named: Bool) -> [ListedWindow] {
        [
            ListedWindow(number: 6863, frame: CGRect(origin: CGPoint(x: 210, y: 131), size: size),
                         name: named ? "Gamma.txt" : nil),
            ListedWindow(number: 6864, frame: CGRect(origin: CGPoint(x: 181, y: 102), size: size),
                         name: named ? "Beta.txt" : nil),
            ListedWindow(number: 6865, frame: alphaFrame, name: named ? "Alpha.txt" : nil),
        ]
    }

    private static func alpha(frame: CGRect? = alphaFrame) -> RawWindow {
        RawWindow(
            number: nil, title: "Alpha.txt", role: "AXWindow", subrole: "AXStandardWindow", isMinimised: false,
            isFullScreen: false, frame: frame)
    }

    @Test func aWindowMatchesTheListedWindowWithItsFrameAndTitle() {
        #expect(FrontmostAppWindows.number(of: Self.alpha(), among: Self.listed(named: true)) == 6865)
    }

    @Test func withoutNamesTheFrameAloneDecides() {
        #expect(FrontmostAppWindows.number(of: Self.alpha(), among: Self.listed(named: false)) == 6865)
    }

    @Test func twoUnnamedWindowsAtTheSameFrameMatchNeither() {
        let twins = [
            ListedWindow(number: 1, frame: Self.alphaFrame, name: nil),
            ListedWindow(number: 2, frame: Self.alphaFrame, name: nil),
        ]
        #expect(FrontmostAppWindows.number(of: Self.alpha(), among: twins) == nil)
    }

    @Test func aNameTellsTwoWindowsAtTheSameFrameApart() {
        let twins = [
            ListedWindow(number: 6865, frame: Self.alphaFrame, name: "Alpha.txt"),
            ListedWindow(number: 7000, frame: Self.alphaFrame, name: "Other"),
        ]
        #expect(FrontmostAppWindows.number(of: Self.alpha(), among: twins) == 6865)
    }

    @Test func aWindowWithNoListedFrameOrNoFrameMatchesNothing() {
        let moved = CGRect(origin: CGPoint(x: 400, y: 300), size: Self.size)
        #expect(FrontmostAppWindows.number(of: Self.alpha(frame: moved), among: Self.listed(named: true)) == nil)
        #expect(FrontmostAppWindows.number(of: Self.alpha(frame: nil), among: Self.listed(named: true)) == nil)
    }
}
