import Foundation

/// A display, by the window server's number, as `WindowID` wraps a window's. No frame crosses the port.
public struct DisplayID: Hashable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}

/// "The left half of that display's usable area"; the adapter works out the rectangle when it places.
public struct ScreenHalf: Equatable, Sendable {
    public let side: SplitSide
    public let display: DisplayID
    public init(side: SplitSide, display: DisplayID) {
        self.side = side
        self.display = display
    }
}

/// The latest split gesture's windows that may still be placed. At most one: every gesture that is not silent clears it
/// before deciding.
struct SplitPlacing: Equatable, Sendable {
    let first: BundleID
    let second: BundleID
    let display: DisplayID

    func half(of app: BundleID) -> ScreenHalf? {
        if app == first { return ScreenHalf(side: .left, display: display) }
        if app == second { return ScreenHalf(side: .right, display: display) }
        return nil
    }
}
