import Foundation

/// The thumb corners this Mac has. It has an External trackpad corner exactly when it has mixed trackpads: a built-in
/// and an external trackpad were once connected at the same time. Until then one corner serves every trackpad of
/// either kind. Every "which corner" rule lives here; recognition, the window's rows and its illustrations read answers.
public enum ThumbCorners: Equatable, Sendable {
    /// No mixed trackpads: the single *Thumb corner* row; its corner is the MacBook trackpad corner, saved in `settings`.
    case single(ThumbCorner)
    /// Mixed trackpads: the *MacBook trackpad* and *External trackpad* rows.
    case perKind(macBook: ThumbCorner, external: ThumbCorner)

    /// The External corner a Mac gets the moment it has mixed trackpads, upgraders included.
    static let defaultExternal: ThumbCorner = .bottomLeft

    /// From the two saved facts: the record's corner, and the External corner, nil until mixed.
    init(macBook: ThumbCorner, external: ThumbCorner?) {
        self = external.map { .perKind(macBook: macBook, external: $0) } ?? .single(macBook)
    }

    /// Whether these kinds, connected at the same time, give the Mac mixed trackpads. A Magic Mouse is no kind,
    /// and a Mac with no built-in trackpad never qualifies.
    static func areMixed(_ connected: Set<TrackpadKind>) -> Bool { connected.isSuperset(of: [.builtIn, .external]) }

    /// One row or two: the only corner fact that changes the window's height.
    public var hasMixedTrackpads: Bool { if case .perKind = self { true } else { false } }

    /// The corner a trackpad of this kind anchors the thumb in. Total.
    public func corner(for kind: TrackpadKind) -> ThumbCorner {
        switch (self, kind) {
        case (.single(let corner), _): corner
        case (.perKind(let macBook, _), .builtIn): macBook
        case (.perKind(_, let external), .external): external
        }
    }

    /// The corner every illustration draws: an external trackpad's while one is connected, else the built-in's,
    /// none connected included. Without mixed trackpads both are the one corner.
    func drawn(connected: Set<TrackpadKind>) -> ThumbCorner { corner(for: connected.contains(.external) ? .external : .builtIn) }
}
