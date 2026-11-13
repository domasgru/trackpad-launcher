import AppKit
@testable import LauncherCore
import Testing
@testable import LauncherUI

@MainActor @Suite struct SecondAppPickerTests {
    private func bundleID(_ name: String) -> BundleID { BundleID(rawValue: "com.test.\(name.lowercased())") }

    private func colour(of item: NSMenuItem) -> NSColor? {
        item.attributedTitle?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
    }

    private func titles(_ menu: NSMenu) -> [String] { menu.items.map(\.title) }

    private func firstPickerTitles() throws -> [String] {
        let bench = PickerBench(showing: nil)
        let menu = try #require(bench.view.menu)
        bench.coordinator.menuNeedsUpdate(menu)
        return titles(menu)
    }

    @Test func thePlusButtonOpensThePickersMenuWithTheFirstAppDisabledAndAPickMakesTheSecondApp() throws {
        let bench = SecondPickerBench(slot: .add, unavailable: bundleID("Notes"))
        let plus = bench.view.plusButton
        #expect(bench.showsPlus)
        #expect(plus.frame.size == CGSize(width: 16, height: 16))
        #expect(plus.toolTip == "Add a second app")
        #expect(plus.accessibilityLabel() == "Add a second app")

        bench.pressPlus()

        let popped = try #require(bench.poppedUp.first)
        #expect(bench.poppedUp.count == 1)
        #expect(popped.button === plus)
        #expect(titles(popped.menu) == (try firstPickerTitles()))
        #expect(popped.menu.items.allSatisfy { $0.state != .on })
        #expect(popped.menu.autoenablesItems == false)
        for item in popped.menu.items where !item.isSeparatorItem {
            #expect(item.isEnabled == (item.title != "Notes"), "\(item.title)")
        }

        try bench.pick("Safari", from: popped.menu)

        #expect(bench.chosen == ["Safari"])
        #expect(bench.showsMinusAndPicker)
        #expect(bench.displayItem.title == "Safari")
        PickerBench.expectPlaysPickAnimation(on: bench.pickerButton, icon: bench.icon("Safari"))

        bench.render(.app(.present(bench.entry("Safari"))))
        PickerBench.expectPlaysPickAnimation(on: bench.pickerButton, icon: bench.icon("Safari"))
    }

    @Test func noneChangesNothingFromEitherMenu() throws {
        let add = SecondPickerBench(slot: .add)
        add.pressPlus()
        try add.pick("None", from: try #require(add.poppedUp.first).menu)
        #expect(add.chosen.isEmpty && add.removed == 0 && add.otherCalls == 0)
        #expect(add.showsPlus)
        #expect(add.noLayerAnimates)

        let split = SecondPickerBench(slot: .app(.present(PickerBenchEntries.safari)))
        try split.pickFromPicker("None")
        #expect(split.chosen.isEmpty && split.removed == 0 && split.otherCalls == 0)
        #expect(split.showsMinusAndPicker)
        #expect(split.displayItem.title == "Safari")
        #expect(split.noLayerAnimates)
    }

    @Test func otherFromThePlusMenuShowsAndPlaysOnlyWhenTheModelAcceptsTheApp() throws {
        let accepted = SecondPickerBench(slot: .add)
        accepted.pressPlus()
        try accepted.pick("Other…", from: try #require(accepted.poppedUp.first).menu)
        #expect(accepted.otherCalls == 1)
        #expect(accepted.showsPlus)
        accepted.otherCompletion?(accepted.entry("Calendar"))
        accepted.layOut()
        #expect(accepted.showsMinusAndPicker)
        #expect(accepted.displayItem.title == "Calendar")
        PickerBench.expectPlaysPickAnimation(on: accepted.pickerButton, icon: accepted.icon("Calendar"))

        let ignored = SecondPickerBench(slot: .add)
        ignored.pressPlus()
        try ignored.pick("Other…", from: try #require(ignored.poppedUp.first).menu)
        ignored.otherCompletion?(nil)
        #expect(ignored.showsPlus)
        #expect(ignored.noLayerAnimates)
    }

    @Test func theSecondPickerListsWhatTheFirstListsAndPicksReplaceTheSecondApp() throws {
        let bench = SecondPickerBench(slot: .app(.present(PickerBenchEntries.safari)), unavailable: bundleID("Notes"))
        let menu = try #require(bench.pickerButton.menu)
        bench.coordinator.menuNeedsUpdate(menu)
        #expect(titles(menu) == (try firstPickerTitles()))
        #expect(menu.items.first { $0.title == "Safari" }?.state == .on)
        #expect(menu.items.first { $0.title == "Notes" }?.isEnabled == false)
        #expect(menu.items.first { $0.title == "Mail" }?.isEnabled == true)

        try bench.pickFromPicker("Mail")

        #expect(bench.chosen == ["Mail"])
        #expect(bench.displayItem.title == "Mail")
        PickerBench.expectPlaysPickAnimation(on: bench.pickerButton, icon: bench.icon("Mail"))
    }

    @Test func theMinusButtonRemovesTheSecondAppAndTheSlotShowsThePlusAtOnce() {
        let bench = SecondPickerBench(slot: .app(.present(PickerBenchEntries.safari)))
        let minus = bench.view.minusButton
        #expect(bench.showsMinusAndPicker)
        #expect(minus.frame.size == CGSize(width: 16, height: 16))
        #expect(minus.frame.maxX <= bench.pickerButton.frame.minX)
        #expect(minus.toolTip == "Remove the second app")
        #expect(minus.accessibilityLabel() == "Remove the second app")

        bench.pressMinus()

        #expect(bench.removed == 1)
        #expect(bench.showsPlus)
        bench.render(.add)
        #expect(bench.showsPlus)
        #expect(bench.noLayerAnimates)
        #expect(Copy.addSecondApp == "Add a second app")
        #expect(Copy.removeSecondApp == "Remove the second app")
    }

    @Test func rendersNeverAnimateAndAMissingAppShowsGreyedByItsName() {
        let long = String(repeating: "W", count: 40)
        let bench = SecondPickerBench(slot: .add, longName: long)
        let safari = bench.entry("Safari")
        let missing = SecondSlot.app(.missing(name: "Safari", bundleID: bundleID("Safari")))
        let first = PickerBench(showing: nil)
        first.render(.missing(name: "Safari"))
        let firstMissing = (
            item: first.displayItem, colour: colour(of: first.displayItem), toolTip: first.view.toolTip,
            iconHidden: first.view.iconLayer.isHidden
        )
        #expect(firstMissing.colour != nil)
        #expect(firstMissing.iconHidden)

        for slot in [SecondSlot.add, .app(.present(safari)), missing, .app(.present(safari))] {
            bench.clearAnimations()
            bench.render(slot)
            #expect(bench.noLayerAnimates)
            if case .app(.missing) = slot {
                let item = bench.displayItem
                #expect(item.title == firstMissing.item.title)
                #expect(colour(of: item) == firstMissing.colour)
                #expect(bench.pickerButton.toolTip == firstMissing.toolTip)
                #expect(bench.pickerButton.iconLayer.isHidden == firstMissing.iconHidden)
            }
        }

        bench.clearAnimations()
        bench.render(.app(.present(bench.entry(long))))
        #expect(bench.noLayerAnimates)
        #expect(bench.pickerButton.frame.width <= AppPicker.maxWidth)
        #expect(bench.displayItem.title.hasSuffix("…"))
    }
}

/// Entries named as `SecondPickerBench` names them, for a slot built before the bench exists.
enum PickerBenchEntries {
    static let safari = AppEntry(
        bundleID: BundleID(rawValue: "com.test.safari"), name: "Safari", url: URL(filePath: "/Applications/Safari.app"))
}
