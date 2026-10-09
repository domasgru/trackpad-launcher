import Foundation
import Testing

/// Scans every Swift source file the app ships for APIs the product promises never to use.
/// To forbid something new, add it to `banned`; do not write prose.
@Suite struct SourcePolicyTests {
    struct Entry: Sendable, CustomTestStringConvertible {
        let token: String
        let rule: String
        var testDescription: String { "\(token) (\(rule))" }
    }

    static let banned: [Entry] = [
        Entry(token: "print(", rule: "log"),
        Entry(token: "debugPrint(", rule: "log"),
        Entry(token: "dump(", rule: "log"),
        Entry(token: "NSLog(", rule: "log"),
        Entry(token: "os_log", rule: "log"),
        Entry(token: "Logger(", rule: "log"),
        Entry(token: "import OSLog", rule: "log"),
        Entry(token: "import os", rule: "log"),
        Entry(token: "URLSession", rule: "network"),
        Entry(token: "import Network", rule: "network"),
        Entry(token: "NWConnection", rule: "network"),
        Entry(token: "CFSocket", rule: "network"),
        Entry(token: "CFStream", rule: "network"),
        Entry(token: "FileHandle(forWriting", rule: "own files"),
        Entry(token: ".write(to:", rule: "own files"),
        Entry(token: "createFile(atPath", rule: "own files"),
        Entry(token: "Timer", rule: "timer"),
        Entry(token: "asyncAfter", rule: "timer"),
        Entry(token: "Task.sleep", rule: "polling"),
        Entry(token: "makeTimerSource", rule: "timer"),
        Entry(token: "AXIsProcessTrusted", rule: "permission"),
        Entry(token: "tapCreate", rule: "permission"),
        Entry(token: "CGEventTapCreate", rule: "permission"),
        Entry(token: "IOHIDManager", rule: "permission"),
        Entry(token: "CGRequestListenEventAccess", rule: "permission"),
        Entry(token: "CGPreflightListenEventAccess", rule: "permission"),
        Entry(token: "nonisolated(unsafe)", rule: "one writer per field"),
    ]

    /// `Tests/LauncherCoreTests/<this file>` is three levels below the package root.
    static let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// The library sources plus the app target's directory once it exists.
    static var scannedRoots: [URL] {
        [
            packageRoot.appending(path: "Sources"),
            packageRoot.deletingLastPathComponent().appending(path: "TrackpadLauncher"),
        ].filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    @Test(arguments: banned)
    func noSourceUses(_ entry: Entry) throws {
        let hits = try Self.scannedRoots.flatMap { try Self.scan($0, for: entry.token) }
        #expect(hits.isEmpty, "\(entry.token) is banned (\(entry.rule)): \(hits)")
    }

    @Test func scannerFindsAPlantedHit() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "tl-policy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let planted = dir.appending(path: "Planted.swift")
        try Data("func f() {\n    print(\"x\")\n}\n".utf8).write(to: planted)
        try Data("func g() {}\n".utf8).write(to: dir.appending(path: "Clean.swift"))

        let hits = try Self.banned.flatMap { try Self.scan(dir, for: $0.token) }

        #expect(hits == ["Planted.swift:2: print("])
    }

    @Test func scanVisitsEveryLibraryTarget() throws {
        let visited = try Self.scannedRoots.flatMap { try Self.swiftFiles(under: $0) }.map(\.path)
        for target in ["LauncherCore", "LauncherPlatform", "LauncherUI"] {
            #expect(visited.contains { $0.contains("/Sources/\(target)/") }, "no file scanned under \(target)")
        }
    }

    private static func swiftFiles(under root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// One "<file>:<line>: <token>" string per line containing `token`.
    private static func scan(_ root: URL, for token: String) throws -> [String] {
        try swiftFiles(under: root).flatMap { file -> [String] in
            let text = try String(contentsOf: file, encoding: .utf8)
            return text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
                .filter { $0.element.contains(token) }
                .map { "\(file.lastPathComponent):\($0.offset + 1): \(token)" }
        }
    }
}
