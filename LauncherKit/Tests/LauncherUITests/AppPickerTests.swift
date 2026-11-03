import AppKit
@testable import LauncherCore
import Testing
@testable import LauncherUI

@Suite struct AppPickerTests {
    @Test func pickingFromTheMenuPlaysThePickAnimationOnTheNewIcon() {
        let bench = PickerBench(showing: "Safari")

        bench.pick("Mail")

        #expect(bench.chosen == ["Mail"])
        #expect(bench.closedItem.title == "Mail")
        let image = bench.closedItem.image
        #expect(image?.size == NSSize(width: 17, height: 16))
        #expect(image !== bench.icon("Mail"))
        bench.expectPlaysPickAnimation(of: "Mail")
    }

    @Test func otherPlaysOnlyWhenTheModelAcceptsTheChosenApp() {
        let bench = PickerBench(showing: "Safari")

        bench.pick("Other…")
        #expect(bench.otherCalls == 1)
        #expect(bench.closedItem.title == "Safari")
        #expect(bench.noLayerAnimates)

        bench.otherCompletion?(bench.entry("Calendar"))
        #expect(bench.closedItem.title == "Calendar")
        bench.expectPlaysPickAnimation(of: "Calendar")
    }

    @Test func aCancelledOtherLeavesTheIconAlone() {
        let bench = PickerBench(showing: "Safari")

        bench.pick("Other…")

        #expect(bench.closedItem.title == "Safari")
        #expect(bench.iconLayerContents === bench.icon("Safari"))
        #expect(bench.noLayerAnimates)
    }

    @Test func anOtherPickTheModelIgnoresChangesNothing() {
        let bench = PickerBench(showing: "Safari")

        bench.pick("Other…")
        bench.otherCompletion?(nil)

        #expect(bench.closedItem.title == "Safari")
        #expect(bench.iconLayerContents === bench.icon("Safari"))
        #expect(bench.noLayerAnimates)
    }

    @Test func aFirstAssignmentGrowsTheIconWhileTheNameAndChevronAreAlreadyInPlace() {
        let bench = PickerBench(showing: nil)
        #expect(bench.view.iconLayer.isHidden)

        bench.pick("Calendar")

        #expect(bench.closedItem.title == "Calendar")
        bench.expectPlaysPickAnimation(of: "Calendar")

        let settled = PickerBench(showing: "Calendar")
        #expect(bench.view.button.frame == settled.view.button.frame)
        #expect(bench.view.badge.frame == settled.view.badge.frame)
        #expect(bench.view.intrinsicContentSize == settled.view.intrinsicContentSize)
        #expect(bench.view.iconLayer.position == settled.view.iconLayer.position)
        #expect(bench.view.iconLayer.bounds == settled.view.iconLayer.bounds)
    }

    @Test func theIconSitsOnTheLeadingSquareOfTheButtonsImageSlot() {
        let bench = PickerBench(showing: "Safari")
        let layer = bench.view.iconLayer
        let slot = bench.view.convert(
            (bench.view.button.cell as! NSPopUpButtonCell).imageRect(forBounds: bench.view.button.bounds),
            from: bench.view.button)

        #expect(layer.bounds.size == CGSize(width: 16, height: 16))
        #expect(layer.position == CGPoint(x: slot.minX + 8, y: slot.minY + 8))
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
        #expect(bench.closedItem.title == "Choose app…")
        #expect(bench.view.iconLayer.isHidden)
        #expect(bench.noLayerAnimates)
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

        bench.pick("Music")

        bench.expectPlaysPickAnimation(of: "Music")
    }

    @Test func withoutAnAnimationAPickSwapsTheIconAtOnce() {
        let menu = PickerBench(showing: "Safari", animation: nil)
        menu.pick("Mail")
        #expect(menu.closedItem.title == "Mail")
        #expect(menu.iconLayerContents === menu.icon("Mail"))
        #expect(menu.noLayerAnimates)

        let other = PickerBench(showing: "Safari", animation: nil)
        other.pick("Other…")
        other.otherCompletion?(other.entry("Calendar"))
        #expect(other.closedItem.title == "Calendar")
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

        #expect(bench.view.layer?.masksToBounds == false)
        #expect(bench.view.iconLayer.masksToBounds == false)
        #expect(bench.view.clipsToBounds == false)
        #expect(bench.view.iconLayer.action(forKey: "contents") == nil)
        #expect(bench.view.iconLayer.action(forKey: "position") == nil)
        #expect(bench.view.iconLayer.action(forKey: "hidden") == nil)
    }
}
