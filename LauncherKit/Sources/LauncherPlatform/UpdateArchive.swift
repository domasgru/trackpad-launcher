import AppleArchive
import Foundation
import System

/// The downloaded update archive: expanded into a scratch folder just long enough for the signature check, and removed
/// when the check refuses it. The rules for what an archive may hold are a copy of the card contract's, kept apart on
/// purpose: that one is frozen for every shipped version, this one may move with the app.
enum UpdateArchive {
    /// The one bundle an update archive holds.
    static let bundleName = "TrackpadLauncher.app"

    /// `body` runs on the one bundle the archive holds, expanded into a fresh scratch folder that is gone when this
    /// returns. nil: the archive is unreadable, holds anything else than that bundle, or has none.
    static func withExpandedBundle<Result>(of archive: URL, _ body: (URL) -> Result) -> Result? {
        let files = FileManager.default
        guard
            let scratch = try? files.url(
                for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: archive, create: true)
        else { return nil }
        defer { try? files.removeItem(at: scratch) }
        guard (try? extract(archive, into: scratch)) != nil else { return nil }
        let bundle = scratch.appending(path: bundleName)
        guard files.fileExists(atPath: bundle.path) else { return nil }
        return body(bundle)
    }

    /// Whether the archive holds the release the feed offered. A refused archive is removed, so Sparkle's own
    /// extraction fails and no installer ever exists for it.
    static func admit(_ archive: URL, as offer: ExpectedUpdate, signer: Signer) -> Bool {
        let genuine =
            withExpandedBundle(of: archive) { CodeSignature.isGenuine($0, as: offer, signer: signer) } ?? false
        if !genuine { try? FileManager.default.removeItem(at: archive) }
        return genuine
    }

    /// Every entry is checked before it is written; the first refused one cancels, which ends the extraction with an
    /// error.
    private static func extract(_ archive: URL, into folder: URL) throws {
        guard let raw = ArchiveByteStream.fileStream(path: FilePath(archive.path), mode: .readOnly, options: [], permissions: []),
            let decompressed = ArchiveByteStream.decompressionStream(readingFrom: raw),
            let decoded = ArchiveStream.decodeStream(readingFrom: decompressed),
            let extractor = ArchiveStream.extractStream(
                extractingTo: FilePath(folder.path),
                selectUsing: { message, path, data in
                    guard message == .extractBegin else { return .ok }
                    return admitted(path: path.string, data: data) ? .ok : .cancel
                }, flags: [.ignoreOperationNotPermitted])
        else { throw CocoaError(.fileReadCorruptFile) }
        defer {
            try? extractor.close()
            try? decoded.close()
            try? decompressed.close()
            try? raw.close()
        }
        _ = try ArchiveStream.process(readingFrom: decoded, writingTo: extractor)
    }

    private static func admitted(path: String, data: ArchiveHeader.EntryFilterData?) -> Bool {
        guard case .header(let header)? = data, let type = header.entryType else { return false }
        let kind: EntryKind =
            switch type {
            case .directory: .directory
            case .regularFile: .file
            case .link: .symbolicLink
            default: .other
            }
        var target: String?
        if case .string(_, let value)? = header.field(forKey: ArchiveHeader.FieldKey("LNK")) { target = value }
        return admits(path: path, kind: kind, linkTarget: target)
    }

    enum EntryKind { case directory, file, symbolicLink, other }

    /// Pure: a relative path equal to or under "TrackpadLauncher.app/", with no ".." and no leading "/"; a directory, a
    /// regular file, or a symbolic link whose target, resolved from the link's folder, stays strictly inside the
    /// bundle. Anything else is refused.
    static func admits(path: String, kind: EntryKind, linkTarget: String?) -> Bool {
        guard !path.hasPrefix("/") else { return false }
        let parts = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard parts.first == bundleName, !parts.contains(".."), !parts.contains(".") else { return false }
        switch kind {
        case .directory, .file: return true
        case .other: return false
        case .symbolicLink:
            guard let linkTarget, !linkTarget.isEmpty, !linkTarget.hasPrefix("/") else { return false }
            var resolved = Array(parts.dropLast())
            for step in linkTarget.split(separator: "/", omittingEmptySubsequences: true) {
                switch step {
                case ".": continue
                case "..":
                    guard resolved.count > 1 else { return false }
                    resolved.removeLast()
                default: resolved.append(String(step))
                }
            }
            return resolved.count > 1
        }
    }
}
