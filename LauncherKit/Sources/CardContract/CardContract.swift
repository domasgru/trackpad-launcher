import AppleArchive
import Foundation
import Security
import System

// A frozen copy of what every shipped version's update card demands of a release. The card code it was copied from is
// deleted from the app; these rules must keep running on every future release, and must not move when the app does.
// The duplication is deliberate: do not merge it back, and change nothing here unless a shipped card changed.

/// The card's rules, whole, on one archive file. nil: every shipped card would install it. Otherwise why not, for a person.
public func refusal(ofArchive archive: URL, team: String, identifier: String) -> String? {
    guard let declared = archiveName(archive.lastPathComponent) else {
        return "the file name \(archive.lastPathComponent) is not TrackpadLauncher-<version>-macOS-<minimum>.aar."
    }
    guard let data = try? Data(contentsOf: archive) else { return "the archive cannot be read." }
    let bundle: URL
    do {
        bundle = try BundleInstall.unpack(data, near: FileManager.default.temporaryDirectory)
    } catch {
        return "the archive does not unpack to the one TrackpadLauncher.app an update card admits."
    }
    defer { BundleInstall.discard(bundle) }
    guard
        isGenuine(
            bundle, version: declared.version, minimumMacOS: declared.minimumMacOS,
            signer: Signer(team: team, identifier: identifier))
    else {
        return "the app is not a notarised Developer ID build of team \(team) and identifier \(identifier) whose Info.plist names version \(declared.version) and minimum macOS \(declared.minimumMacOS)."
    }
    return nil
}

/// "TrackpadLauncher-<version>-macOS-<minimum>.aar", the contract with every shipped version; nil for any other.
func archiveName(_ name: String) -> (version: Version, minimumMacOS: Version)? {
    let prefix = "TrackpadLauncher-"
    let suffix = ".aar"
    guard name.hasPrefix(prefix), name.hasSuffix(suffix), name.count > prefix.count + suffix.count else { return nil }
    let declared = name.dropFirst(prefix.count).dropLast(suffix.count)
    let pieces = declared.components(separatedBy: "-macOS-")
    guard pieces.count == 2, let version = Version(pieces[0]), let minimum = Version(pieces[1]) else { return nil }
    return (version, minimum)
}

private let developerID =
    "anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"

/// Whether a downloaded bundle is the release the card offered: the Developer ID requirement with this copy's team
/// and identifier and Apple's notarisation, checked with strict validation of every architecture, nested code and
/// resource, reading the stapled ticket rather than asking the network; and its sealed Info.plist names exactly
/// `version` and `minimumMacOS`.
func isGenuine(_ bundle: URL, version expectedVersion: Version, minimumMacOS expectedMinimum: Version, signer: Signer) -> Bool {
    let quoted = CharacterSet(charactersIn: "\"\\")
    guard signer.team.rangeOfCharacter(from: quoted) == nil, signer.identifier.rangeOfCharacter(from: quoted) == nil
    else { return false }
    let text =
        "\(developerID) and certificate leaf[subject.OU] = \"\(signer.team)\" and identifier \"\(signer.identifier)\" and notarized"
    var code: SecStaticCode?
    var requirement: SecRequirement?
    guard SecStaticCodeCreateWithPath(bundle as CFURL, [], &code) == errSecSuccess, let code,
        SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess, let requirement
    else { return false }
    // kSecCSNoNetworkAccess (1 << 29) is not imported into Swift.
    let noNetworkAccess: UInt32 = 1 << 29
    let strict = SecCSFlags(
        rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | noNetworkAccess)
    guard SecStaticCodeCheckValidity(code, strict, requirement) == errSecSuccess else { return false }
    guard let values = signingInformation(of: code),
        let plist = values[kSecCodeInfoPList as String] as? [String: Any],
        let version = (plist["CFBundleShortVersionString"] as? String).flatMap(Version.init),
        let minimum = (plist["LSMinimumSystemVersion"] as? String).flatMap(Version.init)
    else { return false }
    return version == expectedVersion && minimum == expectedMinimum
}

private func signingInformation(of code: SecStaticCode) -> [String: Any]? {
    var information: CFDictionary?
    guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess
    else { return nil }
    return information as? [String: Any]
}

/// The team and bundle identifier a Developer ID signature carries.
struct Signer: Sendable, Equatable {
    let team: String
    let identifier: String
}

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

    /// Removes a staged copy and the temporary folder it was made in. Leftovers do not matter: nothing throws.
    static func discard(_ staged: URL) {
        let files = FileManager.default
        try? files.removeItem(at: staged)
        let folder = staged.deletingLastPathComponent()
        if (try? files.contentsOfDirectory(atPath: folder.path))?.isEmpty == true {
            try? files.removeItem(at: folder)
        }
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
