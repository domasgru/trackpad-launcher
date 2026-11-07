import CoreGraphics
import LauncherCore
import Testing

@testable import LauncherPlatform

/// The facts `probe_fixture` recorded for an app with two document windows, a minimised one, a palette and a plain
/// panel, hidden and shown.
@Suite struct HiddenAppWindowSortTests {
    private static func raw(
        _ number: UInt32, _ title: String, subrole: String, minimised: Bool = false, fullScreen: Bool = false,
        fullScreenButton: Bool
    ) -> RawWindow {
        RawWindow(
            number: number, title: title, role: "AXWindow", subrole: subrole, isMinimised: minimised,
            isFullScreen: fullScreen, frame: nil, hasFullScreenButton: fullScreenButton)
    }

    private static let hidden = [
        raw(64806, "Utility", subrole: "AXFloatingWindow", fullScreenButton: false),
        raw(64807, "PlainPanel", subrole: "AXDialog", fullScreenButton: false),
        raw(64804, "W2", subrole: "AXDialog", fullScreenButton: true),
        raw(64803, "W1", subrole: "AXDialog", fullScreenButton: true),
        raw(64805, "W3", subrole: "AXDialog", minimised: true, fullScreenButton: true),
    ]

    private static let shown = [
        raw(64806, "Utility", subrole: "AXFloatingWindow", fullScreenButton: false),
        raw(64807, "PlainPanel", subrole: "AXDialog", fullScreenButton: false),
        raw(64804, "W2", subrole: "AXStandardWindow", fullScreenButton: true),
        raw(64803, "W1", subrole: "AXStandardWindow", fullScreenButton: true),
        raw(64805, "W3", subrole: "AXDialog", minimised: true, fullScreenButton: true),
    ]

    private func titles(_ windows: [AppWindow]) -> [String] { windows.map(\.title) }

    @Test func aHiddenAppsDocumentWindowsAreListedInTheAppsOrderAndItsPanelsAreNot() {
        let sorted = AppWindowReader.sort(Self.hidden, onScreen: [], appIsHidden: true)

        #expect(titles(sorted.visible) == ["W2", "W1"])
        #expect(titles(sorted.minimised) == ["W3"])
    }

    @Test func theHiddenCountIsTheCountTheShownAppHas() {
        let hidden = AppWindowReader.sort(Self.hidden, onScreen: [], appIsHidden: true)
        let shown = AppWindowReader.sort(Self.shown, onScreen: [64807, 64804, 64803], appIsHidden: false)

        #expect(hidden.visible.count + hidden.minimised.count == 3)
        #expect(shown.visible.count + shown.minimised.count == 3)
        #expect(titles(shown.visible) == ["W2", "W1"])
        #expect(titles(shown.minimised) == ["W3"])
    }

    @Test func aHiddenAppsFullScreenWindowIsLeftOut() {
        let windows = Self.hidden + [Self.raw(64900, "Movie", subrole: "AXDialog", fullScreen: true, fullScreenButton: true)]
        let sorted = AppWindowReader.sort(windows, onScreen: [], appIsHidden: true)

        #expect(titles(sorted.visible) == ["W2", "W1"])
    }

    @Test func aHiddenAppsWindowWithNoNumberIsLeftOut() {
        let lost = RawWindow(
            number: nil, title: "Lost", role: "AXWindow", subrole: "AXDialog", isMinimised: false, isFullScreen: false,
            frame: nil, hasFullScreenButton: true)
        #expect(AppWindowReader.sort([lost], onScreen: [], appIsHidden: true).visible.isEmpty)
    }
}
