import AppKit
import Testing
@testable import LauncherUI

@MainActor @Suite struct SettingsPopUpTests {
    enum Corner: CaseIterable { case first, second, third }

    final class Bench {
        let coordinator: SettingsPopUp<Corner>.Coordinator
        let button: SettingsPopUpButton
        var selected: [Corner] = []
        var selection: Corner

        init(selection: Corner) {
            self.selection = selection
            coordinator = SettingsPopUp<Corner>.Coordinator()
            button = SettingsPopUp(
                options: [], title: { _ in "" }, selection: selection, select: { _ in }, accessibilityLabel: ""
            ).makeView(coordinator: coordinator)
            render()
        }

        func render() {
            SettingsPopUp(
                options: Corner.allCases, title: { "\($0)" }, selection: selection,
                select: { [unowned self] in selected.append($0) }, accessibilityLabel: "Corner"
            ).update(button, coordinator: coordinator)
        }

        /// What a click on `title` in the menu does: AppKit selects the item, then sends the action.
        func pick(_ title: String) {
            button.selectItem(withTitle: title)
            _ = button.sendAction(button.action, to: button.target)
        }
    }

    @Test func listsEveryOptionWithTheSelectionShown() {
        let bench = Bench(selection: .second)

        #expect(bench.button.itemTitles == ["first", "second", "third"])
        #expect(bench.button.titleOfSelectedItem == "second")
        #expect(bench.button.accessibilityLabel() == "Corner")
    }

    @Test func pickingSendsTheOptionAndTheButtonFollowsTheModel() {
        let bench = Bench(selection: .first)

        bench.pick("third")
        bench.selection = .third
        bench.render()

        #expect(bench.selected == [.third])
        #expect(bench.button.titleOfSelectedItem == "third")
    }

    /// The bug this guards: a pop-up in the settings window drew a gray bezel at rest, where System Settings' pop-ups
    /// draw only their chevron badge until hovered.
    @Test func atRestTheButtonDrawsNoBezelBehindItsTitle() throws {
        let bench = Bench(selection: .first)
        let plain = NSPopUpButton(frame: .zero, pullsDown: false)
        plain.addItems(withTitles: bench.button.itemTitles)

        #expect(try Self.leadingPadding(of: bench.button) == .white)
        // The standard bordered look fills the same spot, so the check above can tell the two apart.
        #expect(try Self.leadingPadding(of: plain) != .white)
    }

    enum Shade: Equatable { case white, other }

    /// The colour, at rest on a white background, of the button's leading padding at its vertical middle: where the
    /// bezel is and the title is not.
    static func leadingPadding(of button: NSPopUpButton) throws -> Shade {
        button.sizeToFit()
        button.setFrameOrigin(NSPoint(x: 10, y: 10))
        let background = NSView(frame: NSRect(x: 0, y: 0, width: button.frame.width + 20, height: button.frame.height + 20))
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.white.cgColor
        background.addSubview(button)
        let window = NSWindow(contentRect: background.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = background
        let rep = try #require(background.bitmapImageRepForCachingDisplay(in: background.bounds))
        background.cacheDisplay(in: background.bounds, to: rep)
        let scale = CGFloat(rep.pixelsWide) / background.bounds.width
        let point = NSPoint(x: button.frame.minX + 4, y: background.bounds.height - button.frame.midY)
        let color = try #require(
            rep.colorAt(x: Int(point.x * scale), y: Int(point.y * scale))?.usingColorSpace(.sRGB))
        let isWhite = [color.redComponent, color.greenComponent, color.blueComponent].allSatisfy { $0 > 0.98 }
        button.removeFromSuperview()
        return isWhite ? .white : .other
    }
}
