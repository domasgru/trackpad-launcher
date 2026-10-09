import Foundation

/// MultitouchSupport device ID (equal to the IORegistry "Multitouch ID").
public struct TrackpadID: Hashable, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

/// macOS keeps trackpad settings per kind: one domain for the built-in, one shared by all external trackpads.
public enum TrackpadKind: Hashable, Sendable, CaseIterable { case builtIn, external }

public struct Trackpad: Hashable, Sendable, Identifiable {
    public let id: TrackpadID
    public let kind: TrackpadKind
    public let surface: SurfaceSize

    public init(id: TrackpadID, kind: TrackpadKind, surface: SurfaceSize) {
        self.id = id
        self.kind = kind
        self.surface = surface
    }
}
