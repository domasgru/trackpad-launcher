import Foundation
import Testing

/// Scans every Swift source file the app ships for APIs the product promises never to use, and the
/// manifest (`project.yml`) for Info.plist keys the bundle must never declare.
/// To forbid something new, add it to `banned` or `neverDeclared`; do not write prose.
@Suite struct SourcePolicyTests {
    struct Entry: Sendable, CustomTestStringConvertible {
        let token: String
        let rule: String
        var testDescription: String { "\(token) (\(rule))" }
    }

    static let suddenTerminationRule =
        "loginwindow force-quits, 3 s after a foreground app ends, every child of it that is a UI element without a visible window and declares sudden termination; a move's opening, and an older version's update card, make the new process that child for its first moments"

    static let banned: [Entry] = [
        Entry(token: "SuddenTermination", rule: suddenTerminationRule),
        Entry(token: "print(", rule: "log"),
        Entry(token: "debugPrint(", rule: "log"),
        Entry(token: "dump(", rule: "log"),
        Entry(token: "NSLog(", rule: "log"),
        Entry(token: "os_log", rule: "log"),
        Entry(token: "Logger(", rule: "log"),
        Entry(token: "import OSLog", rule: "log"),
        Entry(token: "import os", rule: "log"),
        Entry(token: "URLSession", rule: "our Swift makes no request"),
        Entry(token: "URLSession.shared", rule: "network"),
        Entry(token: "URLSessionConfiguration.default", rule: "network"),
        Entry(token: ".background(withIdentifier", rule: "network"),
        Entry(token: "String(contentsOf:", rule: "network"),
        Entry(token: "NSURLConnection", rule: "network"),
        Entry(token: "NSURLDownload", rule: "network"),
        Entry(token: "downloadTask", rule: "our Swift downloads nothing"),
        Entry(token: ".download(", rule: "our Swift downloads nothing"),
        Entry(token: "CFHTTP", rule: "network"),
        Entry(token: "import WebKit", rule: "network"),
        Entry(token: "WKWebView", rule: "network"),
        Entry(token: "curl", rule: "network"),
        Entry(token: "NSAppleScript", rule: "network"),
        Entry(token: "Process()", rule: "no child processes"),
        Entry(token: "Process.run(", rule: "no child processes"),
        Entry(token: "executableURL", rule: "no child processes"),
        Entry(token: "NSTask", rule: "no child processes"),
        Entry(token: "posix_spawn", rule: "no child processes"),
        Entry(token: "import Network", rule: "network"),
        Entry(token: "NWConnection", rule: "network"),
        Entry(token: "CFSocket", rule: "network"),
        Entry(token: "CFStream", rule: "network"),
        Entry(token: "FileHandle(forWriting", rule: "own files"),
        Entry(token: ".write(to:", rule: "own files"),
        Entry(token: "createFile(atPath", rule: "own files"),
        Entry(token: "asyncAfter", rule: "timer"),
        Entry(token: "Task.sleep", rule: "polling"),
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
        Entry(token: "SMAppService.agent", rule: "nothing relaunches the app after a crash or a force quit; the hand-over job opens it once after an update"),
        Entry(token: "SMAppService.daemon", rule: "nothing relaunches the app after a crash or a force quit; the hand-over job opens it once after an update"),
        Entry(token: "SMAppService.loginItem", rule: "nothing relaunches the app after a crash or a force quit; the hand-over job opens it once after an update"),
        Entry(token: "SMLoginItemSetEnabled", rule: "nothing relaunches the app after a crash or a force quit; the hand-over job opens it once after an update"),
        Entry(token: "/bin/rm", rule: "the administrator's swap removes nothing"),
    ]

    static let neverDeclared: [Entry] = [
        Entry(token: "NSSupportsSuddenTermination", rule: suddenTerminationRule),
        Entry(token: "SUEnableSystemProfiling", rule: "no system profile is ever sent"),
        Entry(token: "SUEnableInstallerLauncherService", rule: "the XPC services stay unused"),
        Entry(token: "SUEnableDownloaderService", rule: "the XPC services stay unused"),
    ]

    /// Keys the manifest must carry, and what their value must look like.
    struct Declared: Sendable, CustomTestStringConvertible {
        let key: String
        let valuePrefix: String?
        let valueSuffix: String?
        var testDescription: String { key }
    }

    static let alwaysDeclared: [Declared] = [
        Declared(key: "SUFeedURL", valuePrefix: "https://", valueSuffix: nil),
        Declared(key: "SUPublicEDKey", valuePrefix: nil, valueSuffix: nil),
        Declared(key: "SUEnableAutomaticChecks", valuePrefix: nil, valueSuffix: nil),
        Declared(key: "SUAutomaticallyUpdate", valuePrefix: nil, valueSuffix: nil),
        Declared(key: "SUVerifyUpdateBeforeExtraction", valuePrefix: nil, valueSuffix: nil),
        Declared(key: "TLUpdateDownloads", valuePrefix: "https://", valueSuffix: "/"),
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
        Confined(
            token: "http", onlyIn: ["SparkleEngine.swift"], rule: "no address in Swift; only Sparkle's `httpHeaders`"),
        Confined(
            token: "Timer", onlyIn: ["SystemIdleClock.swift"],
            rule: "the one timer is an automatic update's idle minute"),
        Confined(
            token: "makeTimerSource", onlyIn: ["SystemIdleClock.swift"],
            rule: "the one timer is an automatic update's idle minute"),
        Confined(
            token: "DispatchSourceTimer", onlyIn: ["SystemIdleClock.swift"],
            rule: "the one timer is an automatic update's idle minute"),
        Confined(token: "import Sparkle", onlyIn: ["SparkleEngine.swift"], rule: "the update engine is one file"),
        Confined(token: "HTTPCookieStorage", onlyIn: ["SparkleEngine.swift"], rule: "cookies are refused where the engine starts"),
        Confined(token: "URLCache", onlyIn: ["SparkleEngine.swift"], rule: "nothing is cached where the engine starts"),
        Confined(token: "org.sparkle-project", onlyIn: ["SparkleEngine.swift"], rule: "Sparkle's private paths have one reader"),
        Confined(token: "sparkle-updater", onlyIn: ["SparkleEngine.swift"], rule: "Sparkle's private job has one reader"),
        Confined(token: "Data(contentsOf:", onlyIn: ["Apps.swift", "CardContract.swift"], rule: "the one local-file reader; a URL read is a request"),
        Confined(token: "AXIsProcessTrusted", onlyIn: ["SystemPermissions.swift"], rule: "R9 one permission, one adapter"),
        Confined(token: "notify_register", onlyIn: ["SystemPermissions.swift"], rule: "R7 the trust push"),
        Confined(
            token: "ScreenCaptureAccess", onlyIn: ["SystemPermissions.swift"], rule: "one permission check, one adapter"),
        Confined(token: "ScreenCaptureKit", onlyIn: ["PreviewCapture.swift"], rule: "one file captures the screen"),
        Confined(token: "SCShareableContent", onlyIn: ["PreviewCapture.swift"], rule: "one file captures the screen"),
        Confined(token: "SCScreenshotManager", onlyIn: ["PreviewCapture.swift"], rule: "one file captures the screen"),
        Confined(token: "systemUptime", onlyIn: ["UptimeNow.swift"], rule: "the process's clock is read in one place"),
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
        Confined(token: ".hide(", onlyIn: ["BackgroundHider.swift"], rule: "apps are hidden in one place"),
        Confined(token: "SecCode", onlyIn: ["CodeSignature.swift", "CardContract.swift"], rule: "the code signature is read in one place"),
        Confined(token: "SecStaticCode", onlyIn: ["CodeSignature.swift", "CardContract.swift"], rule: "the code signature is read in one place"),
        Confined(token: "SecRequirement", onlyIn: ["CodeSignature.swift", "CardContract.swift"], rule: "the code signature is read in one place"),
        Confined(
            token: "ignoringOtherApps", onlyIn: ["AppActivation.swift"],
            rule: "the override of the active app has one home, with its reason"),
        Confined(
            token: ".activate()", onlyIn: ["AnimationTuner.swift"],
            rule: "the plain call is refused when an opening by hand starts the process; it lives only in the Debug tuner, whose click-time call is user intent"),
        Confined(
            token: "/bin/sh", onlyIn: ["LaunchdJob.swift", "PrivilegedInstall.swift"],
            rule: "the hand-over job and the administrator's move are the two scripts"),
        Confined(token: "/bin/mv", onlyIn: ["PrivilegedInstall.swift"], rule: "the administrator's move has one script"),
        Confined(token: "osascript", onlyIn: ["PrivilegedInstall.swift"], rule: "the administrator's exchange has one script"),
        Confined(token: "SMJob", onlyIn: ["LaunchdJob.swift"], rule: "the one non-permanent job API has one file"),
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
        Confined(token: "moveItem(", onlyIn: ["BundleInstall.swift", "CardContract.swift"], rule: "the move's file operations are in one file"),
        Confined(token: "replaceItemAt(", onlyIn: ["BundleInstall.swift"], rule: "the move's file operations are in one file"),
        Confined(token: "renamex_np(", onlyIn: ["BundleInstall.swift"], rule: "the move's file operations are in one file"),
        Confined(token: "removeItem(", onlyIn: ["BundleInstall.swift", "CardContract.swift"], rule: "the move's file operations are in one file"),
        Confined(
            token: "AppleArchive", onlyIn: ["CardContract.swift"], rule: "the card's rules unpack an archive, frozen"),
        Confined(
            token: "ArchiveStream", onlyIn: ["CardContract.swift"], rule: "the card's rules unpack an archive, frozen"),
        Confined(
            token: "ArchiveByteStream", onlyIn: ["CardContract.swift"], rule: "the card's rules unpack an archive, frozen"),
        Confined(
            token: "removexattr", onlyIn: ["BundleInstall.swift", "CardContract.swift"], rule: "the quarantine is cleared in one file"),
        Confined(
            token: "itemReplacementDirectory", onlyIn: ["BundleInstall.swift", "CardContract.swift"],
            rule: "the staging folder is made in one file"),
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

    @Test func theNetworkBansAreAllStillListed() {
        let listed = Set(Self.banned.map(\.token))
        let required: Set<String> = [
            "URLSession", "URLSession.shared", "URLSessionConfiguration.default", ".background(withIdentifier", "String(contentsOf:",
            "NSURLConnection", "NSURLDownload", "downloadTask", ".download(", "CFHTTP", "import WebKit", "WKWebView", "curl", "NSAppleScript",
            "import Network", "NWConnection", "CFSocket", "CFStream", "Process()", "Process.run(", "executableURL",
            "NSTask", "posix_spawn", "asyncAfter", "Task.sleep", ".write(to:", "FileHandle(forWriting",
            "createFile(atPath",
        ]
        #expect(required.subtracting(listed).isEmpty, "dropped from banned: \(required.subtracting(listed).sorted())")
    }

    @Test func theTimerBansAreStillScannedInTheConfinedList() {
        let confinedToTheClock = Set(Self.confined.filter { $0.onlyIn == ["SystemIdleClock.swift"] }.map(\.token))
        let required: Set<String> = ["Timer", "makeTimerSource", "DispatchSourceTimer"]
        #expect(required.subtracting(confinedToTheClock).isEmpty, "dropped from confined: \(required.subtracting(confinedToTheClock).sorted())")
    }

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

    @Test(arguments: neverDeclared)
    func manifestNeverDeclares(_ entry: Entry) throws {
        let hits = try Self.scanManifest(in: Self.packageRoot.deletingLastPathComponent(), for: entry.token)
        #expect(hits.isEmpty, "\(entry.token) must not be declared (\(entry.rule)): \(hits)")
    }

    @Test(arguments: alwaysDeclared)
    func manifestAlwaysDeclares(_ entry: Declared) throws {
        let manifest = Self.packageRoot.deletingLastPathComponent()
        let problems = try Self.declarationProblems(in: manifest, for: entry)
        #expect(problems.isEmpty, "\(entry.key): \(problems)")
    }

    @Test func declarationScanFindsAMissingKeyAndAPlainHTTPValue() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "tl-declared-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let manifest = "info:\n  properties:\n        SUFeedURL: http://example.com/appcast.xml\n        TLUpdateDownloads: https://example.com/x\n"
        try Data(manifest.utf8).write(to: dir.appending(path: "project.yml"))

        let missing = try Self.declarationProblems(
            in: dir, for: Declared(key: "SUPublicEDKey", valuePrefix: nil, valueSuffix: nil))
        let plain = try Self.declarationProblems(
            in: dir, for: Declared(key: "SUFeedURL", valuePrefix: "https://", valueSuffix: nil))
        let unterminated = try Self.declarationProblems(
            in: dir, for: Declared(key: "TLUpdateDownloads", valuePrefix: "https://", valueSuffix: "/"))

        #expect(missing == ["not declared"])
        #expect(plain == ["value does not start with https://"])
        #expect(unterminated == ["value does not end with /"])
    }

    @Test func manifestScanFindsAPlantedKey() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "tl-manifest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let manifest = "info:\n  properties:\n        NSSupportsSuddenTermination: true\n"
        try Data(manifest.utf8).write(to: dir.appending(path: "project.yml"))

        let hits = try Self.scanManifest(in: dir, for: "NSSupportsSuddenTermination")

        #expect(hits == ["project.yml:3: NSSupportsSuddenTermination"])
    }

    @Test func manifestScanFailsWithoutAManifest() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "tl-manifest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let error = #expect(throws: CocoaError.self) {
            try Self.scanManifest(in: dir, for: "NSSupportsSuddenTermination")
        }
        #expect(error?.code == .fileReadNoSuchFile)
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
        for target in ["LauncherCore", "LauncherPlatform", "LauncherUI", "CardContract"] {
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

    @Test func cardContractStaysFrozenApartFromTheApp() throws {
        let sources = Self.packageRoot.appending(path: "Sources")
        for target in ["CardContract", "card-contract"] {
            let hits = try Self.disallowedImports(
                in: sources.appending(path: target), allowed: ["AppleArchive", "CardContract", "Foundation", "Security", "System"])
            #expect(hits.isEmpty, "\(target) may import neither LauncherCore nor LauncherPlatform: \(hits)")
        }
        let manifest = try String(
            contentsOf: Self.packageRoot.deletingLastPathComponent().appending(path: "project.yml"), encoding: .utf8)
        #expect(!manifest.contains("CardContract"), "the app links CardContract")
        #expect(!manifest.contains("card-contract"), "the app links card-contract")
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
            try hits(in: file, for: token)
        }
    }

    /// Throws when `directory` holds no `project.yml`: a moved manifest must fail, not pass unscanned.
    private static func scanManifest(in directory: URL, for token: String) throws -> [String] {
        try hits(in: directory.appending(path: "project.yml"), for: token)
    }

    /// What is wrong with the `key: value` line of `project.yml`; empty when the key is declared as the entry asks.
    private static func declarationProblems(in directory: URL, for entry: Declared) throws -> [String] {
        let text = try String(contentsOf: directory.appending(path: "project.yml"), encoding: .utf8)
        let lines = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let line = lines.first(where: { $0.hasPrefix(entry.key + ":") }) else { return ["not declared"] }
        let value = line.dropFirst(entry.key.count + 1).trimmingCharacters(in: .whitespaces)
        var problems: [String] = []
        if let prefix = entry.valuePrefix, !value.hasPrefix(prefix) { problems.append("value does not start with \(prefix)") }
        if let suffix = entry.valueSuffix, !value.hasSuffix(suffix) { problems.append("value does not end with \(suffix)") }
        return problems
    }

    private static func hits(in file: URL, for token: String) throws -> [String] {
        let text = try String(contentsOf: file, encoding: .utf8)
        return text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            .filter { $0.element.contains(token) }
            .map { "\(file.lastPathComponent):\($0.offset + 1): \(token)" }
    }
}
