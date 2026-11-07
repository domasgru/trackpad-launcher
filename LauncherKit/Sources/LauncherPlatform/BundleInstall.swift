import Foundation

/// Every unprivileged file operation of moving this app into /Applications, over URLs a test points
/// at temp folders. This file holds every unprivileged one; the administrator path's moves are `PrivilegedInstall`'s
/// script.
enum BundleInstall {
    private static let quarantine = "com.apple.quarantine"
    /// A fresh temporary folder on the volume of `destination`.
    private static func newFolder(near destination: URL) throws -> URL {
        let files = FileManager.default
        let anchor = files.fileExists(atPath: destination.path) ? destination : destination.deletingLastPathComponent()
        return try files.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: anchor, create: true)
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
