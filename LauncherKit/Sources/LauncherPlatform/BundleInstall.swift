import AppleArchive
import Foundation
import System

/// Every unprivileged file operation of moving this app into /Applications or updating it there, over URLs a test points
/// at temp folders. This file holds every unprivileged one; the administrator path's moves are `PrivilegedInstall`'s
/// script.
enum BundleInstall {
    private static let quarantine = "com.apple.quarantine"
    /// The one bundle an update archive holds: a contract with every shipped version. It is not the installed copy's
    /// name; an update goes over this copy, whatever it is named.
    private static let archivedBundleName = "TrackpadLauncher.app"

    /// A fresh temporary folder on the volume of `destination`.
    private static func newFolder(near destination: URL) throws -> URL {
        let files = FileManager.default
        let anchor = files.fileExists(atPath: destination.path) ? destination : destination.deletingLastPathComponent()
        return try files.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: anchor, create: true)
    }

    /// The archive through a byte stream over memory, so no file holds it. The selection hook sees each entry before
    /// it is written; the first refused one cancels, which ends the extraction with an error.
    private static func extract(_ archive: Data, into folder: URL) throws {
        guard let raw = ArchiveByteStream.customStream(instance: MemoryStream(archive)),
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
        let kind: ArchiveEntryKind =
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

    /// A copy of `source` in a fresh temporary folder on the volume of `destination`, with the quarantine cleared on
    /// every item (a copy that carries none is never translocated). Nothing at `destination` changes.
    static func stage(_ source: URL, near destination: URL) throws -> URL {
        let files = FileManager.default
        let folder = try newFolder(near: destination)
        let staged = folder.appending(path: destination.lastPathComponent)
        do {
            try files.copyItem(at: source, to: staged)
            try clearQuarantine(under: staged)
        } catch {
            discard(staged)
            throw error
        }
        return staged
    }

    /// `archive` unpacked from memory into a fresh item-replacement folder on `destination`'s volume; returns the bundle
    /// in it. Every entry is checked before it is written (`admits`); the first refused entry cancels the extraction and
    /// the folder is discarded. Quarantine is cleared on every item. Nothing at `destination` changes.
    static func unpack(_ archive: Data, near destination: URL) throws -> URL {
        let files = FileManager.default
        let folder = try newFolder(near: destination)
        do {
            try extract(archive, into: folder)
            let bundle = folder.appending(path: archivedBundleName)
            guard files.fileExists(atPath: bundle.path) else { throw CocoaError(.fileReadCorruptFile) }
            try clearQuarantine(under: bundle)
            return bundle
        } catch {
            try? files.removeItem(at: folder)
            throw error
        }
    }

    /// Pure: a relative path equal to or under "TrackpadLauncher.app/", with no ".." and no leading "/"; a directory, a
    /// regular file, or a symbolic link whose target, resolved from the link's folder, stays strictly inside the
    /// bundle. Anything else is refused.
    static func admits(path: String, kind: ArchiveEntryKind, linkTarget: String?) -> Bool {
        guard !path.hasPrefix("/") else { return false }
        let parts = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard parts.first == archivedBundleName, !parts.contains(".."), !parts.contains(".") else { return false }
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

    /// Puts `staged` at `destination` in one step: when something lies there, the kernel exchanges the two directory
    /// entries (`RENAME_SWAP`, atomic by contract, so a crash at any instant leaves one whole copy there) and the old
    /// copy, now at `staged`, is discarded; when nothing does, a move. Throws with `destination` untouched.
    static func swap(_ staged: URL, into destination: URL) throws {
        let files = FileManager.default
        if files.fileExists(atPath: destination.path) {
            guard renamex_np(staged.path, destination.path, UInt32(RENAME_SWAP)) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        } else {
            try files.moveItem(at: staged, to: destination)
        }
        discard(staged)
    }

    /// Removes a staged copy and the temporary folder it was made in. Leftovers do not matter: nothing throws.
    static func discard(_ staged: URL) {
        let files = FileManager.default
        try? files.removeItem(at: staged)
        let folder = staged.deletingLastPathComponent()
        if (try? files.contentsOfDirectory(atPath: folder.path))?.isEmpty == true {
            try? files.removeItem(at: folder)
        }
    }

    /// Removes the copy the user opened. A folder that cannot be written (a read-only share) leaves it whole: deleting
    /// the inside of a bundle whose own removal then fails would leave a broken copy. A failure is tolerated.
    static func removeOriginal(_ original: URL) {
        guard FileManager.default.isDeletableFile(atPath: original.path) else { return }
        try? FileManager.default.removeItem(at: original)
    }

    /// Without following symlinks: a link's own mark goes, never its target's.
    private static func clearQuarantine(under root: URL) throws {
        let files = FileManager.default
        var items = [root]
        if let walker = files.enumerator(at: root, includingPropertiesForKeys: nil) {
            items += walker.compactMap { $0 as? URL }
        }
        for item in items where removexattr(item.path, quarantine, XATTR_NOFOLLOW) != 0 && errno != ENOATTR {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: item.path])
        }
    }
}

enum ArchiveEntryKind { case directory, file, symbolicLink, other }

/// Reads an archive held in memory, one buffer at a time.
private final class MemoryStream: ArchiveByteStreamProtocol {
    private let data: Data
    private var offset = 0

    init(_ data: Data) { self.data = data }

    func read(into buffer: UnsafeMutableRawBufferPointer) throws -> Int {
        let count = try read(into: buffer, atOffset: Int64(offset))
        offset += count
        return count
    }

    func read(into buffer: UnsafeMutableRawBufferPointer, atOffset at: Int64) throws -> Int {
        let start = Int(at)
        let count = min(buffer.count, data.count - start)
        guard count > 0 else { return 0 }
        data.withUnsafeBytes { source in
            buffer.copyMemory(from: UnsafeRawBufferPointer(rebasing: source[start..<start + count]))
        }
        return count
    }

    func write(from buffer: UnsafeRawBufferPointer) throws -> Int { throw Errno.badFileDescriptor }
    func write(from buffer: UnsafeRawBufferPointer, atOffset offset: Int64) throws -> Int { throw Errno.badFileDescriptor }
    func seek(toOffset: Int64, relativeTo: FileDescriptor.SeekOrigin) throws -> Int64 { throw Errno.illegalSeek }
    func cancel() {}
    func close() throws {}
}
