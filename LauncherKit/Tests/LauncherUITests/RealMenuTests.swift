import AppKit
@testable import LauncherCore
import Testing
@testable import LauncherUI

/// The picker in a real window, its menu opened and picked from by AppKit's own tracking, as a click does: what the
/// user sees while the menu is open and in the moment the pick lands, before the picker's action runs.
@Suite(.serialized) struct RealMenuTests {
    /// A long name, wider than the picker may ever be, so a button sized to its widest item overflows.
    static let names = PickerBench.names + ["An application with a very long name indeed"]

    @Test func theMenuOpensWithTheRowsAppOverTheButtonAndChecked() throws {
        // The row's app deep in a long list: the menu opens reaching far above the button to put it there.
        let fillers = (10..<50).map { "Filler \($0)" }
        let run = try RealMenuRun(showing: "Music", picking: nil, installed: fillers + Self.names)

        #expect(run.menuTopAboveButton > 400, "menu top \(run.menuTopAboveButton) pt above the button")

        // AppKit opens a pop-up's menu with its selected item over the button.
        #expect(run.selectedWhileOpen == "Music")
        #expect(run.checkedWhileOpen == ["Music"])
    }

    @Test func thePickedAppNeverShowsAtFullSizeBeforeThePickAnimation() throws {
        let run = try RealMenuRun(showing: "Safari", picking: "Mail")

        // What the button draws when AppKit has selected the pick and is about to send its action.
        let drawn = try #require(run.drawnImageAtPick)
        #expect(drawn.isClear, "no app icon drawn by the button itself")
        // Right after the action: the icon layer shows the pick and grows it from the pick animation's start.
        #expect(run.iconAfterPick === run.bench.icon("Mail"))
        let scales = run.animationAfterPick?.values?.compactMap { ($0 as? NSValue)?.caTransform3DValue.m11 }
        #expect(scales?.first.map { abs($0 - 0.4) < 1e-9 } == true)
        #expect(scales?.last.map { abs($0 - 1) < 1e-9 } == true)
    }

    @Test func theButtonNeverGrowsPastTheMaximumWidthAroundAPick() throws {
        let run = try RealMenuRun(showing: "Safari", picking: "Mail")

        #expect(run.widestButton <= AppPicker.maxWidth, "button width \(run.widestButton)")
    }

    @Test func theButtonIsSystemSettingsOwnPopUp() throws {
        let bench = PickerBench(showing: "Safari", installed: Self.names)
        let window = RealMenuRun.window(holding: bench.view)
        defer { window.close() }
        let button = try #require(bench.popUpButton)
        let cell = try #require(button.cell as? NSPopUpButtonCell)

        #expect(button.isBordered)
        #expect(cell.arrowPosition != .noArrow)
        #expect(cell.value(forKey: "_resolvedButtonStyle") as? Int == RealMenuRun.formButtonStyle)
        // The bezel shows on hover.
        #expect(cell.value(forKey: "_hasRolloverAppearance") as? Bool == true)
        #expect(button.font == NSFont.systemFont(ofSize: NSFont.systemFontSize))
        // A click on the chevrons, on the icon or on the name is the button's: the icon's own view takes none.
        let frame = button.frame
        for x in [frame.maxX - 6, frame.minX + 20, frame.midX] {
            #expect(button.superview?.hitTest(CGPoint(x: x, y: frame.midY)) === button, "click at x \(x)")
        }
        #expect(button.attributedTitle.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
            ?? button.font == NSFont.systemFont(ofSize: NSFont.systemFontSize))
    }
}

/// One real open of the picker's menu in a window: optionally picks `title` while it tracks.
@MainActor final class RealMenuRun {
    /// The cell's resolved style in a grouped Form (System Settings): chevrons in a badge, bezel on hover.
    static let formButtonStyle = 10

    let bench: PickerBench
    private(set) var selectedWhileOpen: String?
    /// The icon layer's contents and animations right after the picked item's action ran.
    private(set) var iconAfterPick: AnyObject?
    private(set) var animationAfterPick: CAKeyframeAnimation?
    private(set) var checkedWhileOpen: [String] = []
    private(set) var drawnImageAtPick: NSImage?
    private(set) var widestButton: CGFloat = 0

    /// How far the open menu's top edge is above the button's top edge, in points.
    private(set) var menuTopAboveButton: CGFloat = 0

    init(showing name: String, picking title: String?, installed: [String] = RealMenuTests.names) throws {
        bench = PickerBench(showing: name, installed: installed)
        let window = Self.window(holding: bench.view)
        defer { window.close() }
        let button = try #require(bench.popUpButton)
        let menu = try #require(button.menu)
        // The timer and the observer run on the main thread, inside AppKit's menu tracking.
        nonisolated(unsafe) let unsafeButton = button, unsafeMenu = menu, unsafeWindow = window
        let observer = NotificationCenter.default.addObserver(
            forName: NSMenu.willSendActionNotification, object: nil, queue: nil
        ) { [unowned self] _ in
            MainActor.assumeIsolated {
                drawnImageAtPick = Self.drawnItem(of: unsafeButton)?.image
                measure(unsafeButton, in: unsafeWindow)
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        let sent = NotificationCenter.default.addObserver(
            forName: NSMenu.didSendActionNotification, object: nil, queue: nil
        ) { [unowned self] _ in
            MainActor.assumeIsolated {
                iconAfterPick = bench.view.iconLayer.contents as AnyObject?
                animationAfterPick = bench.view.iconLayer.animation(forKey: PickerButton.pickKey) as? CAKeyframeAnimation
            }
        }
        defer { NotificationCenter.default.removeObserver(sent) }
        let timer = Timer(timeInterval: 0.3, repeats: false) { [unowned self] _ in
            MainActor.assumeIsolated {
                selectedWhileOpen = unsafeButton.selectedItem?.title
                let buttonTop = unsafeWindow.convertToScreen(unsafeButton.convert(unsafeButton.bounds, to: nil)).maxY
                let menuTop = NSApp.windows.filter { $0.isVisible && $0.className.contains("Menu") }
                    .map(\.frame.maxY).max() ?? buttonTop
                menuTopAboveButton = menuTop - buttonTop
                checkedWhileOpen = unsafeMenu.items.filter { $0.state == .on }.map(\.title)
                measure(unsafeButton, in: unsafeWindow)
                unsafeMenu.cancelTracking()
                if let title, let index = unsafeMenu.items.firstIndex(where: { $0.title == title }) {
                    unsafeMenu.performActionForItem(at: index)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        button.performClick(nil)
        // Let the menu's close and the picker's deferred work land, measuring each layout on the way.
        for _ in 0..<10 {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            measure(button, in: window)
        }
    }

    private func measure(_ button: NSPopUpButton, in window: NSWindow) {
        window.contentView?.layoutSubtreeIfNeeded()
        // The button and whatever draws it: AppKit renders a pop-up through a subview of its own.
        func extent(_ view: NSView) -> CGRect {
            view.subviews.reduce(view.convert(view.bounds, to: nil)) { $0.union(extent($1)) }
        }
        widestButton = max(widestButton, extent(button).width)
    }

    /// The item the button draws: its own display item, or the menu's selected one.
    static func drawnItem(of button: NSPopUpButton) -> NSMenuItem? {
        guard let cell = button.cell as? NSPopUpButtonCell else { return nil }
        return cell.usesItemFromMenu ? button.selectedItem : cell.menuItem
    }

    /// A window wide enough for any pop-up, the picker at the picker's own size in it.
    static func window(holding view: NSView) -> NSWindow {
        NSApplication.shared.setActivationPolicy(.accessory)
        let window = NSWindow(
            contentRect: CGRect(x: 200, y: 80, width: 600, height: 120), styleMask: [.titled], backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
        let root = NSView(frame: CGRect(x: 0, y: 0, width: 600, height: 120))
        root.addSubview(view)
        view.setFrameOrigin(CGPoint(x: 20, y: 40))
        window.contentView = root
        window.orderFrontRegardless()
        return window
    }
}

extension NSImage {
    /// Every pixel transparent: a slot holder, not an icon.
    var isClear: Bool {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)
        else { return false }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0 { return false }
        }
        return true
    }
}

extension PickerBench {
    /// The pop-up button inside the picker's view.
    var popUpButton: NSPopUpButton? {
        func find(_ view: NSView) -> NSPopUpButton? {
            (view as? NSPopUpButton) ?? view.subviews.lazy.compactMap(find).first
        }
        return find(view)
    }
}
