import Foundation
import Testing
import LauncherCore

@Suite struct SwitcherTests {
    private func entry(_ name: String, at directory: String = "/Applications") -> AppEntry {
        AppEntry(
            bundleID: BundleID(rawValue: "com.test.\(name.lowercased())"), name: name,
            url: URL(fileURLWithPath: "\(directory)/\(name).app"))
    }

    private var safari: AppEntry { entry("Safari") }
    private var mail: AppEntry { entry("Mail") }
    private var slack: AppEntry { entry("Slack") }
    private var notes: AppEntry { entry("Notes") }

    private func switcher(frontmost: AppEntry, travel: Double = 0) -> Switcher {
        var switcher = Switcher(
            listed: [mail, slack, notes], frontmost: frontmost, trackpad: Trackpad.macBook14.id)!
        switcher.travelMM = travel
        return switcher
    }

    @Test func theFrontmostAppInTheListKeepsItsPlaceAndStartsSelected() {
        let switcher = switcher(frontmost: slack)
        #expect(switcher.row == [mail, slack, notes])
        #expect(switcher.home == 1)
        #expect(switcher.selected == 1)
        #expect(switcher.selectedApp == slack)
        #expect(switcher.selectsFrontmost)
    }

    @Test func aFrontmostAppOutsideTheListIsShownAtTheLeftEndAndStartsSelected() {
        let switcher = switcher(frontmost: safari)
        #expect(switcher.row == [safari, mail, slack, notes])
        #expect(switcher.home == 0)
        #expect(switcher.selectedApp == safari)
    }

    @Test func identityIsTheBundleIDNotTheLocation() {
        let switcher = switcher(frontmost: entry("Slack", at: "/Users/me/Downloads"))
        #expect(switcher.row == [mail, slack, notes])
        #expect(switcher.home == 1)
    }

    @Test func aRowNeedsAnotherIconBesidesTheFrontmostApp() {
        let trackpad = Trackpad.macBook14.id
        #expect(Switcher(listed: [mail], frontmost: safari, trackpad: trackpad)?.row.count == 2)
        #expect(Switcher(listed: [], frontmost: safari, trackpad: trackpad) == nil)
        #expect(Switcher(listed: [safari], frontmost: safari, trackpad: trackpad) == nil)
    }

    @Test(arguments: [
        (travel: 5.9, selected: 0), (6.0, 1), (6.1, 1), (17.9, 1), (18.0, 2), (24.0, 2), (30.0, 3), (36.0, 3),
        (60.0, 3), (-30.0, 0),
    ])
    func theSelectionIsTheNearestIconAndNeverPassesAnEnd(travel: Double, selected: Int) {
        #expect(switcher(frontmost: safari, travel: travel).selected == selected)
    }

    @Test(arguments: [
        (travel: -5.9, selected: 1), (-6.0, 0), (-6.1, 0), (6.0, 2), (18.0, 2),
    ])
    func theSelectionMovesBackUnderTheSameRule(travel: Double, selected: Int) {
        #expect(switcher(frontmost: slack, travel: travel).selected == selected)
    }

    @Test func theHighlightSitsBetweenIconsInProportionToTheTravel() {
        let half = switcher(frontmost: safari, travel: 5)
        #expect(abs(half.position - 5.0 / 12) < 1e-9)
        #expect(half.stretch == 0)
        #expect(switcher(frontmost: safari, travel: 36).position == 3)
        #expect(switcher(frontmost: safari, travel: -12).position == 0)
    }

    @Test func pushingPastAnEndStretchesTheHighlightButNeverByAFifthOfAnIcon() {
        let near = switcher(frontmost: safari, travel: 48)
        let far = switcher(frontmost: safari, travel: 60)
        #expect(near.position == 3)
        #expect(near.stretch > 0 && near.stretch < 0.2)
        #expect(far.stretch > near.stretch && far.stretch < 0.2)
        #expect(switcher(frontmost: safari, travel: 1000).stretch < 0.2)
        let before = switcher(frontmost: safari, travel: -12)
        #expect(before.stretch < 0 && before.stretch > -0.2)
        #expect(switcher(frontmost: safari, travel: 0).stretch == 0)
        #expect(switcher(frontmost: safari, travel: 36).stretch == 0)
    }
}
