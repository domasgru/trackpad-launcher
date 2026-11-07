import AppKit
import LauncherCore
import Testing
@testable import LauncherUI

/// A panel that records its ordering instead of showing itself.
@MainActor
final class BenchPanel: WindowSwitcherPanel {
    override func orderFrontRegardless() {}
    override func orderOut(_ sender: Any?) {}
}

@MainActor
enum CardFixtures {
    static let notes = AppEntry(
        bundleID: BundleID(rawValue: "com.test.notes"), name: "Notes", url: URL(fileURLWithPath: "/Applications/Notes.app"))

    static func content(windows: [UInt32], in app: AppEntry = notes) throws -> WindowSwitcher.Content {
        var orders = WindowOrders()
        let list = AppWindows(visible: windows.map { AppWindow(id: WindowID(rawValue: $0), title: "W\($0)") }, minimised: [])
        let content = orders.list(.app(app, AppLaunch("bench"), .windows(list)), stillOpen: { _ in [] })
        return try #require(content)
    }

    static func switcher(windows: [UInt32], serial: Int = 1, followMM: Double? = nil) throws -> WindowSwitcher {
        var switcher = WindowSwitcher(
            try content(windows: windows), showsPreviews: false, serial: serial, trackpad: TrackpadID(rawValue: 1))
        if let followMM { switcher.selection.follow(followMM) }
        return switcher
    }

    static func icon() -> NSImage { NSImage(size: NSSize(width: 44, height: 44)) }

    static func offset(of layer: CALayer?) -> Double { -Double(layer?.transform.m42 ?? 0) }
}

@MainActor @Suite(.serialized) struct WindowSwitcherCardTests {
    private let layout = WindowColumnLayout(rowCount: 1, displayHeight: 0)
    private let topLeft = NSPoint(x: 100, y: 800)

    private func laidOutPanel() throws -> WindowSwitcherPanel {
        _ = NSApplication.shared
        let panel = WindowSwitcherPanel()
        guard case .card(let card) = try CardFixtures.content(windows: [1]).list else {
            Issue.record("one window is the card")
            return panel
        }
        panel.lay(card: card, icon: CardFixtures.icon(), layout: layout, topLeft: topLeft)
        return panel
    }

    @Test func theCardHasTheIconWhereAPreviewSitsAndABoldTitleAboveARegularMessage() throws {
        let panel = try laidOutPanel()

        let slotCentre = NSPoint(x: layout.inset + layout.slot.width / 2, y: layout.inset + layout.slot.height / 2)
        let icon = panel.cardIcon.frame
        #expect(abs(icon.midX - slotCentre.x) < 0.5 && abs(icon.midY - slotCentre.y) < 0.5)
        #expect(panel.cardTitle.stringValue == "No other windows")
        #expect(panel.cardTitle.font?.pointSize == 13)
        #expect(panel.cardTitle.font?.fontDescriptor.symbolicTraits.contains(.bold) == true)
        #expect(panel.cardMessage.stringValue == "Notes has no other windows on this desktop.")
        #expect(panel.cardMessage.font?.pointSize == 12)
        #expect(panel.cardMessage.font?.fontDescriptor.symbolicTraits.contains(.bold) == false)
        #expect(panel.cardMessage.maximumNumberOfLines == 2)
        #expect(panel.cardMessage.frame.height > 20 && panel.cardMessage.frame.height < 40)
        #expect(panel.cardMessage.cell?.truncatesLastVisibleLine == true)
        #expect(panel.cardTitle.frame.minY > panel.cardMessage.frame.minY)
        #expect(abs(panel.cardTitle.frame.minX - layout.titleLeading) < 0.01)
        #expect(panel.visibleRowCount == 0)
        #expect(panel.cardContent.isHidden == false)
    }

    @Test func layingOutRowsHidesTheCardAndLayingOutTheCardHidesTheRows() throws {
        let panel = try laidOutPanel()
        let rows = try CardFixtures.content(windows: [1, 2, 3])
        guard case .rows(let listed) = rows.list else { Issue.record("three windows are rows"); return }

        panel.lay(
            out: listed.rows, icon: CardFixtures.icon(), layout: WindowColumnLayout(rowCount: 3, displayHeight: 0),
            topLeft: topLeft)
        #expect(panel.cardContent.isHidden)
        #expect(panel.visibleRowCount == 3)

        guard case .card(let card) = try CardFixtures.content(windows: []).list else { Issue.record("none is the card"); return }
        panel.lay(card: card, icon: CardFixtures.icon(), layout: layout, topLeft: topLeft)
        #expect(panel.cardContent.isHidden == false)
        #expect(panel.visibleRowCount == 0)
        #expect(panel.cardTitle.stringValue == "No open windows")
    }

    @Test func movingTheCardMovesThePlateAndItsContentTogetherWithAShortAction() throws {
        let panel = try laidOutPanel()

        panel.moveCard(by: 6, animated: true)
        #expect(CardFixtures.offset(of: panel.highlightLayer) == 6)
        #expect(CardFixtures.offset(of: panel.cardContent.layer) == 6)
        #expect(try #require(panel.highlightLayer?.animation(forKey: "card")).duration == 0.1)
        #expect(try #require(panel.cardContent.layer?.animation(forKey: "card")).duration == 0.1)

        panel.moveCard(by: -6, animated: true)
        #expect(CardFixtures.offset(of: panel.highlightLayer) == -6)
        #expect(CardFixtures.offset(of: panel.cardContent.layer) == -6)
    }

    @Test func settlingTheCardReturnsItToRestOverTheDismissFadeOrAtOnce() throws {
        let panel = try laidOutPanel()
        panel.moveCard(by: 6, animated: false)
        #expect(panel.highlightLayer?.animation(forKey: "card") == nil)

        panel.settleCard(animated: true)
        #expect(CardFixtures.offset(of: panel.highlightLayer) == 0)
        #expect(CardFixtures.offset(of: panel.cardContent.layer) == 0)
        #expect(try #require(panel.highlightLayer?.animation(forKey: "card")).duration == 0.15)

        panel.moveCard(by: 6, animated: false)
        panel.settleCard(animated: false)
        #expect(CardFixtures.offset(of: panel.highlightLayer) == 0)
        #expect(panel.highlightLayer?.animation(forKey: "card") == nil)
        #expect(panel.cardContent.layer?.animation(forKey: "card") == nil)
    }

    @Test func settlingWithRowsLaidOutChangesNothing() throws {
        let panel = try laidOutPanel()
        guard case .rows(let listed) = try CardFixtures.content(windows: [1, 2]).list else { return }
        panel.lay(
            out: listed.rows, icon: CardFixtures.icon(), layout: WindowColumnLayout(rowCount: 2, displayHeight: 0),
            topLeft: topLeft)
        let frame = panel.highlightLayer?.frame

        panel.settleCard(animated: true)

        #expect(panel.highlightLayer?.animationKeys() == nil)
        #expect(panel.highlightLayer?.frame == frame)
    }

    // MARK: Presenter

    private func presenter(reduceMotion: Bool) -> (WindowSwitcherPresenter, BenchPanel) {
        _ = NSApplication.shared
        let panel = BenchPanel()
        return (WindowSwitcherPresenter(reduceMotion: { reduceMotion }, panel: panel), panel)
    }

    @Test func theCardFollowsTheFingersThenSettlesBackAsThePanelGoes() throws {
        let (presenter, panel) = presenter(reduceMotion: false)
        let shown = try CardFixtures.switcher(windows: [1], followMM: 40)
        #expect(shown.cardOffset == 6)

        presenter.render(shown)
        #expect(CardFixtures.offset(of: panel.highlightLayer) == 6)
        #expect(CardFixtures.offset(of: panel.cardContent.layer) == 6)

        presenter.render(nil)
        #expect(CardFixtures.offset(of: panel.highlightLayer) == 0)
        #expect(try #require(panel.highlightLayer?.animation(forKey: "card")).duration == 0.15)
    }

    @Test func theCardStaysStillWithReduceMotionOn() throws {
        let (presenter, panel) = presenter(reduceMotion: true)

        presenter.render(try CardFixtures.switcher(windows: [1], followMM: 40))
        #expect(CardFixtures.offset(of: panel.highlightLayer) == 0)
        #expect(panel.highlightLayer?.animation(forKey: "card") == nil)

        presenter.render(nil)
        #expect(CardFixtures.offset(of: panel.highlightLayer) == 0)
        #expect(panel.highlightLayer?.animation(forKey: "card") == nil)
    }

    @Test func rowsOfTheNextWindowSwipeReplaceTheCard() throws {
        let (presenter, panel) = presenter(reduceMotion: false)
        presenter.render(try CardFixtures.switcher(windows: [1], serial: 1))
        #expect(panel.visibleRowCount == 0 && panel.cardContent.isHidden == false)

        presenter.render(try CardFixtures.switcher(windows: [1, 2, 3], serial: 2))

        #expect(panel.visibleRowCount == 3)
        #expect(panel.cardContent.isHidden)
    }
}
