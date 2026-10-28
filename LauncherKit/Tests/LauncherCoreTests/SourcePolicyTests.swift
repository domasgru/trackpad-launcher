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
        Entry(token: "displayLink", rule: "timer"),
        Entry(token: "DisplayLink", rule: "timer"),
        Entry(token: "IOHIDManager", rule: "no Input Monitoring or event posting"),
        Entry(token: "CGRequestListenEventAccess", rule: "no Input Monitoring or event posting"),
        Entry(token: "CGPreflightListenEventAccess", rule: "no Input Monitoring or event posting"),
        Entry(token: "IOHIDRequestAccess", rule: "no Input Monitoring or event posting"),
        Entry(token: "IOHIDCheckAccess", rule: "no Input Monitoring or event posting"),
        Entry(token: "CGRequestPostEventAccess", rule: "no Input Monitoring or event posting"),
        Entry(token: "CGPreflightPostEventAccess", rule: "no Input Monitoring or event posting"),
        Entry(token: "keyDown", rule: "R9 no keyboard"),
        Entry(token: "keyUp", rule: "R9 no keyboard"),
        Entry(token: "KeyDown", rule: "R9 no keyboard"),
        Entry(token: "KeyUp", rule: "R9 no keyboard"),
        Entry(token: "flagsChanged", rule: "R9 no keyboard"),
        Entry(token: "FlagsChanged", rule: "R9 no keyboard"),
        Entry(token: "ScrollWheel", rule: "scrolling is read only by the click tap"),
        Entry(token: ".post(tap:", rule: "R9 never synthesise"),
        Entry(token: "CGEventPost", rule: "R9 never synthesise"),
        Entry(token: "postToPid", rule: "R9 never synthesise"),
        Entry(token: "nonisolated(unsafe)", rule: "one writer per field"),
        Entry(
            token: "perform: {",
            rule: "a run-loop source's perform is a file-scope constant: written inside main-actor code it traps off main"),
        Entry(token: "AXUIElementSetAttributeValue", rule: "the window switcher only raises a window"),
        Entry(token: "kAXPressAction", rule: "the window switcher only raises a window"),
        Entry(token: "SCStream(", rule: "previews are pictures, never a stream"),
        Entry(token: "SCRecordingOutput", rule: "previews are pictures, never a recording"),
        Entry(token: "CGImageDestination", rule: "a preview is never encoded or written"),
        Entry(token: "representation(using", rule: "a preview is never encoded or written"),
        Entry(token: "tiffRepresentation", rule: "a preview is never encoded or written"),
        Entry(token: "NSStatusBar", rule: "no menu bar icon"),
        Entry(token: "NSStatusItem", rule: "no menu bar icon"),
        Entry(token: "SMAppService.agent", rule: "nothing relaunches the app"),
        Entry(token: "SMAppService.daemon", rule: "nothing relaunches the app"),
        Entry(token: "SMAppService.loginItem", rule: "nothing relaunches the app"),
        Entry(token: "SMLoginItemSetEnabled", rule: "nothing relaunches the app"),
    ]

    /// Each permission API lives in exactly one file, the adapter that owns it. Any other hit fails.
    struct Confined: Sendable, CustomTestStringConvertible {
        let token: String
        let onlyIn: Set<String>
        let rule: String
        var files: String { onlyIn.sorted().joined(separator: ", ") }
        var testDescription: String { "\(token) only in \(files) (\(rule))" }
    }

    static let confined: [Confined] = [
        Confined(token: "AXIsProcessTrusted", onlyIn: ["SystemPermissions.swift"], rule: "R9 one permission, one adapter"),
        Confined(token: "notify_register", onlyIn: ["SystemPermissions.swift"], rule: "R7 the trust push"),
        Confined(
            token: "ScreenCaptureAccess", onlyIn: ["SystemPermissions.swift"], rule: "one permission check, one adapter"),
        Confined(token: "ScreenCaptureKit", onlyIn: ["PreviewCapture.swift"], rule: "one file captures the screen"),
        Confined(token: "SCShareableContent", onlyIn: ["PreviewCapture.swift"], rule: "one file captures the screen"),
        Confined(token: "SCScreenshotManager", onlyIn: ["PreviewCapture.swift"], rule: "one file captures the screen"),
        Confined(token: "tapCreate", onlyIn: ["ClickTap.swift"], rule: "the click tap's event taps, one file"),
        Confined(token: "CGEventTapCreate", onlyIn: ["ClickTap.swift"], rule: "the click tap's event taps, one file"),
        Confined(token: "tapEnable", onlyIn: ["ClickTap.swift"], rule: "the click tap's event taps, one file"),
        Confined(token: "tapIsEnabled", onlyIn: ["ClickTap.swift"], rule: "the click tap's event taps, one file"),
        Confined(
            token: "mouseMoved", onlyIn: ["BounceOverlay.swift", "ClickTap.swift"],
            rule: "pointer moves are read only while a launch bounce shows; the click tap only rewrites to one"),
        Confined(
            token: "addGlobalMonitorForEvents", onlyIn: ["BounceOverlay.swift"],
            rule: "pointer moves are read only while a launch bounce shows"),
        Confined(
            token: "addLocalMonitorForEvents", onlyIn: ["BounceOverlay.swift"],
            rule: "pointer moves are read only while a launch bounce shows"),
        Confined(token: "scrollWheel", onlyIn: ["ClickTap.swift"], rule: "scrolling is read only by the click tap's event taps"),
        Confined(
            token: "_LSCopyApplicationArrayInFrontToBackOrder", onlyIn: ["LaunchServicesOrder.swift"],
            rule: "the private ⌘-Tab order has one reader"),
        Confined(
            token: "_LSCopyApplicationInformation", onlyIn: ["LaunchServicesOrder.swift"],
            rule: "the private ⌘-Tab order has one reader"),
        Confined(token: "AXUIElement", onlyIn: ["FrontmostAppWindows.swift", "LaunchWatch.swift"], rule: "the window reads have two readers"),
        Confined(token: "CGWindowList", onlyIn: ["FrontmostAppWindows.swift", "LaunchWatch.swift"], rule: "the window reads have two readers"),
        Confined(token: "SecCode", onlyIn: ["CodeSignature.swift"], rule: "the code signature is read in one place"),
        Confined(token: "SecStaticCode", onlyIn: ["CodeSignature.swift"], rule: "the code signature is read in one place"),
        Confined(token: "SecRequirement", onlyIn: ["CodeSignature.swift"], rule: "the code signature is read in one place"),
        Confined(token: "/bin/mv", onlyIn: ["PrivilegedInstall.swift"], rule: "the administrator's move has one script"),
        Confined(token: "/bin/rm", onlyIn: ["PrivilegedInstall.swift"], rule: "the administrator's move has one script"),
        Confined(token: "SMAppService", onlyIn: ["SystemLoginItem.swift"], rule: "one login item, one adapter"),
        Confined(
            token: "setActivationPolicy", onlyIn: ["SettingsShell.swift"],
            rule: "the Dock icon follows the settings window, in one place"),
        Confined(
            token: "disableRelaunchOnLogin", onlyIn: ["TrackpadLauncherApp.swift"],
            rule: "only the login item starts the app at login"),
        Confined(
            token: "keyAELaunchedAsLogInItem", onlyIn: ["ThisCopy.swift"],
            rule: "the launch event is parsed in one place"),
        Confined(
            token: "currentAppleEvent", onlyIn: ["ThisCopy.swift", "TrackpadLauncherApp.swift"],
            rule: "the launch event is read at the app delegate and parsed in one place"),
        Confined(
            token: "forceTerminate", onlyIn: ["SystemRunningCopies.swift"], rule: "other copies are stopped in one place"),
        Confined(token: ".terminate(", onlyIn: ["SystemRunningCopies.swift"], rule: "processes are ended in one place"),
        Confined(token: "copyItem(", onlyIn: ["BundleInstall.swift"], rule: "the move's file operations are in one file"),
        Confined(token: "moveItem(", onlyIn: ["BundleInstall.swift"], rule: "the move's file operations are in one file"),
        Confined(token: "replaceItemAt(", onlyIn: ["BundleInstall.swift"], rule: "the move's file operations are in one file"),
        Confined(token: "removeItem(", onlyIn: ["BundleInstall.swift"], rule: "the move's file operations are in one file"),
        Confined(
            token: "quarantinePropertiesKey", onlyIn: ["BundleInstall.swift"],
            rule: "the move's file operations are in one file"),
        Confined(
            token: "AuthorizationExecuteWithPrivileges", onlyIn: ["PrivilegedInstall.swift"],
            rule: "the one privileged call has one file"),
        Confined(
            token: "AuthorizationCopyRights", onlyIn: ["PrivilegedInstall.swift"], rule: "the one privileged call has one file"),
        Confined(token: "statfs", onlyIn: ["DiskImages.swift"], rule: "disk images are read and ejected in one place"),
        Confined(token: "DADisk", onlyIn: ["DiskImages.swift"], rule: "disk images are read and ejected in one place"),
        Confined(token: "unmountVolume", onlyIn: ["DiskImages.swift"], rule: "disk images are read and ejected in one place"),
        Confined(token: "SecTranslocate", onlyIn: ["ThisCopy.swift"], rule: "translocation is read in one place"),
        Confined(token: "runModal", onlyIn: ["MoveDialogPresenter.swift"], rule: "the move dialog is the one modal"),
        Confined(token: "kAEQuitReason", onlyIn: ["QuitSignals.swift"], rule: "the quit event is parsed in one place"),
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
        #expect(hits.isEmpty, "\(entry.token) belongs only in \(entry.files) (\(entry.rule)): \(hits)")
    }

    @Test func confinedScanFindsAUseOutsideItsFile() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "tl-confined-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = Data("func f() { _ = AXIsProcessTrusted() }\n".utf8)
        try source.write(to: dir.appending(path: "SystemPermissions.swift"))
        try source.write(to: dir.appending(path: "Other.swift"))

        let hits = try Self.scan(dir, for: "AXIsProcessTrusted", outside: ["SystemPermissions.swift"])

        #expect(hits == ["Other.swift:1: AXIsProcessTrusted"])
    }

    @Test func confinedScanFindsAUseOutsideEveryFileItIsAllowedIn() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "tl-confined-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = Data("func f() { _ = AXIsProcessTrusted() }\n".utf8)
        for name in ["First.swift", "Second.swift", "Third.swift"] { try source.write(to: dir.appending(path: name)) }

        let hits = try Self.scan(dir, for: "AXIsProcessTrusted", outside: ["First.swift", "Second.swift"])

        #expect(hits == ["Third.swift:1: AXIsProcessTrusted"])
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

    /// One "<file>:<line>: <token>" string per line containing `token`, skipping every file named in `allowedFiles`.
    private static func scan(_ root: URL, for token: String, outside allowedFiles: Set<String> = []) throws -> [String] {
        try swiftFiles(under: root).filter { !allowedFiles.contains($0.lastPathComponent) }.flatMap { file -> [String] in
            let text = try String(contentsOf: file, encoding: .utf8)
            return text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
                .filter { $0.element.contains(token) }
                .map { "\(file.lastPathComponent):\($0.offset + 1): \(token)" }
        }
    }
}
