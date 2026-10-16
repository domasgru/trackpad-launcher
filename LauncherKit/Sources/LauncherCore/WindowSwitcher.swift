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

    public var app: AppEntry? {
        if case .app(let entry, _, _) = self { entry } else { nil }
    }
}

/// The window switcher during one window swipe. Its content is fixed when the window swipe begins: a window that opens
/// later is not added, and one that closes stays listed. The selection follows the travel.
public struct WindowSwitcher: Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        case windows(of: AppEntry, WindowList)
        /// "No open windows", with the app's icon when there is a frontmost app.
        case noWindows(of: AppEntry?)
        /// "Allow Accessibility to switch windows", with the frontmost app's icon.
        case accessibilityNeeded(for: AppEntry?)
    }

    /// At most `GestureRules.windowSwitcherMaxRows` windows in all.
    public enum WindowList: Equatable, Sendable {
        /// The front window, the other visible windows front to back, then the minimised ones in the app's order.
        /// A full-screen front window is alone.
        case front(AppWindow, others: [AppWindow], minimised: [AppWindow])
        /// Every listed window is minimised: there is no front window.
        case minimisedOnly(first: AppWindow, rest: [AppWindow])
    }

    public enum Row: Equatable, Sendable {
        /// Its preview, or the app icon until the preview is ready, and its title.
        case visible(WindowID, title: String)
        /// Dimmed, with the app icon, its title and the "Minimised" badge.
        case minimised(WindowID, title: String)
        /// The single row of a window switcher with nothing to switch.
        case message(String)

        public var window: WindowID? {
            switch self {
            case .visible(let id, _), .minimised(let id, _): id
            case .message: nil
            }
        }

        public var title: String {
            switch self {
            case .visible(_, let title), .minimised(_, let title), .message(let title): title
            }
        }
    }

    public let content: Content
    public package(set) var selection: SwitcherSelection
    /// The window swipes since launch. Tells one window swipe's switcher from the next, so the presenter lays out
    /// once per window swipe and nothing taken for one ever shows in another.
    public let serial: Int
    public let trackpad: TrackpadID

    /// The selection counts the rows (one for a message) and starts on the first row.
    package init(_ content: Content, serial: Int, trackpad: TrackpadID) {
        self.content = content
        self.serial = serial
        self.trackpad = trackpad
        selection = SwitcherSelection(count: Self.rows(of: content).count)
    }

    /// Whose windows these are and whose icon the rows show. nil: no frontmost app.
    public var app: AppEntry? {
        switch content {
        case .windows(let app, _): app
        case .noWindows(let app), .accessibilityNeeded(let app): app
        }
    }

    /// Top to bottom. A window titled "" reads as the app's name, plus " — Window N" when there is more than one row,
    /// N its 1-based row.
    public var rows: [Row] { Self.rows(of: content) }

    private static func rows(of content: Content) -> [Row] {
        switch content {
        case .noWindows: return [.message(Copy.noOpenWindows)]
        case .accessibilityNeeded: return [.message(Copy.accessibilityForWindows)]
        case .windows(let app, let list):
            let visible: [AppWindow]
            let minimised: [AppWindow]
            switch list {
            case .front(let front, let others, let rest):
                visible = [front] + others
                minimised = rest
            case .minimisedOnly(let first, let rest):
                visible = []
                minimised = [first] + rest
            }
            let count = visible.count + minimised.count
            func title(_ window: AppWindow, at index: Int) -> String {
                window.title.isEmpty
                    ? Copy.untitledWindow(of: app.name, position: index + 1, rows: count) : window.title
            }
            let visibleRows = visible.enumerated().map { Row.visible($1.id, title: title($1, at: $0)) }
            let minimisedRows = minimised.enumerated().map {
                Row.minimised($1.id, title: title($1, at: visible.count + $0))
            }
            return visibleRows + minimisedRows
        }
    }

    /// The app's window in front when the window swipe began. nil when every window is minimised, or for a message.
    public var frontWindow: WindowID? {
        if case .windows(_, .front(let front, _, _)) = content { front.id } else { nil }
    }

    /// Windows are listed, so a lift can change something. false for a message.
    public var listsWindows: Bool {
        if case .windows = content { true } else { false }
    }
}

extension WindowSwitcher.Content {
    /// The one parse from what the system read to what the switcher lists:
    /// - `.noApp`, or an app with no windows, reads as `.noWindows`.
    /// - A full-screen front window is the single row; other full-screen windows are left out.
    /// - Visible windows come before minimised ones, and the list is cut at `GestureRules.windowSwitcherMaxRows`.
    package init(_ read: FrontmostWindows) {
        guard case .app(let app, let visible, let minimised) = read else {
            self = .noWindows(of: nil)
            return
        }
        let limit = GestureRules.windowSwitcherMaxRows
        if let front = visible.first {
            if front.isFullScreen {
                self = .windows(of: app, .front(front, others: [], minimised: []))
                return
            }
            let others = Array(visible.dropFirst().filter { !$0.isFullScreen }.prefix(limit - 1))
            self = .windows(
                of: app, .front(front, others: others, minimised: Array(minimised.prefix(limit - 1 - others.count))))
        } else if let first = minimised.first {
            self = .windows(of: app, .minimisedOnly(first: first, rest: Array(minimised.dropFirst().prefix(limit - 1))))
        } else {
            self = .noWindows(of: app)
        }
    }
}
