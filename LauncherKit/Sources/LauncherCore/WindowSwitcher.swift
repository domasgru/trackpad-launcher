import Foundation

/// The window server's number for one window: the one number the Accessibility API, the window list and screen
/// capture all report, stable for the window's life.
public struct WindowID: Hashable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) { self.rawValue = rawValue }
}

/// One of an app's normal document or app windows, as one read found it.
public struct AppWindow: Equatable, Sendable, Identifiable {
    public let id: WindowID
    /// As the app titles it; "" when it has no title.
    public let title: String
    public let isFullScreen: Bool

    public init(id: WindowID, title: String, isFullScreen: Bool = false) {
        self.id = id
        self.title = title
        self.isFullScreen = isFullScreen
    }
}

/// One read of the frontmost app's windows.
public enum FrontmostWindows: Equatable, Sendable {
    /// There is no active app, or it is Trackpad Launcher itself.
    case noApp
    /// `visible`: its windows on the current Space, front to back; panels, palettes, sheets and other helpers left
    /// out. `minimised`: its minimised windows, in the order the app lists them. Both empty when it has none, when
    /// Accessibility is missing, or when the app did not answer in time.
    case app(AppEntry, visible: [AppWindow], minimised: [AppWindow])
}

/// The window switcher during one window swipe. Its content is fixed when the window swipe begins: a window that opens
/// later is not added, and one that closes stays listed. The selection follows the travel.
public struct WindowSwitcher: Equatable, Sendable {
    /// What a window swipe lists: the frontmost app and two to ten of its windows. One exists only for a window swipe.
    public struct Content: Equatable, Sendable {
        /// Whose windows these are; their rows show its icon.
        public let app: AppEntry
        public let windows: WindowList
    }

    /// Two to `GestureRules.windowSwitcherMaxRows` windows in all.
    public enum WindowList: Equatable, Sendable {
        /// The front window, the other visible windows front to back, then the minimised ones in the app's order.
        case front(AppWindow, others: [AppWindow], minimised: [AppWindow])
        /// Every listed window is minimised: there is no front window.
        case minimisedOnly(first: AppWindow, rest: [AppWindow])
    }

    public enum Row: Equatable, Sendable {
        /// Its preview, or the app icon until the preview is ready, and its title.
        case visible(WindowID, title: String)
        /// Dimmed, with the app icon, its title and the "Minimised" badge.
        case minimised(WindowID, title: String)

        public var window: WindowID {
            switch self {
            case .visible(let id, _), .minimised(let id, _): id
            }
        }

        public var title: String {
            switch self {
            case .visible(_, let title), .minimised(_, let title): title
            }
        }
    }

    public let content: Content
    public package(set) var selection: SwitcherSelection
    /// The window swipes since launch. Tells one window swipe's switcher from the next, so the presenter lays out
    /// once per window swipe and nothing taken for one ever shows in another.
    public let serial: Int
    public let trackpad: TrackpadID
    /// Screen Recording was granted when the window swipe began, so visible rows show previews.
    public let showsPreviews: Bool

    /// The selection counts the rows (two to ten) and starts on the first row.
    package init(_ content: Content, showsPreviews: Bool, serial: Int, trackpad: TrackpadID) {
        self.content = content
        self.showsPreviews = showsPreviews
        self.serial = serial
        self.trackpad = trackpad
        selection = SwitcherSelection(count: Self.rows(of: content).count)
    }

    /// Whose windows these are and whose icon the rows show.
    public var app: AppEntry { content.app }

    /// Top to bottom, two to ten. A window titled "" reads as the app's name followed by " — Window N", N its 1-based
    /// row.
    public var rows: [Row] { Self.rows(of: content) }

    private static func rows(of content: Content) -> [Row] {
        let visible: [AppWindow]
        let minimised: [AppWindow]
        switch content.windows {
        case .front(let front, let others, let rest):
            visible = [front] + others
            minimised = rest
        case .minimisedOnly(let first, let rest):
            visible = []
            minimised = [first] + rest
        }
        func title(_ window: AppWindow, at index: Int) -> String {
            window.title.isEmpty ? Copy.untitledWindow(of: content.app.name, position: index + 1) : window.title
        }
        let visibleRows = visible.enumerated().map { Row.visible($1.id, title: title($1, at: $0)) }
        let minimisedRows = minimised.enumerated().map {
            Row.minimised($1.id, title: title($1, at: visible.count + $0))
        }
        return visibleRows + minimisedRows
    }

    /// The windows to capture: the visible rows while `showsPreviews`, else none.
    public var previewWindows: [WindowID] {
        guard showsPreviews else { return [] }
        return rows.compactMap { if case .visible(let id, _) = $0 { id } else { nil } }
    }

    /// The app's window in front when the window swipe began. nil when every listed window is minimised.
    public var frontWindow: WindowID? {
        if case .front(let front, _, _) = content.windows { front.id } else { nil }
    }

    /// The window that comes to the front while its row is selected. nil on a minimised row.
    public var selectedVisibleWindow: WindowID? {
        if case .visible(let id, _) = rows[selection.selected] { id } else { nil }
    }
}

extension WindowSwitcher.Content {
    /// The one parse from what the system read to what the switcher lists, and so whether a slide up or down is a
    /// window swipe at all:
    /// - A full-screen front window is the single row; other full-screen windows are left out.
    /// - Visible windows come before minimised ones, and the list is cut at `GestureRules.windowSwitcherMaxRows`.
    /// - nil for `.noApp`, and for fewer than two rows after these rules: one window, an only window minimised, no
    ///   windows, a full-screen front window, or an app that did not answer (its read lists nothing).
    package init?(_ read: FrontmostWindows) {
        guard case .app(let app, let visible, let minimised) = read else { return nil }
        let limit = GestureRules.windowSwitcherMaxRows
        let windows: WindowSwitcher.WindowList
        let count: Int
        if let front = visible.first {
            guard !front.isFullScreen else { return nil }
            let others = Array(visible.dropFirst().filter { !$0.isFullScreen }.prefix(limit - 1))
            let rest = Array(minimised.prefix(limit - 1 - others.count))
            windows = .front(front, others: others, minimised: rest)
            count = 1 + others.count + rest.count
        } else if let first = minimised.first {
            let rest = Array(minimised.dropFirst().prefix(limit - 1))
            windows = .minimisedOnly(first: first, rest: rest)
            count = 1 + rest.count
        } else {
            return nil
        }
        guard count >= 2 else { return nil }
        self.init(app: app, windows: windows)
    }
}
