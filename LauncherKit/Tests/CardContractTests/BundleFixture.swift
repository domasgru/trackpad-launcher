import CryptoKit
import Foundation

/// A throwaway folder with app bundles made in it, and the readers the moved tests check an unpacked bundle with.
final class BundleFixture: @unchecked Sendable {
    static let identifier = "com.example.TrackpadLauncherFixture"

    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "tl-bundle-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        for directory in FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.compactMap({ $0 as? URL }) ?? [] {
            chmod(directory.path, 0o755)
        }
        chmod(root.path, 0o755)
        try? FileManager.default.removeItem(at: root)
    }

    func folder(_ name: String) throws -> URL {
        let url = root.appending(path: name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// An app with nested files and a symlink, the quarantine set on every item.
    @discardableResult
    func makeBundle(named name: String, in folder: URL, version: String) throws -> URL {
        let files = FileManager.default
        let app = folder.appending(path: name)
        let contents = app.appending(path: "Contents")
        let nested = contents.appending(path: "Resources/nested")
        try files.createDirectory(at: contents.appending(path: "MacOS"), withIntermediateDirectories: true)
        try files.createDirectory(at: nested, withIntermediateDirectories: true)
        let info: [String: Any] = [
            "CFBundleIdentifier": Self.identifier, "CFBundleShortVersionString": version,
            "CFBundleExecutable": "fixture", "CFBundlePackageType": "APPL",
        ]
        try (info as NSDictionary).write(to: contents.appending(path: "Info.plist"))
        try Data("binary \(version)".utf8).write(to: contents.appending(path: "MacOS/fixture"))
        try Data("deep \(version)".utf8).write(to: nested.appending(path: "deep.txt"))
        try files.createSymbolicLink(
            atPath: contents.appending(path: "Resources/link").path, withDestinationPath: "nested/deep.txt")
        try quarantineEveryItem(of: app)
        return app
    }

    private func quarantineEveryItem(of app: URL) throws {
        let items = [app] + (FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? [])
        for item in items where (try? FileManager.default.destinationOfSymbolicLink(atPath: item.path)) == nil {
            let value = Array("0081;00000000;Fixture;".utf8)
            guard setxattr(item.path, "com.apple.quarantine", value, value.count, 0, 0) == 0 else { throw CocoaError(.fileWriteUnknown) }
        }
    }

    /// Relative path to a description of the item: the SHA-256 of a file, the target of a symlink, "dir" of a folder.
    static func manifest(of app: URL) throws -> [String: String] {
        let files = FileManager.default
        var manifest: [String: String] = [:]
        for item in files.enumerator(at: app, includingPropertiesForKeys: nil)?.compactMap({ $0 as? URL }) ?? [] {
            let components = item.pathComponents
            let relative = components[(components.lastIndex(of: app.lastPathComponent) ?? 0)...].dropFirst().joined(separator: "/")
            if let target = try? files.destinationOfSymbolicLink(atPath: item.path) {
                manifest[relative] = "link:" + target
            } else if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                manifest[relative] = "dir"
            } else {
                manifest[relative] = SHA256.hash(data: try Data(contentsOf: item)).map { String(format: "%02x", $0) }.joined()
            }
        }
        return manifest
    }

    /// Every extended attribute `xattr -r` lists under the app, as an independent reader.
    static func extendedAttributes(under app: URL) throws -> String {
        try run("/usr/bin/xattr", ["-r", app.path])
    }

    /// `folder`'s `subdirectory` archived by release.sh's own line, read back whole.
    static func archive(_ subdirectory: String, in folder: URL) throws -> Data {
        let output = FileManager.default.temporaryDirectory.appending(path: "tl-archive-\(UUID().uuidString).aar")
        defer { try? FileManager.default.removeItem(at: output) }
        try run(
            "/usr/bin/aa",
            ["archive", "-d", folder.path, "-subdir", subdirectory, "-exclude-field", "uid,gid,xat,acl,flg", "-o", output.path])
        return try Data(contentsOf: output)
    }

    /// Everything in `folder`, archived without a subdirectory, so entries sit beside the app.
    static func archiveEverything(in folder: URL) throws -> Data {
        let output = FileManager.default.temporaryDirectory.appending(path: "tl-archive-\(UUID().uuidString).aar")
        defer { try? FileManager.default.removeItem(at: output) }
        try run("/usr/bin/aa", ["archive", "-d", folder.path, "-exclude-field", "uid,gid,xat,acl,flg", "-o", output.path])
        return try Data(contentsOf: output)
    }

    static func appNames(in folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".app") }.sorted()
    }

    @discardableResult
    private static func run(_ tool: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        let waitForExit = try process.start()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        waitForExit()
        guard process.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
        return String(decoding: data, as: UTF8.self)
    }
}
