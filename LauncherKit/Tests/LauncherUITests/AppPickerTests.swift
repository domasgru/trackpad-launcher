import AppKit
@testable import LauncherCore
import Testing
@testable import LauncherUI

@Suite struct AppPickerTests {
    @Test func pickingFromTheMenuPlaysThePickAnimationOnTheNewIcon() {
        let bench = PickerBench(showing: "Safari")

        bench.pick("Mail")

        #expect(bench.chosen == ["Mail"])
        #expect(bench.displayItem.title == "Mail")
        let image = bench.displayItem.image
        #expect(image?.size == NSSize(width: 20, height: 16))
        #expect(image !== bench.icon("Mail"))
        bench.expectPlaysPickAnimation(of: "Mail")
    }

    @Test func otherPlaysOnlyWhenTheModelAcceptsTheChosenApp() throws {
        let bench = PickerBench(showing: "Safari")

        bench.pick("Other…")
        #expect(bench.otherCalls == 1)
        #expect(bench.displayItem.title == "Safari")
        #expect(bench.noLayerAnimates)

        let completion = try #require(bench.otherCompletion)
        completion(bench.entry("Calendar"))
        #expect(bench.displayItem.title == "Calendar")
        bench.expectPlaysPickAnimation(of: "Calendar")
    }

    @Test func aCancelledOtherLeavesTheIconAlone() throws {
        let bench = PickerBench(showing: "Safari")

        bench.pick("Other…")
        #expect(bench.otherCalls == 1)
        _ = try #require(bench.otherCompletion)

        #expect(bench.displayItem.title == "Safari")
        #expect(bench.iconLayerContents === bench.icon("Safari"))
        #expect(bench.noLayerAnimates)
    }

    @Test func anOtherPickTheModelIgnoresChangesNothing() throws {
        let bench = PickerBench(showing: "Safari")

        bench.pick("Other…")
        #expect(bench.otherCalls == 1)
        let completion = try #require(bench.otherCompletion)
        completion(nil)

        #expect(bench.displayItem.title == "Safari")
        #expect(bench.iconLayerContents === bench.icon("Safari"))
        #expect(bench.noLayerAnimates)
    }

    @Test func aFirstAssignmentGrowsTheIconWhileTheNameAndChevronAreAlreadyInPlace() {
        let bench = PickerBench(showing: nil)
        #expect(bench.view.iconLayer.isHidden)

        bench.pick("Calendar")

        #expect(bench.displayItem.title == "Calendar")
        bench.expectPlaysPickAnimation(of: "Calendar")

        let settled = PickerBench(showing: "Calendar")
        #expect(bench.view.frame == settled.view.frame)
        #expect(bench.view.intrinsicContentSize == settled.view.intrinsicContentSize)
        #expect(bench.view.iconLayer.position == settled.view.iconLayer.position)
        #expect(bench.view.iconLayer.bounds == settled.view.iconLayer.bounds)
    }

    @Test func theIconSitsOnTheLeadingSquareOfTheButtonsImageSlot() throws {
        let bench = PickerBench(showing: "Safari")
        let layer = bench.view.iconLayer
        let slot = (bench.view.cell as! NSPopUpButtonCell).imageRect(forBounds: bench.view.bounds)
        // The icon's view fills the button and is flipped like it, so the layer's coordinates are the button's.
        let iconView = try #require(bench.view.subviews.last)
        #expect(iconView.frame == bench.view.bounds && iconView.isFlipped == bench.view.isFlipped)

        #expect(layer.bounds.size == CGSize(width: 16, height: 16))
        #expect(layer.position == CGPoint(x: slot.minX + 8, y: slot.midY))
    }

    @Test func pickingTheAppAlreadyShownPlaysItAgain() {
        let bench = PickerBench(showing: "Finder")
        bench.pick("Finder")
        bench.clearAnimations()

        bench.pick("Finder")

        #expect(bench.chosen == ["Finder", "Finder"])
        bench.expectPlaysPickAnimation(of: "Finder")
    }

    @Test func pickingNoneShowsChooseAppAtOnceWithoutAnimation() {
        let bench = PickerBench(showing: "Notes")

        bench.pick("None")

        #expect(bench.chosen == [nil])
        #expect(bench.displayItem.title == "Choose app…")
        #expect(bench.view.iconLayer.isHidden)
        #expect(bench.noLayerAnimates)
    }

    @Test func pickingNoneRunsOnlyChooseNone() {
        let bench = PickerBench(showing: "Notes")

        bench.pick("None")

        #expect(bench.noneCalls == 1)
        #expect(bench.chooseCalls == 0)
        #expect(bench.displayItem.title == "Choose app…")
        #expect(bench.view.iconLayer.isHidden)
        #expect(bench.noLayerAnimates)
    }

    @Test func withoutChooseNoneNoneIsInert() {
        let bench = PickerBench(showing: "Notes", hasNone: false)

        bench.pick("None")

        #expect(bench.noneCalls == 0)
        #expect(bench.chooseCalls == 0)
        #expect(bench.displayItem.title == "Notes")
        #expect(bench.iconLayerContents === bench.icon("Notes"))
        #expect(bench.noLayerAnimates)
    }

    @Test func theUnavailableAppsItemIsDisabledAndTheCurrentOneIsOn() {
        let bench = PickerBench(showing: "Notes", unavailable: BundleID(rawValue: "com.test.mail"))
        let menu = bench.view.menu!
        bench.coordinator.menuNeedsUpdate(menu)

        #expect(menu.items.first { $0.title == "Mail" }?.isEnabled == false)
        #expect(menu.items.first { $0.title == "Notes" }?.state == .on)
        #expect(menu.items.first { $0.title == "Notes" }?.isEnabled == true)
    }

    @Test func rendersNeverAnimateTheIcon() {
        let bench = PickerBench(showing: "Safari")
        bench.clearAnimations()

        bench.render(.present(bench.entry("Mail")))
        #expect(bench.iconLayerContents === bench.icon("Mail"))
        #expect(bench.noLayerAnimates)

        bench.render(.missing(name: "Mail"))
        #expect(bench.view.iconLayer.isHidden)
        #expect(bench.noLayerAnimates)

        bench.render(.present(bench.entry("Mail")))
        #expect(!bench.view.iconLayer.isHidden)
        #expect(bench.iconLayerContents === bench.icon("Mail"))
        #expect(bench.noLayerAnimates)

        bench.render(.present(bench.entry("Safari")))
        #expect(bench.iconLayerContents === bench.icon("Safari"))
        #expect(bench.noLayerAnimates)

        let scanned = InstalledApps(recent: [bench.entry("Safari")], others: [bench.entry("Mail")])
        bench.render(.present(bench.entry("Safari")), installed: scanned)
        #expect(bench.iconLayerContents === bench.icon("Safari"))
        #expect(bench.noLayerAnimates)
    }

    @Test func aQuickSecondPickReplacesTheIconAndPlaysFromTheStart() {
        let bench = PickerBench(showing: "Safari")
        bench.pick("Mail")
        bench.expectPlaysPickAnimation(of: "Mail")

        bench.pick("Music")

        bench.expectPlaysPickAnimation(of: "Music")
    }

    @Test func withoutAnAnimationAPickSwapsTheIconAtOnce() throws {
        let menu = PickerBench(showing: "Safari", animation: nil)
        menu.pick("Mail")
        #expect(menu.displayItem.title == "Mail")
        #expect(menu.iconLayerContents === menu.icon("Mail"))
        #expect(menu.noLayerAnimates)

        let other = PickerBench(showing: "Safari", animation: nil)
        other.pick("Other…")
        #expect(other.otherCalls == 1)
        let completion = try #require(other.otherCompletion)
        completion(other.entry("Calendar"))
        #expect(other.displayItem.title == "Calendar")
        #expect(other.iconLayerContents === other.icon("Calendar"))
        #expect(other.noLayerAnimates)
    }

    @Test func aPickWithoutAnimationCutsShortOneStillPlaying() {
        let bench = PickerBench(showing: "Safari")
        bench.pick("Mail")
        bench.animation = nil

        bench.pick("Music")

        #expect(bench.iconLayerContents === bench.icon("Music"))
        #expect(bench.noLayerAnimates)
    }

    @Test func theIconLayerNeverClipsOrAnimatesOnItsOwn() {
        let bench = PickerBench(showing: "Safari")

        #expect(bench.view.layer?.masksToBounds ?? false == false)
        #expect(bench.view.iconLayer.superlayer?.masksToBounds == false)
        #expect(bench.view.iconLayer.masksToBounds == false)
        #expect(bench.view.clipsToBounds == false)
        #expect(bench.view.subviews.last?.clipsToBounds == false)
        #expect(bench.view.iconLayer.action(forKey: "contents") == nil)
        #expect(bench.view.iconLayer.action(forKey: "position") == nil)
        #expect(bench.view.iconLayer.action(forKey: "hidden") == nil)
    }
}
