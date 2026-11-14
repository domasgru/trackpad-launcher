import AppKit
import LauncherCore
import SwiftUI

/// Three dots that step: none, one, two, three, 250 ms each. Three period glyphs at the label's font, one centred in each
/// of three equal slots whose total width is the advance of "…" at that font. A mask anchored at the leading edge covers
/// 0, 1, 2 or 3 slots, so no dot is ever cut and the box never resizes: the word beside it never moves. The steps are one
/// repeating animation of the mask's width, which the render server plays while the view is in a window that is on screen
/// and Reduce motion is off; otherwise the mask shows all three dots, still. Added and removed on window, occlusion and
/// display-options changes, idempotently, as for the card's arrow. Hidden from accessibility: the label that owns it reads
/// whole.
final class ProgressDotsView: NSView {
    static let animationKey = "steps"

    /// Covers the dots from the leading edge; its model width is all three slots.
    let maskLayer = CALayer()
    private let dotsLayer = CALayer()
    private let dotLayers = (0..<3).map { _ in CATextLayer() }
    private let font: NSFont
    private let color: NSColor
    private let slot: CGFloat
    private let isOnScreen: (NSWindow) -> Bool
    private let reduceMotion: () -> Bool
    private var isObservingDisplayOptions = false
    private weak var observedWindow: NSWindow?

    /// The advance of "…" at `font`, and the line's height: the box the dots fill.
    static func size(font: NSFont) -> NSSize {
        let measured = NSAttributedString(string: "…", attributes: [.font: font]).size()
        return NSSize(width: measured.width, height: ceil(measured.height))
    }

    init(
        font: NSFont, color: NSColor, isOnScreen: @escaping (NSWindow) -> Bool, reduceMotion: @escaping () -> Bool
    ) {
        self.font = font
        self.color = color
        self.isOnScreen = isOnScreen
        self.reduceMotion = reduceMotion
        let size = Self.size(font: font)
        slot = size.width / 3
        super.init(frame: NSRect(origin: .zero, size: size))
        wantsLayer = true
        let silent: [String: CAAction] = [
            "contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "contentsScale": NSNull(),
            "foregroundColor": NSNull(), "backgroundColor": NSNull(),
        ]
        dotsLayer.frame = CGRect(origin: .zero, size: size)
        dotsLayer.actions = silent
        for (index, dot) in dotLayers.enumerated() {
            dot.frame = CGRect(x: CGFloat(index) * slot, y: 0, width: slot, height: size.height)
            dot.string = "."
            dot.font = font
            dot.fontSize = font.pointSize
            dot.alignmentMode = .center
            dot.actions = silent
            dotsLayer.addSublayer(dot)
        }
        maskLayer.anchorPoint = .zero
        maskLayer.position = .zero
        maskLayer.bounds = CGRect(origin: .zero, size: size)
        maskLayer.backgroundColor = NSColor.black.cgColor
        maskLayer.actions = silent
        dotsLayer.mask = maskLayer
        layer?.addSublayer(dotsLayer)
        updateAppearance()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { Self.size(font: font) }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func isAccessibilityElement() -> Bool { false }

    override func accessibilityChildren() -> [Any]? { [] }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateAppearance()
        stopObservingWindow()
        if let window {
            observedWindow = window
            NotificationCenter.default.addObserver(
                self, selector: #selector(windowStateChanged), name: NSWindow.didChangeOcclusionStateNotification,
                object: window)
            startObservingDisplayOptions()
        } else {
            stopObservingDisplayOptions()
        }
        applyMotion()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    /// A dynamic colour resolves to a `CGColor` for one appearance, so it is resolved again when the appearance changes.
    private func updateAppearance() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        var resolved = color.cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance { resolved = color.cgColor }
        for dot in dotLayers {
            dot.contentsScale = scale
            dot.foregroundColor = resolved
        }
    }

    private func stopObservingWindow() {
        guard let observedWindow else { return }
        NotificationCenter.default.removeObserver(
            self, name: NSWindow.didChangeOcclusionStateNotification, object: observedWindow)
        self.observedWindow = nil
    }

    private func startObservingDisplayOptions() {
        guard !isObservingDisplayOptions else { return }
        isObservingDisplayOptions = true
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(windowStateChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }

    private func stopObservingDisplayOptions() {
        guard isObservingDisplayOptions else { return }
        isObservingDisplayOptions = false
        NSWorkspace.shared.notificationCenter.removeObserver(
            self, name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }

    @objc private func windowStateChanged(_ notification: Notification) {
        applyMotion()
    }

    private func applyMotion() {
        let moves = window.map(isOnScreen) == true && !reduceMotion()
        if !moves {
            maskLayer.removeAnimation(forKey: Self.animationKey)
        } else if maskLayer.animation(forKey: Self.animationKey) == nil {
            maskLayer.add(Self.animation(slot: slot), forKey: Self.animationKey)
        }
    }

    /// The mask's width held at none, one, two, then three slots for a quarter second each. A discrete animation of four
    /// values takes five key times; with four the last value never shows.
    static func animation(slot: CGFloat) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "bounds.size.width")
        animation.values = (0...3).map { CGFloat($0) * slot }
        animation.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        animation.calculationMode = .discrete
        animation.duration = 1
        animation.repeatCount = .infinity
        // Not a no-op, though the loop never completes: without it a real window opens with the dots still.
        animation.isRemovedOnCompletion = false
        return animation
    }
}

/// The dots at the system label font for a control size, in the disabled control text colour, as a disabled bordered
/// button's own title shows. Gated by the window's occlusion and the system's Reduce motion setting.
struct ProgressDots: NSViewRepresentable {
    let controlSize: NSControl.ControlSize

    var font: NSFont { NSFont.systemFont(ofSize: NSFont.systemFontSize(for: controlSize)) }

    func makeNSView(context: Context) -> ProgressDotsView {
        ProgressDotsView(
            font: font, color: .disabledControlTextColor, isOnScreen: { $0.occlusionState.contains(.visible) },
            reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion })
    }

    func updateNSView(_ view: ProgressDotsView, context: Context) {}
}
