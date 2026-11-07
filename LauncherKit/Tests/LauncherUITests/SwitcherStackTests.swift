import AppKit
@testable import LauncherCore
import Testing
@testable import LauncherUI

@MainActor @Suite(.serialized) struct SwitcherStackTests {
    private let row = SwitcherRowLayout(iconCount: 5, displayWidth: 1512)
    private let screen = NSRect(x: 0, y: 0, width: 1512, height: 982)

    private func icon() -> NSImage {
        NSImage(size: NSSize(width: 80, height: 80), flipped: false) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
            return true
        }
    }

    private func laidOutPanel() -> SwitcherPanel {
        _ = NSApplication.shared
        let panel = SwitcherPanel()
        panel.layoutRow((0..<5).map { _ in icon() }, layout: row, on: screen, scale: 2)
        return panel
    }

    private func close(_ value: CGFloat, _ expected: Double) -> Bool { abs(Double(value) - expected) < 0.0001 }

    /// A layer's top edge in its container's parent, which has the panel's content origin.
    private func topEdge(of layer: CALayer, in container: CALayer) -> CGFloat {
        let top = CGPoint(x: layer.position.x, y: layer.position.y + layer.bounds.height / 2)
        return container.convert(top, to: container.superlayer).y
    }

    @Test func aStackSitsInItsSlotWithItsCopiesBehindTheIconAndTheRowKeepsItsShape() throws {
        let panel = laidOutPanel()
        let copies = WindowStackLayout(row: row).copies(of: try #require(WindowStack(windows: 4)))

        panel.addStack(at: 2, copies: copies, rises: false)

        #expect(panel.frame.size == CGSize(width: 536, height: 136))
        #expect(panel.slotLayers.count == 5)
        for (index, slot) in panel.slotLayers.enumerated() {
            #expect(close(slot.position.x, 68 + 100 * Double(index)) && close(slot.position.y, 68))
            let icon = try #require(slot.sublayers?.last)
            #expect(icon.bounds.size == CGSize(width: 80, height: 80))
            #expect(slot.sublayers?.count == (index == 2 ? 4 : 1))
        }
        let slot = panel.slotLayers[2]
        let layers = try #require(slot.sublayers)
        let icon = try #require(layers.last)
        let iconTop = topEdge(of: icon, in: slot)
        #expect(close(iconTop, 68 + 40))
        let copyLayers = Array(layers.dropLast())
        #expect(copyLayers.count == 3)
        #expect(copyLayers.allSatisfy { $0.contents as AnyObject === icon.contents as AnyObject })
        let nearestFirst = Array(copyLayers.reversed())
        #expect(nearestFirst.map { close(topEdge(of: $0, in: slot) - iconTop, 6 * Double(nearestFirst.firstIndex(of: $0)! + 1)) } == [true, true, true])
        #expect(nearestFirst.map(\.bounds.width).enumerated().allSatisfy { close($1, [73.6, 67.2, 60.8][$0]) })
    }

    @Test func theWholeStackGrowsWithTheSelectedIconAndNothingElseMoves() throws {
        let panel = laidOutPanel()
        panel.addStack(at: 2, copies: WindowStackLayout(row: row).copies(of: try #require(WindowStack(windows: 4))), rises: false)

        panel.show(position: 2, selected: 2, animatesSize: false)

        let selected = panel.slotLayers[2]
        #expect(close(selected.transform.m11, 1.12) && close(selected.transform.m22, 1.12))
        for layer in selected.sublayers ?? [] {
            #expect(CATransform3DIsIdentity(layer.transform))
        }
        for (index, slot) in panel.slotLayers.enumerated() where index != 2 {
            #expect(CATransform3DIsIdentity(slot.transform))
        }
    }

    @Test func aStackAddedToAMissingSlotChangesNothing() throws {
        let panel = laidOutPanel()
        panel.addStack(at: 7, copies: WindowStackLayout(row: row).copies(of: try #require(WindowStack(windows: 3))), rises: false)
        #expect(panel.slotLayers.allSatisfy { $0.sublayers?.count == 1 })
    }

    private func nearestFirst(_ slot: CALayer) throws -> [CALayer] {
        Array(try #require(slot.sublayers).dropLast().reversed())
    }

    @Test func aRisingStackStartsBehindTheIconAndEachCopyRisesFortyMillisecondsAfterTheOneInFront() throws {
        let panel = laidOutPanel()
        let copies = WindowStackLayout(row: row).copies(of: try #require(WindowStack(windows: 4)))

        panel.addStack(at: 1, copies: copies, rises: true)

        let slot = panel.slotLayers[1]
        let layers = try nearestFirst(slot)
        #expect(layers.count == 3)
        var begins: [Double] = []
        for layer in layers {
            #expect(layer.animationKeys() == ["rise"])
            let rise = try #require(layer.animation(forKey: "rise") as? CABasicAnimation)
            #expect(rise.keyPath == "position.y")
            #expect(close(CGFloat(try #require(rise.fromValue as? Double)), 40))
            #expect(close(CGFloat(try #require(rise.toValue as? Double)), layer.position.y))
            #expect(rise.duration == 0.3)
            #expect(rise.fillMode == .backwards)
            #expect(rise.isRemovedOnCompletion)
            let curve = try #require(rise.timingFunction)
            var controls: [Float] = []
            for index in 1...2 {
                var point: [Float] = [0, 0]
                curve.getControlPoint(at: index, values: &point)
                controls += point
            }
            #expect(controls == [0.25, 1.0, 0.5, 1.0])
            begins.append(rise.beginTime)
        }
        #expect(zip(layers, copies).allSatisfy { close($0.position.y, 40 + $1.rise) })
        #expect(close(CGFloat(begins[1] - begins[0]), 0.04) && close(CGFloat(begins[2] - begins[1]), 0.04))
    }

    @Test func movingTheSelectionOverARisingStackNeitherReplaysNorCutsItsRise() throws {
        let panel = laidOutPanel()
        panel.addStack(at: 1, copies: WindowStackLayout(row: row).copies(of: try #require(WindowStack(windows: 4))), rises: true)
        let layers = try nearestFirst(panel.slotLayers[1])
        let rises = try layers.map { try #require($0.animation(forKey: "rise")) }

        for selected in [0, 1, 2, 1, 0] {
            panel.show(position: CGFloat(selected), selected: selected, animatesSize: true)
            for (layer, rise) in zip(layers, rises) {
                #expect(layer.animationKeys() == ["rise"])
                #expect(layer.animation(forKey: "rise") === rise)
            }
        }
    }

    @Test func aStackWithoutRisingPlacesItsCopiesAtRestWithNoAnimation() throws {
        let panel = laidOutPanel()
        let copies = WindowStackLayout(row: row).copies(of: try #require(WindowStack(windows: 4)))

        panel.addStack(at: 1, copies: copies, rises: false)

        let layers = try nearestFirst(panel.slotLayers[1])
        #expect(layers.allSatisfy { $0.animationKeys() == nil })
        #expect(zip(layers, copies).allSatisfy { close($0.position.y, 40 + $1.rise) })
    }
}

@MainActor
final class BenchSwitcherPanel: SwitcherPanel {
    override func orderFrontRegardless() {}
    override func orderOut(_ sender: Any?) {}
}

@MainActor @Suite(.serialized) struct SwitcherRiseTests {
    private let apps = ["safari", "mail", "notes"].map {
        AppEntry(bundleID: BundleID(rawValue: "com.test.\($0)"), name: $0, url: URL(fileURLWithPath: "/Applications/\($0).app"))
    }

    private func presenter(reduceMotion: Bool) -> (SwitcherPresenter, BenchSwitcherPanel) {
        _ = NSApplication.shared
        let panel = BenchSwitcherPanel()
        return (SwitcherPresenter(reduceMotion: { reduceMotion }, panel: panel), panel)
    }

    private func switcher(serial: Int, stacks: [Int?], selected: Int = 0) throws -> Switcher {
        var switcher = try #require(
            Switcher(frontmost: apps[0], running: apps, leavingOut: [], serial: serial, trackpad: TrackpadID(rawValue: 1)))
        for (slot, count) in stacks.enumerated() {
            guard let count else { continue }
            let read = WindowRead.windows(
                AppWindows(
                    visible: (0..<count).map { AppWindow(id: WindowID(rawValue: UInt32($0 + 1)), title: "W\($0)") },
                    minimised: []))
            switcher.take(read, at: slot)
        }
        switcher.selection.follow(GestureRules.switcherStepMM * Double(selected))
        return switcher
    }

    private func risers(_ panel: SwitcherPanel) -> [[CALayer]] {
        panel.slotLayers.map { slot in (slot.sublayers ?? []).dropLast().filter { $0.animation(forKey: "rise") != nil } }
    }

    private func copyCounts(_ panel: SwitcherPanel) -> [Int] { panel.slotLayers.map { ($0.sublayers?.count ?? 1) - 1 } }

    @Test func eachStackRisesOnceWhenItsCountArrivesAndNeverWhileTheSelectionMoves() throws {
        let (presenter, panel) = presenter(reduceMotion: false)

        presenter.render(try switcher(serial: 1, stacks: [3, nil, 1]))
        #expect(panel.slotLayers.count == 3)
        #expect(copyCounts(panel) == [2, 0, 0])
        #expect(risers(panel).map(\.count) == [2, 0, 0])
        let first = risers(panel)[0].map { $0.animation(forKey: "rise")! }

        presenter.render(try switcher(serial: 1, stacks: [3, 2, 1], selected: 1))
        #expect(copyCounts(panel) == [2, 1, 0])
        #expect(risers(panel).map(\.count) == [2, 1, 0])
        #expect(zip(risers(panel)[0], first).allSatisfy { $0.animation(forKey: "rise") === $1 })

        let second = risers(panel)[1].map { $0.animation(forKey: "rise")! }
        presenter.render(try switcher(serial: 1, stacks: [3, 2, 1], selected: 2))
        #expect(copyCounts(panel) == [2, 1, 0])
        #expect(zip(risers(panel)[0], first).allSatisfy { $0.animation(forKey: "rise") === $1 })
        #expect(zip(risers(panel)[1], second).allSatisfy { $0.animation(forKey: "rise") === $1 })

        presenter.render(try switcher(serial: 2, stacks: [3, nil, nil]))
        #expect(copyCounts(panel) == [2, 0, 0])
        #expect(risers(panel).map(\.count) == [2, 0, 0])
        #expect(zip(risers(panel)[0], first).allSatisfy { $0.animation(forKey: "rise") !== $1 })
    }

    @Test func aRowWhoseCountsAreAllPendingShowsWithNoCopies() throws {
        let (presenter, panel) = presenter(reduceMotion: false)
        presenter.render(try switcher(serial: 1, stacks: [nil, nil, nil]))
        #expect(panel.slotLayers.count == 3)
        #expect(copyCounts(panel) == [0, 0, 0])
    }

    @Test func withReduceMotionEveryStackShowsInPlaceAtOnce() throws {
        let (presenter, panel) = presenter(reduceMotion: true)

        presenter.render(try switcher(serial: 1, stacks: [3, nil, 1]))
        presenter.render(try switcher(serial: 1, stacks: [3, 2, 1], selected: 1))

        #expect(copyCounts(panel) == [2, 1, 0])
        #expect(panel.slotLayers.allSatisfy { slot in (slot.sublayers ?? []).allSatisfy { $0.animationKeys() == nil } })
    }
}
