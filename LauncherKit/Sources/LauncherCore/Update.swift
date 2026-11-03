import Foundation

/// A published full release that carries an app and declares the macOS it needs. Built only by the release list's
/// adapter: a draft, a pre-release, an asset still uploading, or a release without a well-named archive never becomes
/// one.
public struct Release: Equatable, Sendable {
    public let version: Version
    public let minimumMacOS: Version
    /// Where the app's archive downloads from: this repository's release downloads.
    public let archive: URL
    /// The archive's size as the list declares it: the progress denominator and the exact expected length.
    public let archiveSize: Int

    public init(version: Version, minimumMacOS: Version, archive: URL, archiveSize: Int) {
        self.version = version
        self.minimumMacOS = minimumMacOS
        self.archive = archive
        self.archiveSize = archiveSize
    }

    /// The one rule for what counts as newer: the highest release above `running` whose minimum `macOS` meets; nil when
    /// none.
    public static func newerVersion(in releases: [Release], than running: Version, on macOS: Version) -> Release? {
        releases.filter { $0.version > running && $0.minimumMacOS <= macOS }.max { $0.version < $1.version }
    }
}

/// The running copy as an update check sees it. The gate, whole: exists only for a copy truly signed with a Developer
/// ID, in /Applications (`Placement.installed`), whose version the adapter could read (`version` nil when it could
/// not). The composition root and the tests call this one rule. Read once at start: after a swap, `Bundle.main` would
/// read the new bundle.
public struct InstalledRelease: Equatable, Sendable {
    public let version: Version
    public let macOS: Version

    public init?(placement: Placement, developerIDSigned: Bool, version: Version?, macOS: Version) {
        guard developerIDSigned, placement == .installed, let version else { return nil }
        self.version = version
        self.macOS = macOS
    }
}

/// What an update reports, in this order: any `.progress`; then `.failed`, or `.downloaded` followed by exactly one of
/// `.installed`, `.declined`, `.failed`.
public enum UpdateEvent: Equatable, Sendable {
    /// 0...1 of the archive received, in whole percents.
    case progress(Double)
    /// The whole archive arrived. From here on nothing cancels the update.
    case downloaded
    /// /Applications holds the new version.
    case installed
    /// The administrator prompt was cancelled; nothing changed.
    case declined
    /// Nothing changed: the download failed, stalled or had the wrong length; the archive held something else; the
    /// app was not genuine; or the swap failed.
    case failed
}

/// The update card, the settings window's first group while a newer version is known. Not dismissable.
public enum UpdateCard: Equatable, Sendable {
    /// "Version 1.1.0 is available" · *Update now*
    case available(Version)
    /// "Downloading version 1.1.0…" · a bar at `progress` (0...1) · *Cancel*. The only state with *Cancel*.
    case downloading(Version, progress: Double)
    /// "Installing version 1.1.0…": no bar, no *Cancel*; *Quit Trackpad Launcher* is disabled.
    case installing(Version)
    /// "The update couldn't be installed." · *Try again*
    case failed(Version)

    /// The card with its progress erased: what decides its height, so the window refits when the card appears, goes or
    /// changes state, never on a progress push.
    public enum Layout: Equatable, Sendable { case available, downloading, installing, failed }

    public var layout: Layout {
        switch self {
        case .available: .available
        case .downloading: .downloading
        case .installing: .installing
        case .failed: .failed
        }
    }
}
