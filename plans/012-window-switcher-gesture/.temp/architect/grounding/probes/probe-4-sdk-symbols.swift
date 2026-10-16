// Probe 4: which capture and glass symbols the macOS 26 SDK still offers, and how it flags them.
// Typecheck only: swiftc -typecheck probe-4-sdk-symbols.swift  (warnings and errors are the result)
import AppKit
import ScreenCaptureKit

func deprecatedCapture(id: CGWindowID) -> CGImage? {
    CGWindowListCreateImage(.null, .optionIncludingWindow, id, [.boundsIgnoreFraming, .nominalResolution])
}

func permission() -> Bool {
    _ = CGRequestScreenCaptureAccess()
    return CGPreflightScreenCaptureAccess()
}

@MainActor func glass() {
    let container = NSGlassEffectContainerView()
    let glass = NSGlassEffectView()
    glass.cornerRadius = 12
    glass.tintColor = .white
    glass.style = .regular
    container.contentView = glass
    container.spacing = 8
    _ = NSApplication.shared
}

@MainActor func panel() -> NSPanel {
    let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    p.level = .popUpMenu
    p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    p.ignoresMouseEvents = true
    p.hidesOnDeactivate = false
    return p
}
