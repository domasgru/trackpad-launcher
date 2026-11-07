import AppleArchive
import Foundation
import System

/// Archives written entry by entry with the AppleArchive encoder, for entries `aa` cannot be told to write: paths with
/// "..", absolute paths, and files beneath a symbolic link.
enum CraftedArchive {
    enum Entry {
        case directory(String)
        case file(String, Data)
        case link(String, to: String)
        case fifo(String)
    }

    /// Every item of `app`, as entries under its own name.
    static func entries(of app: URL) throws -> [Entry] {
        let files = FileManager.default
        let name = app.lastPathComponent
        var entries: [Entry] = [.directory(name)]
        for case let item as URL in files.enumerator(at: app, includingPropertiesForKeys: nil)! {
            let relative = name + "/" + item.path.dropFirst(app.path.count + 1)
            if let target = try? files.destinationOfSymbolicLink(atPath: item.path) {
                entries.append(.link(relative, to: target))
            } else if (try item.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true {
                entries.append(.directory(relative))
            } else {
                entries.append(.file(relative, try Data(contentsOf: item)))
            }
        }
        return entries
    }

    static func make(_ entries: [Entry]) throws -> Data {
        let output = FileManager.default.temporaryDirectory.appending(path: "tl-crafted-\(UUID().uuidString).aar")
        defer { try? FileManager.default.removeItem(at: output) }
        guard let file = ArchiveByteStream.fileStream(
                path: FilePath(output.path), mode: .writeOnly, options: [.create], permissions: FilePermissions(rawValue: 0o644)),
            let compressed = ArchiveByteStream.compressionStream(using: .lzfse, writingTo: file),
            let encoder = ArchiveStream.encodeStream(writingTo: compressed)
        else { throw CocoaError(.fileWriteUnknown) }
        for entry in entries {
            let header = ArchiveHeader()
            switch entry {
            case .directory(let path):
                head(header, type: "D", path: path, mode: 0o755)
                try encoder.writeHeader(header)
            case .file(let path, let data):
                head(header, type: "F", path: path, mode: 0o644)
                header.append(.blob(key: ArchiveHeader.FieldKey("DAT"), size: UInt64(data.count)))
                try encoder.writeHeader(header)
                try data.withUnsafeBytes { try encoder.writeBlob(key: ArchiveHeader.FieldKey("DAT"), from: $0) }
            case .link(let path, let target):
                head(header, type: "L", path: path, mode: 0o755)
                header.append(.string(key: ArchiveHeader.FieldKey("LNK"), value: target))
                try encoder.writeHeader(header)
            case .fifo(let path):
                head(header, type: "P", path: path, mode: 0o644)
                try encoder.writeHeader(header)
            }
        }
        try encoder.close()
        try compressed.close()
        try file.close()
        return try Data(contentsOf: output)
    }

    private static func head(_ header: ArchiveHeader, type: Character, path: String, mode: UInt64) {
        header.append(.uint(key: ArchiveHeader.FieldKey("TYP"), value: UInt64(type.asciiValue!)))
        header.append(.string(key: ArchiveHeader.FieldKey("PAT"), value: path))
        header.append(.uint(key: ArchiveHeader.FieldKey("MOD"), value: mode))
    }
}
