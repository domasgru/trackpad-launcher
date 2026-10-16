import Foundation

/// How raising windows one at a time, each to the front of its app, reaches an order.
public enum WindowStack {
    /// The shortest front part of `target` (front to back) that, raised back to front, leaves the target windows on
    /// screen in `target` order among themselves, with the first in front of every window of the app. `current`: the
    /// app's visible windows now, front to back, including any that opened since the begin. The first target window is
    /// part of it unless it already leads `current`, so a minimised first window is restored and one opened mid-swipe
    /// is passed; target windows not in `current` other than the first (minimised) are left out, so a later minimised
    /// window is never restored. A window not in `target` keeps its place among the windows not raised, so one opened
    /// mid-swipe in front ends just behind the raised ones. Empty when the order already holds. Total: the whole target
    /// always qualifies.
    public static func raises(current: [WindowID], target: [WindowID]) -> [WindowID] {
        guard let first = target.first else { return [] }
        let onScreen = Set(current)
        let target = [first] + target.dropFirst().filter { onScreen.contains($0) }
        let targeted = Set(target)
        let start = current.first == first ? 0 : 1
        for count in start...target.count {
            let raised = Set(target.prefix(count))
            let unraised = current.filter { targeted.contains($0) && !raised.contains($0) }
            if unraised[...] == target.dropFirst(count) { return Array(target.prefix(count)) }
        }
        return target
    }
}

/// What the lift does: `raises` front to back (the first ends in front with the keyboard focus), and whether the
/// gesture haptic plays.
public struct WindowLift: Equatable, Sendable {
    public let raises: [WindowID]
    public let playsHaptic: Bool

    public init(raises: [WindowID], playsHaptic: Bool) {
        self.raises = raises
        self.playsHaptic = playsHaptic
    }

    public static let nothing = WindowLift(raises: [], playsHaptic: false)
}

extension WindowSwitcher {
    /// The lift, from the rows fixed at begin and a second read of the frontmost app's windows. Pure.
    /// - `now` is no app or another app: no raises, silent.
    /// - The selected window has closed: no raises, so no reordering; the haptic plays iff a window is in front now
    ///   and it is not `frontWindow`. Every listed window closed is therefore silent.
    /// - Otherwise the target is the selected window, then the visible windows in their begin order (the front window
    ///   first) without it, minus any that closed; the haptic plays iff the selected window is not `frontWindow`,
    ///   which covers restoring a minimised one and every row when every window is minimised. Lifting on the front
    ///   window therefore restores the begin order, silently.
    public func lift(now: FrontmostWindows) -> WindowLift {
        guard case .app(let nowApp, let visible, let minimised) = now, nowApp.url == app.url else { return .nothing }
        let selected = rows[selection.selected].window
        let onScreen = visible.map(\.id)
        let open = Set(onScreen + minimised.map(\.id))
        guard open.contains(selected) else {
            return WindowLift(raises: [], playsHaptic: onScreen.first.map { $0 != frontWindow } ?? false)
        }
        let visibleAtBegin = rows.compactMap { row -> WindowID? in
            if case .visible(let id, _) = row { id } else { nil }
        }
        let target = [selected] + visibleAtBegin.filter { $0 != selected && open.contains($0) }
        return WindowLift(
            raises: WindowStack.raises(current: onScreen, target: target), playsHaptic: selected != frontWindow)
    }
}
