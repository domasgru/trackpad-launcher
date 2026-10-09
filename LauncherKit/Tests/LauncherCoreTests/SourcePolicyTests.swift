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
        Entry(token: "IOHIDManager", rule: "R9 only Accessibility"),
        Entry(token: "CGRequestListenEventAccess", rule: "R9 only Accessibility"),
        Entry(token: "CGPreflightListenEventAccess", rule: "R9 only Accessibility"),
        Entry(token: "IOHIDRequestAccess", rule: "R9 only Accessibility"),
        Entry(token: "IOHIDCheckAccess", rule: "R9 only Accessibility"),
        Entry(token: "CGRequestPostEventAccess", rule: "R9 only Accessibility"),
        Entry(token: "CGPreflightPostEventAccess", rule: "R9 only Accessibility"),
        Entry(token: "keyDown", rule: "R9 no keyboard"),
        Entry(token: "keyUp", rule: "R9 no keyboard"),
        Entry(token: "KeyDown", rule: "R9 no keyboard"),
        Entry(token: "KeyUp", rule: "R9 no keyboard"),
        Entry(token: "flagsChanged", rule: "R9 no keyboard"),
        Entry(token: "FlagsChanged", rule: "R9 no keyboard"),
        Entry(token: "scrollWheel", rule: "R6 never scrolling"),
        Entry(token: "ScrollWheel", rule: "R6 never scrolling"),
        Entry(token: ".post(tap:", rule: "R9 never synthesise"),
        Entry(token: "CGEventPost", rule: "R9 never synthesise"),
        Entry(token: "postToPid", rule: "R9 never synthesise"),
        Entry(token: "nonisolated(unsafe)", rule: "one writer per field"),
    ]

    /// Each permission API lives in exactly one file, the adapter that owns it. Any other hit fails.
    struct Confined: Sendable, CustomTestStringConvertible {
        let token: String
        let onlyIn: String
        let rule: String
        var testDescription: String { "\(token) only in \(onlyIn) (\(rule))" }
    }

    static let confined: [Confined] = [
        Confined(token: "AXIsProcessTrusted", onlyIn: "SystemAccessibilityPermission.swift", rule: "R9 one permission, one adapter"),
        Confined(token: "notify_register", onlyIn: "SystemAccessibilityPermission.swift", rule: "R7 the trust push"),
        Confined(token: "tapCreate", onlyIn: "ClickTap.swift", rule: "R9 the one event tap"),
        Confined(token: "CGEventTapCreate", onlyIn: "ClickTap.swift", rule: "R9 the one event tap"),
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

    @Test(arguments: confined)
    func onlyItsAdapterUses(_ entry: Confined) throws {
        let hits = try Self.scannedRoots.flatMap { try Self.scan($0, for: entry.token, outside: entry.onlyIn) }
        #expect(hits.isEmpty, "\(entry.token) belongs only in \(entry.onlyIn) (\(entry.rule)): \(hits)")
    }

    @Test func confinedScanFindsAUseOutsideItsFile() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "tl-confined-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = Data("func f() { _ = AXIsProcessTrusted() }\n".utf8)
        try source.write(to: dir.appending(path: "SystemAccessibilityPermission.swift"))
        try source.write(to: dir.appending(path: "Other.swift"))

        let hits = try Self.scan(dir, for: "AXIsProcessTrusted", outside: "SystemAccessibilityPermission.swift")

        #expect(hits == ["Other.swift:1: AXIsProcessTrusted"])
    }

    /// Pins both halves of the policy edit so neither drifts back: no confined token is also banned, and the kept
    /// IOHID, Input Monitoring, timer and polling tokens are still banned.
    @Test func policyListsMatchPlanTwo() {
        let banned = Self.banned.map(\.token)
        for entry in Self.confined {
            for token in banned {
                #expect(
                    !entry.token.contains(token) && !token.contains(entry.token),
                    "\(entry.token) is confined, so \(token) must not also be banned")
            }
        }
        for kept in [
            "IOHIDManager", "CGRequestListenEventAccess", "CGPreflightListenEventAccess", "Timer", "asyncAfter",
            "makeTimerSource", "Task.sleep",
        ] {
            #expect(banned.contains(kept), "\(kept) must stay banned")
        }
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
        #expect(visited.contains { $0.contains("/TrackpadLauncher/") }, "no file scanned under the app target")
    }

    static let coreAllowedImports: Set<String> = ["Foundation", "Observation"]

    @Test func coreImportsOnlyFoundationAndObservation() throws {
        let core = Self.packageRoot.appending(path: "Sources/LauncherCore")
        let hits = try Self.disallowedImports(in: core, allowed: Self.coreAllowedImports)
        #expect(hits.isEmpty, "LauncherCore may import only \(Self.coreAllowedImports.sorted()): \(hits)")
    }

    @Test func importScannerFindsAPlantedImport() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "tl-imports-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("import Foundation\nimport AppKit\n".utf8).write(to: dir.appending(path: "Planted.swift"))
        try Data("@preconcurrency import IOKit\nimport Observation\n".utf8).write(to: dir.appending(path: "Other.swift"))

        let hits = try Self.disallowedImports(in: dir, allowed: Self.coreAllowedImports)

        #expect(Set(hits) == ["Planted.swift:2: AppKit", "Other.swift:1: IOKit"])
    }

    /// One "<file>:<line>: <module>" string per import of a module outside `allowed`.
    private static func disallowedImports(in root: URL, allowed: Set<String>) throws -> [String] {
        try swiftFiles(under: root).flatMap { file -> [String] in
            let text = try String(contentsOf: file, encoding: .utf8)
            return text.split(separator: "\n", omittingEmptySubsequences: false).enumerated().compactMap { line in
                let words = line.element.split(separator: " ")
                guard let at = words.firstIndex(of: "import"), at + 1 < words.count,
                    words[..<at].allSatisfy({ $0.hasPrefix("@") || $0 == "public" || $0 == "internal" })
                else { return nil }
                let module = String(words[at + 1].split(separator: ".")[0])
                return allowed.contains(module) ? nil : "\(file.lastPathComponent):\(line.offset + 1): \(module)"
            }
        }
    }

    private static func swiftFiles(under root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// One "<file>:<line>: <token>" string per line containing `token`, skipping the file named `allowedFile`.
    private static func scan(_ root: URL, for token: String, outside allowedFile: String? = nil) throws -> [String] {
        try swiftFiles(under: root).filter { $0.lastPathComponent != allowedFile }.flatMap { file -> [String] in
            let text = try String(contentsOf: file, encoding: .utf8)
            return text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
                .filter { $0.element.contains(token) }
                .map { "\(file.lastPathComponent):\($0.offset + 1): \(token)" }
        }
    }
}
