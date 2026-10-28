import Foundation

public enum Build: Equatable, Sendable {
    case release
    /// Not signed with a Developer ID: Xcode, the perf build, an ad-hoc binary. Never `#if DEBUG`.
    case development
}

public struct DiskImage: Hashable, Sendable {
    public let volume: URL
    public init(volume: URL) { self.volume = volume }
}

/// Where this copy lies, read once at start.
public struct Location: Equatable, Sendable {
    /// `Bundle.main.bundleURL`: a hidden translocation mount when macOS translocated a quarantined copy.
    public let running: URL
    /// The bundle the user opened, where Finder shows it; `running` when not translocated.
    public let original: URL
    /// What macOS says, stored: never inferred by comparing two spellings of a URL.
    public let isTranslocated: Bool
    /// The disk image `original` lies on; nil anywhere else.
    public let diskImage: DiskImage?

    public init(running: URL, original: URL, isTranslocated: Bool, diskImage: DiskImage?) {
        self.running = running
        self.original = original
        self.isTranslocated = isTranslocated
        self.diskImage = diskImage
    }
}

/// Where this copy stands for an opening by hand. One rule, pure.
public enum Placement: Equatable, Sendable {
    /// Inside /Applications, at any depth, not translocated, whatever the build: its first run starts it at login.
    case installed
    /// A development build anywhere else: it runs where it was built and leaves starting at login alone.
    case development
    /// A release build anywhere else: a disk image, ~/Downloads, ~/Applications, a translocated copy.
    case elsewhere

    public init(build: Build, location: Location, applications: URL = URL(filePath: "/Applications")) {
        if !location.isTranslocated, Self.isInside(location.running, applications) {
            self = .installed
        } else if build == .development {
            self = .development
        } else {
            self = .elsewhere
        }
    }

    /// Component-wise on standardized paths: `/ApplicationsOld` is not inside, `..` is resolved, a trailing slash
    /// never matters.
    private static func isInside(_ url: URL, _ folder: URL) -> Bool {
        let path = url.standardizedFileURL.pathComponents
        let root = folder.standardizedFileURL.pathComponents
        return path.count > root.count && Array(path.prefix(root.count)) == root
    }
}
