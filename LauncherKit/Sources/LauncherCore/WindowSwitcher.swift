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

/// The window switcher during one window swipe. Its content is fixed when the window swipe begins: a window that opens
/// later is not added, and one that closes stays listed. The selection follows the travel.
public struct WindowSwitcher: Equatable, Sendable {
    /// What a window swipe lists: the frontmost app and two to ten of its windows. One exists only for a window swipe.
    public struct Content: Equatable, Sendable {
        /// Whose windows these are; their rows show its icon.
        public let app: AppEntry
        public let rows: Rows
    }

    public struct Rows: Equatable, Sendable {
        /// Top to bottom, in the app's window order. A window titled "" reads as the app's name followed by
        /// " — Window N", N its 1-based row; any other title reads as the app's title rule words it
        /// (`WindowTitleRule`), which never sees the fallback.
        public let rows: [Row]
        /// The app's window in front when the window swipe began; nil when every listed window is minimised.
        public let frontWindow: WindowID?
        /// The listed visible windows, front to back, at the start: a lift restores this order behind the selected
        /// window. Kept apart from the row order, which no longer follows the z-order.
        let zOrder: [WindowID]

        /// The pick sorted by `order`, every picked window being in it; a row is `.visible` for a picked visible
        /// window and `.minimised` for a picked minimised one.
        init(app: AppEntry, pick: WindowPick, order: [WindowID]) {
            let position = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            let visible = Set(pick.zOrder)
            let sorted = pick.windows.sorted { (position[$0.id] ?? .max) < (position[$1.id] ?? .max) }
            rows = sorted.enumerated().map { index, window in
                let title = window.title.isEmpty
                    ? Copy.untitledWindow(of: app.name, position: index + 1)
                    : WindowTitleRule.displayTitle(window.title, of: app.bundleID)
                return visible.contains(window.id)
                    ? Row.visible(window.id, title: title) : Row.minimised(window.id, title: title)
            }
            frontWindow = pick.front?.id
            zOrder = pick.zOrder
        }

        /// The front window's row; 0 when there is none.
        var startRow: Int { frontWindow.flatMap { front in rows.firstIndex { $0.window == front } } ?? 0 }
    }

    public enum Row: Equatable, Sendable {
        /// Its preview, or the app icon when it has none, and its title.
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

    /// The selection counts the rows (two to ten) and starts on the front window's row.
    package init(_ content: Content, showsPreviews: Bool, serial: Int, trackpad: TrackpadID) {
        self.content = content
        self.showsPreviews = showsPreviews
        self.serial = serial
        self.trackpad = trackpad
        selection = SwitcherSelection(count: content.rows.rows.count, startingAt: content.rows.startRow)
    }

    /// Whose windows these are and whose icon the rows show.
    public var app: AppEntry { content.app }

    /// Top to bottom, two to ten, in the app's window order.
    public var rows: [Row] { content.rows.rows }

    /// The windows to capture: the visible rows while `showsPreviews`, else none.
    public var previewWindows: [WindowID] {
        guard showsPreviews else { return [] }
        return rows.compactMap { if case .visible(let id, _) = $0 { id } else { nil } }
    }

    /// The app's window in front when the window swipe began. nil when every listed window is minimised.
    public var frontWindow: WindowID? { content.rows.frontWindow }

    /// The window that comes to the front while its row is selected. nil on a minimised row.
    public var selectedVisibleWindow: WindowID? {
        if case .visible(let id, _) = rows[selection.selected] { id } else { nil }
    }
}
