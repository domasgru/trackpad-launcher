import AppKit
import LauncherCore
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

        panel.addStack(at: 2, copies: copies)

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
        panel.addStack(at: 2, copies: WindowStackLayout(row: row).copies(of: try #require(WindowStack(windows: 4))))

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
        panel.addStack(at: 7, copies: WindowStackLayout(row: row).copies(of: try #require(WindowStack(windows: 3))))
        #expect(panel.slotLayers.allSatisfy { $0.sublayers?.count == 1 })
    }
}
