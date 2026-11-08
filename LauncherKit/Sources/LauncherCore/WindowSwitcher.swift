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
    /// What a window swipe lists: the frontmost app and either two to ten of its windows or the no-windows card.
    /// One exists only for a window swipe.
    public struct Content: Equatable, Sendable {
        /// Whose windows these are; their rows and the card show its icon.
        public let app: AppEntry
        public let list: List
    }

    public enum List: Equatable, Sendable {
        /// Two to ten windows, in the app's window order.
        case rows(Rows)
        /// Zero or one window: the no-windows card in place of the rows.
        case card(NoWindowsCard)
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

    /// Rows: the selection counts them (two to ten) and starts on the front window's row. The card: one item, so it
    /// rubber-bands both ways and crosses nothing: no light tick, no raise.
    package init(_ content: Content, showsPreviews: Bool, serial: Int, trackpad: TrackpadID) {
        self.content = content
        self.showsPreviews = showsPreviews
        self.serial = serial
        self.trackpad = trackpad
        selection = switch content.list {
        case .rows(let rows): SwitcherSelection(count: rows.rows.count, startingAt: rows.startRow)
        case .card: SwitcherSelection(count: 1)
        }
    }

    /// Whose windows these are and whose icon the rows or the card show.
    public var app: AppEntry { content.app }

    public var isCard: Bool { if case .card = content.list { true } else { false } }

    /// Top to bottom, two to ten, in the app's window order; [] for the card.
    public var rows: [Row] { if case .rows(let rows) = content.list { rows.rows } else { [] } }

    /// The windows to capture: the visible rows while `showsPreviews`, else none; none for the card.
    public var previewWindows: [WindowID] {
        guard showsPreviews else { return [] }
        return rows.compactMap { if case .visible(let id, _) = $0 { id } else { nil } }
    }

    /// The app's window in front when the window swipe began. nil when every listed window is minimised, and for the
    /// card.
    public var frontWindow: WindowID? { if case .rows(let rows) = content.list { rows.frontWindow } else { nil } }

    /// The window that comes to the front while its row is selected. nil on a minimised row and on the card.
    public var selectedVisibleWindow: WindowID? {
        if case .rows(let list) = content.list, case .visible(let id, _) = list.rows[selection.selected] { id } else { nil }
    }

    /// The card's offset from rest, in points, positive down; nil for rows.
    public var cardOffset: Double? { isCard ? NoWindowsCard.offset(stretch: selection.stretch) : nil }
}

/// The window switcher's single card for an app with zero or one window: the app's icon on the left, a bold first line
/// and a regular second line.
public struct NoWindowsCard: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case noWindows, oneWindow }
    public let kind: Kind
    /// "No open windows" / "No other windows".
    public let title: String
    /// "‹App› has no windows on this desktop." / "‹App› has no other windows on this desktop."
    public let message: String

    package init(_ kind: Kind, of app: AppEntry) {
        self.kind = kind
        switch kind {
        case .noWindows:
            title = Copy.noOpenWindowsTitle
            message = Copy.noOpenWindowsMessage(of: app.name)
        case .oneWindow:
            title = Copy.noOtherWindowsTitle
            message = Copy.noOtherWindowsMessage(of: app.name)
        }
    }

    /// The most the card moves from rest, either way.
    public static let maxOffset = 6.0

    /// `maxOffset × stretch / SwitcherSelection.fullStretch`, within ±`maxOffset`. A one-item selection keeps its travel
    /// within a quarter step of rest and restarts it from a turn, so the offset follows the movement since the last
    /// change of direction, damped by the rubber band's curve, never past 6 pt, and turns at once. Pure.
    public static func offset(stretch: Double) -> Double {
        min(max(maxOffset * stretch / SwitcherSelection.fullStretch, -maxOffset), maxOffset)
    }
}
