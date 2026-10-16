import AppKit
import ApplicationServices
import CoreGraphics
import LauncherCore

/// The frontmost app's windows, read through the Accessibility element API and the window server's window list: the
/// only file that touches either. The element API defines which windows exist (titles, roles, minimised, full screen);
/// the window list orders the visible ones and tells which are on this Space.
///
/// A window's number comes from the private `_AXUIElementGetWindow`, resolved once with `dlsym` from the image
/// AppKit already loaded; when a macOS drops it, windows are matched to the window list by frame and title instead,
/// and a window that matches none is left out.
@MainActor final class FrontmostAppWindows {
    /// Bounds every call into another app: one that does not answer in time reads as having no windows.
    static let messagingTimeout: Float = 0.2

    private typealias GetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

    private let getWindow: GetWindow?

    private static let attributes = [
        kAXRoleAttribute, kAXSubroleAttribute, kAXTitleAttribute, kAXMinimizedAttribute, "AXFullScreen",
        kAXPositionAttribute, kAXSizeAttribute,
    ] as CFArray

    /// Sets the messaging timeout once on the system-wide element, which makes it the process's default (set on any
    /// other element it covers that element only); resolves the private window number; and pays the window list's
    /// first-call cost (about 50 ms) off the main actor now rather than at the first window swipe.
    init() {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), Self.messagingTimeout)
        // RTLD_DEFAULT
        getWindow = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow")
            .map { unsafeBitCast($0, to: GetWindow.self) }
        DispatchQueue.global(qos: .utility).async {
            _ = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        }
    }

    func read() -> FrontmostWindows {
        guard let running = NSWorkspace.shared.frontmostApplication,
            running.processIdentifier != ProcessInfo.processInfo.processIdentifier,
            let entry = RunningApp.entry(for: running)
        else { return .noApp }
        let pid = running.processIdentifier
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &value)
            == .success, let elements = value as? [AXUIElement]
        else { return .app(entry, visible: [], minimised: []) }

        var raw: [RawWindow] = []
        for element in elements {
            var values: CFArray?
            let error = AXUIElementCopyMultipleAttributeValues(
                element, Self.attributes, AXCopyMultipleAttributeOptions(rawValue: 0), &values)
            // The app stopped answering: what was read so far stands.
            if error == .cannotComplete { break }
            guard error == .success, let values = values as? [AnyObject] else { continue }
            raw.append(Self.rawWindow(values, number: number(of: element)))
        }
        if getWindow == nil {
            let listed = Self.listedWindows(of: pid)
            for i in raw.indices { raw[i].number = Self.number(of: raw[i], among: listed) }
        }
        let sorted = Self.sort(raw, onScreen: Self.onScreenNumbers(of: pid))
        return .app(entry, visible: sorted.visible, minimised: sorted.minimised)
    }

    private func number(of element: AXUIElement) -> UInt32? {
        guard let getWindow else { return nil }
        var number: CGWindowID = 0
        return getWindow(element, &number) == .success ? number : nil
    }

    /// The values in `attributes`' order; an attribute the window lacks comes back as an error value and reads as nil.
    private static func rawWindow(_ values: [AnyObject], number: UInt32?) -> RawWindow {
        func value(_ index: Int) -> AnyObject? { index < values.count ? values[index] : nil }
        func axValue(_ index: Int, _ type: AXValueType) -> AXValue? {
            guard let object = value(index), CFGetTypeID(object) == AXValueGetTypeID() else { return nil }
            let axValue = object as! AXValue
            return AXValueGetType(axValue) == type ? axValue : nil
        }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        let position = axValue(5, .cgPoint).flatMap { AXValueGetValue($0, .cgPoint, &origin) ? origin : nil }
        let size = axValue(6, .cgSize).flatMap { AXValueGetValue($0, .cgSize, &extent) ? extent : nil }
        return RawWindow(
            number: number, title: value(2) as? String ?? "", role: value(0) as? String, subrole: value(1) as? String,
            isMinimised: value(3) as? Bool ?? false, isFullScreen: value(4) as? Bool ?? false,
            frame: position.flatMap { origin in size.map { CGRect(origin: origin, size: $0) } })
    }

    /// The pid's normal-layer windows on screen now, front to back: on this Space, not minimised.
    private static func onScreenNumbers(of pid: pid_t) -> [UInt32] {
        windowList([.optionOnScreenOnly, .excludeDesktopElements], of: pid).map(\.number)
    }

    /// Every normal-layer window of the pid the window server knows, minimised ones included, for matching by frame.
    private static func listedWindows(of pid: pid_t) -> [ListedWindow] {
        windowList([.optionAll, .excludeDesktopElements], of: pid)
    }

    private static func windowList(_ options: CGWindowListOption, of pid: pid_t) -> [ListedWindow] {
        let all = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return all.compactMap { info in
            guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                let number = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                let frame = CGRect(dictionaryRepresentation: bounds)
            else { return nil }
            return ListedWindow(number: number, frame: frame, name: info[kCGWindowName as String] as? String)
        }
    }

    /// Which windows are listed, and in what order. Visible: role AXWindow, subrole AXStandardWindow, not minimised,
    /// on screen now (so on this Space), in the window list's order. Minimised: by the minimised flag alone, because a
    /// minimised window reports the AXDialog subrole, in the app's order. A window with no number is left out.
    nonisolated static func sort(
        _ windows: [RawWindow], onScreen: [UInt32]
    ) -> (visible: [AppWindow], minimised: [AppWindow]) {
        var standard: [UInt32: AppWindow] = [:]
        var minimised: [AppWindow] = []
        for window in windows {
            guard let number = window.number else { continue }
            if window.isMinimised {
                minimised.append(AppWindow(id: WindowID(rawValue: number), title: window.title))
            } else if window.role == "AXWindow", window.subrole == "AXStandardWindow" {
                standard[number] = AppWindow(
                    id: WindowID(rawValue: number), title: window.title, isFullScreen: window.isFullScreen)
            }
        }
        return (onScreen.compactMap { standard[$0] }, minimised)
    }

    /// The window's number without the private call: the one listed window with the same frame and, where the list
    /// names windows, the same title. nil when none or more than one matches, or the window has no frame.
    nonisolated static func number(of window: RawWindow, among listed: [ListedWindow]) -> UInt32? {
        guard let frame = window.frame else { return nil }
        let matches = listed.filter { $0.frame == frame && ($0.name.map { $0 == window.title } ?? true) }
        return matches.count == 1 ? matches[0].number : nil
    }
}

/// What the element API said about one window.
struct RawWindow: Sendable {
    var number: UInt32?
    let title: String
    let role: String?
    let subrole: String?
    let isMinimised: Bool
    let isFullScreen: Bool
    /// Top-left origin, in global display points, as the window list reports bounds.
    let frame: CGRect?
}

/// One entry of the window server's window list.
struct ListedWindow: Sendable {
    let number: UInt32
    let frame: CGRect
    /// nil without Screen Recording, which the window list needs to name windows.
    let name: String?
}
