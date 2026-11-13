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

    @Test func thePlusButtonIsAPopUpOverThePickersMenuWithTheFirstAppDisabledAndAPickMakesTheSecondApp() throws {
        let bench = SecondPickerBench(slot: .add, unavailable: bundleID("Notes"))
        let plus = bench.view.plusButton
        #expect(bench.showsPlus)
        #expect(plus.frame.size == CGSize(width: 16, height: 16))
        #expect(plus.toolTip == "Add a second app")
        #expect(plus.accessibilityLabel() == "Add a second app")

        let menu = try bench.plusMenu()

        // The system's pop-up button, as the picker is, so the menu opens over the button rather than below it,
        // with its top item over the button as an unassigned picker's does; no bezel and no chevrons.
        #expect(!plus.pullsDown)
        #expect(!plus.isBordered)
        #expect((plus.cell as? NSPopUpButtonCell)?.arrowPosition == .noArrow)
        #expect(plus.indexOfSelectedItem == 0)
        #expect(titles(menu) == (try firstPickerTitles()))
        #expect(menu.items.allSatisfy { $0.state != .on })
        #expect(menu.autoenablesItems == false)
        for item in menu.items where !item.isSeparatorItem {
            #expect(item.isEnabled == (item.title != "Notes"), "\(item.title)")
            if let entry = item.representedObject as? AppEntry {
                #expect(item.image === bench.menuIcons[entry.url], "\(item.title) shows its icon")
            }
        }

        try bench.pick("Safari", from: menu)

        #expect(bench.chosen == ["Safari"])
        #expect(bench.showsMinusAndPicker)
        #expect(bench.displayItem.title == "Safari")
        PickerBench.expectPlaysPickAnimation(on: bench.pickerButton, icon: bench.icon("Safari"))

        bench.render(.app(.present(bench.entry("Safari"))))
        PickerBench.expectPlaysPickAnimation(on: bench.pickerButton, icon: bench.icon("Safari"))
    }

    @Test func noneChangesNothingFromEitherMenu() throws {
        let add = SecondPickerBench(slot: .add)
        try add.pick("None", from: try add.plusMenu())
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
        try accepted.pick("Other…", from: try accepted.plusMenu())
        #expect(accepted.otherCalls == 1)
        #expect(accepted.showsPlus)
        accepted.otherCompletion?(accepted.entry("Calendar"))
        accepted.layOut()
        #expect(accepted.showsMinusAndPicker)
        #expect(accepted.displayItem.title == "Calendar")
        PickerBench.expectPlaysPickAnimation(on: accepted.pickerButton, icon: accepted.icon("Calendar"))

        let ignored = SecondPickerBench(slot: .add)
        try ignored.pick("Other…", from: try ignored.plusMenu())
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

    /// `button` drawn alone in the light appearance at 2 pixels per point.
    private func drawn(_ button: NSView) throws -> NSBitmapImageRep {
        button.appearance = NSAppearance(named: .aqua)
        let side = Int(button.bounds.width * 2)
        let rep = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        rep.size = button.bounds.size
        button.cacheDisplay(in: button.bounds, to: rep)
        return rep
    }

    /// The colour at a point, measured from the top-left corner, in sRGB.
    private func colour(in rep: NSBitmapImageRep, atPoint x: CGFloat, _ y: CGFloat) throws -> NSColor {
        try #require(rep.colorAt(x: Int(x * 2), y: Int(y * 2))?.usingColorSpace(.sRGB))
    }

    @Test func thePlusAndMinusDrawASixteenPointCircleInTheBadgesFillWithTheSignInTheChevronsColour() throws {
        let bench = SecondPickerBench(slot: .add)
        bench.render(.add)
        let plus = try drawn(bench.view.plusButton)
        bench.render(.app(.present(PickerBenchEntries.safari)))
        let minus = try drawn(bench.view.minusButton)

        for (name, rep) in [("plus", plus), ("minus", minus)] {
            // The circle fills the 16 pt frame: painted at each edge's midpoint, clear in the corners.
            for (x, y) in [(0.5, 8.0), (15.5, 8.0), (8.0, 0.5), (8.0, 15.5)] {
                #expect(try colour(in: rep, atPoint: x, y).alphaComponent > 0.03, "\(name) edge \(x),\(y)")
            }
            for (x, y) in [(0.5, 0.5), (15.5, 0.5), (0.5, 15.5), (15.5, 15.5)] {
                #expect(try colour(in: rep, atPoint: x, y).alphaComponent < 0.01, "\(name) corner \(x),\(y)")
            }
            // The circle's fill, away from the sign: the badge's 8 % black.
            let fill = try colour(in: rep, atPoint: 4, 4)
            #expect(abs(fill.alphaComponent - 0.078) < 0.02, "\(name) fill alpha \(fill.alphaComponent)")
            #expect(fill.redComponent + fill.greenComponent + fill.blueComponent < 0.05, "\(name) fill is black")
            // The sign's middle: the chevrons' label colour, 85 % black.
            let sign = try colour(in: rep, atPoint: 8, 8)
            #expect(abs(sign.alphaComponent - 0.85) < 0.06, "\(name) sign alpha \(sign.alphaComponent)")
            #expect(sign.redComponent + sign.greenComponent + sign.blueComponent < 0.05, "\(name) sign is black")
        }
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
