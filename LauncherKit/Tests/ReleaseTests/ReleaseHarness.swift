import CryptoKit
import Foundation

struct ReleaseRun {
    let status: Int32
    let output: String
}

/// Runs the repository's real `Scripts/release.sh` in a throwaway clone of a throwaway bare origin, with every
/// outside tool (gh, xcodebuild, notarytool, hdiutil, ...) a logging stub first on the PATH. Sparkle's real
/// `sign_update` signs with a throwaway key. Nothing here reaches the real origin, keychain or GitHub.
final class ReleaseHarness: Sendable {
    static let repository = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    static let realSparkleBin = repository.appending(path: "LauncherKit/Vendor/Sparkle/bin")

    enum PushKind: String {
        case version = "reject-version"
        case feed = "reject-feed"
    }

    let folder: URL
    let origin: URL
    let clone: URL
    let state: URL
    let out: URL
    let publicKey: String

    var sparkleBin: URL { clone.appending(path: "LauncherKit/Vendor/Sparkle/bin") }
    var feed: URL { clone.appending(path: "appcast.xml") }

    init() throws {
        let files = FileManager.default
        folder = files.temporaryDirectory.appending(path: "tl-release-\(UUID().uuidString)")
        origin = folder.appending(path: "origin.git")
        clone = folder.appending(path: "clone")
        state = folder.appending(path: "state")
        out = folder.appending(path: "out")
        let key = Curve25519.Signing.PrivateKey()
        publicKey = key.publicKey.rawRepresentation.base64EncodedString()

        for directory in [origin, clone, state, out, state.appending(path: "stubs"), folder.appending(path: "home"), folder.appending(path: "tmp")] {
            try files.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try key.rawRepresentation.base64EncodedString().write(to: state.appending(path: "ed-key"), atomically: true, encoding: .utf8)
        try publicKey.write(to: state.appending(path: "keychain-public-key"), atomically: true, encoding: .utf8)
        try "".write(to: state.appending(path: "log"), atomically: true, encoding: .utf8)
        try "".write(to: state.appending(path: "fail-patterns"), atomically: true, encoding: .utf8)
        try files.createDirectory(at: state.appending(path: "releases"), withIntermediateDirectories: true)

        try installStubs()
        try makeRepositories()
        try Data().write(to: state.appending(path: "log"))
    }

    deinit {
        try? FileManager.default.removeItem(at: folder)
    }

    // MARK: Running

    @discardableResult
    func run(_ arguments: String...) throws -> ReleaseRun {
        try execute("/bin/bash", [clone.appending(path: "Scripts/release.sh").path] + arguments, in: clone)
    }

    @discardableResult
    func git(_ arguments: String..., in directory: URL? = nil) throws -> String {
        let result = try execute("/usr/bin/git", arguments, in: directory ?? clone)
        guard result.status == 0 else { throw HarnessError.command("git \(arguments.joined(separator: " ")): \(result.output)") }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func execute(_ executable: String, _ arguments: [String], in directory: URL) throws -> ReleaseRun {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.environment = [
            "PATH": "\(state.appending(path: "stubs").path):/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": folder.appending(path: "home").path,
            "TMPDIR": folder.appending(path: "tmp").path + "/",
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_TERMINAL_PROMPT": "0",
            "STUB_STATE": state.path,
            "STUB_CLONE": clone.path,
            "STUB_ORIGIN": origin.path,
            "RELEASE_OUT": out.path,
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return ReleaseRun(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }

    // MARK: Arranging

    func failOn(_ patterns: String...) throws {
        try failOn(patterns)
    }

    func failOn(_ patterns: [String]) throws {
        let text = patterns.isEmpty ? "" : patterns.joined(separator: "\n") + "\n"
        try text.write(to: state.appending(path: "fail-patterns"), atomically: true, encoding: .utf8)
    }

    func autoupdateIsSigned(by team: String) throws {
        try team.write(to: state.appending(path: "autoupdate-team"), atomically: true, encoding: .utf8)
    }

    func rejectPushes(_ kind: PushKind) throws {
        try Data().write(to: origin.appending(path: kind.rawValue))
    }

    func acceptPushes(_ kind: PushKind) throws {
        try FileManager.default.removeItem(at: origin.appending(path: kind.rawValue))
    }

    func setKeychainKey(_ key: String) throws {
        try key.write(to: state.appending(path: "keychain-public-key"), atomically: true, encoding: .utf8)
    }

    func removeSparkleTool(_ name: String) throws {
        try FileManager.default.removeItem(at: sparkleBin.appending(path: name))
    }

    func leaveDraft(_ version: String) throws {
        try Data().write(to: state.appending(path: "releases/v\(version).draft"))
    }

    func setVersion(_ marketing: String, build: Int) throws {
        try edit("Config/Version.xcconfig") { line in
            if line.hasPrefix("MARKETING_VERSION") { return "MARKETING_VERSION = \(marketing)" }
            if line.hasPrefix("CURRENT_PROJECT_VERSION") { return "CURRENT_PROJECT_VERSION = \(build)" }
            return line
        }
        try commitAndPush("Set version \(marketing)")
    }

    func setShippedKey(_ value: String) throws {
        try edit("project.yml") { line in
            guard line.trimmingCharacters(in: .whitespaces).hasPrefix("SUPublicEDKey:") else { return line }
            return String(line.prefix { $0 == " " }) + "SUPublicEDKey: \(value)"
        }
        try commitAndPush("Set the shipped key")
    }

    func setFeed(_ contents: String) throws {
        try contents.write(to: feed, atomically: true, encoding: .utf8)
        try commitAndPush("Set the feed")
    }

    func tag(_ name: String) throws {
        try git("tag", name)
        try git("push", "--quiet", "origin", name)
    }

    func makeApp(at url: URL) throws {
        let result = try execute(state.appending(path: "make-app").path, [url.path], in: clone)
        guard result.status == 0 else { throw HarnessError.command(result.output) }
    }

    // MARK: Observing

    var log: [String] {
        let text = (try? String(contentsOf: state.appending(path: "log"), encoding: .utf8)) ?? ""
        return text.split(separator: "\n").map(String.init)
    }

    func logIndex(of prefix: String) -> Int? {
        log.firstIndex { $0.hasPrefix(prefix) }
    }

    var head: String { get throws { try git("rev-parse", "HEAD") } }
    var originRefs: String { get throws { try git("for-each-ref", in: origin) } }
    var treeIsClean: Bool { get throws { try git("status", "--porcelain").isEmpty } }
    var feedText: String { get throws { try String(contentsOf: feed, encoding: .utf8) } }
    var originFeedText: String { get throws { try git("show", "main:appcast.xml", in: origin) + "\n" } }

    func publishedAssets(of version: String) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: state.appending(path: "releases/v\(version)").path).sorted()
    }

    func publishedArchive(of version: String) throws -> URL {
        let directory = state.appending(path: "releases/v\(version)")
        guard let name = try publishedAssets(of: version).first(where: { $0.hasSuffix(".aar") }) else {
            throw HarnessError.command("v\(version) has no .aar")
        }
        return directory.appending(path: name)
    }

    func verifies(signature: String, of archive: URL) throws -> Bool {
        let result = try execute(sparkleBin.appending(path: "sign_update").path, ["--verify", archive.path, signature], in: clone)
        return result.status == 0
    }

    // MARK: Building the repository

    private func edit(_ relativePath: String, _ transform: (String) -> String) throws {
        let url = clone.appending(path: relativePath)
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { transform(String($0)) }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private func commitAndPush(_ message: String) throws {
        try git("add", "-A")
        try git("commit", "--quiet", "-m", message)
        try git("push", "--quiet", "origin", "main")
    }

    private func makeRepositories() throws {
        let files = FileManager.default
        try git("init", "--quiet", "--bare", "--initial-branch=main", in: origin)
        try write(
            origin.appending(path: "hooks/pre-receive"),
            #"""
            #!/bin/bash
            while read -r old new ref; do
              subject="$(/usr/bin/git log -1 --format=%s "$new")"
              echo "push $subject" >> "$STUB_STATE/log"
              case "$subject" in
                Version*) [ ! -e ./reject-version ] || { echo "rejected by the harness" >&2; exit 1; } ;;
                Feed*) [ ! -e ./reject-feed ] || { echo "rejected by the harness" >&2; exit 1; } ;;
              esac
            done
            """#
        )

        try git("init", "--quiet", "--initial-branch=main")
        try git("config", "user.name", "Release Harness")
        try git("config", "user.email", "harness@example.invalid")
        try git("config", "commit.gpgsign", "false")
        try git("config", "tag.gpgsign", "false")
        for path in [
            "Scripts/release.sh", "Scripts/test.sh", "Scripts/release/dmg-background.png",
            "project.yml", ".gitignore",
        ] {
            let destination = clone.appending(path: path)
            try files.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try files.copyItem(at: Self.repository.appending(path: path), to: destination)
        }
        // The version and the feed the tests start from, fixed: the repository's own move on with every release.
        try files.createDirectory(at: clone.appending(path: "Config"), withIntermediateDirectories: true)
        try Self.startingVersion.write(to: clone.appending(path: "Config/Version.xcconfig"), atomically: true, encoding: .utf8)
        try Self.startingFeed.write(to: feed, atomically: true, encoding: .utf8)
        try files.createDirectory(at: sparkleBin, withIntermediateDirectories: true)
        try installSparkleTools()
        // The stubs stand in for the vendored tools, which the clone must not track: a missing one is the test.
        try Data("LauncherKit/Vendor/\n".utf8).write(to: clone.appending(path: ".git/info/exclude"), options: .atomic)
        try setShippedKeyBeforeFirstCommit()
        try git("add", "-A")
        try git("commit", "--quiet", "-m", "Initial")
        try git("remote", "add", "origin", origin.path)
        try git("push", "--quiet", "origin", "main")
        try git("fetch", "--quiet", "origin")
        try git("branch", "--set-upstream-to=origin/main", "main")
    }

    private static let startingVersion = """
        // The version users see (CFBundleShortVersionString) and the build number (CFBundleVersion).
        // Raise both for every release; the build number only ever goes up.
        MARKETING_VERSION = 1.0.15
        CURRENT_PROJECT_VERSION = 16

        """

    private static let startingFeed = """
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
        <channel>
        <title>Trackpad App</title>
        </channel>
        </rss>

        """

    private func setShippedKeyBeforeFirstCommit() throws {
        try edit("project.yml") { line in
            guard line.trimmingCharacters(in: .whitespaces).hasPrefix("SUPublicEDKey:") else { return line }
            return String(line.prefix { $0 == " " }) + "SUPublicEDKey: \(publicKey)"
        }
    }

    // MARK: Stubs

    private static let preamble = #"""
        #!/bin/bash
        line="$(basename "$0") $*"
        echo "$line" >> "$STUB_STATE/log"
        if [ -s "$STUB_STATE/fail-patterns" ] && grep -qF -f "$STUB_STATE/fail-patterns" <<<"$line"; then
          echo "$(basename "$0"): stubbed failure" >&2
          exit 1
        fi

        """#

    private func write(_ url: URL, _ body: String, preamble: Bool = false) throws {
        let text = (preamble ? Self.preamble : "") + body + "\n"
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private func installSparkleTools() throws {
        try write(
            sparkleBin.appending(path: "sign_update"),
            """
            exec "\(Self.realSparkleBin.appending(path: "sign_update").path)" --ed-key-file "$STUB_STATE/ed-key" "$@"
            """,
            preamble: true
        )
        try write(
            sparkleBin.appending(path: "generate_keys"),
            #"""
            [ "$1" = "-p" ] && cat "$STUB_STATE/keychain-public-key"
            """#,
            preamble: true
        )
    }

    private func installStubs() throws {
        let stubs = state.appending(path: "stubs")
        func stub(_ name: String, _ body: String) throws {
            try write(stubs.appending(path: name), body, preamble: true)
        }

        try write(
            state.appending(path: "make-app"),
            #"""
            #!/bin/bash
            set -e
            dest="$1"
            file="$STUB_CLONE/Config/Version.xcconfig"
            version="$(sed -n 's/^MARKETING_VERSION *= *//p' "$file" | tr -d '[:space:]')"
            build="$(sed -n 's/^CURRENT_PROJECT_VERSION *= *//p' "$file" | tr -d '[:space:]')"
            mkdir -p "$dest/Contents/MacOS" "$dest/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"
            cat > "$dest/Contents/Info.plist" <<PLIST
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
              <key>CFBundleIdentifier</key><string>com.domasgru.TrackpadLauncherApp</string>
              <key>CFBundleShortVersionString</key><string>$version</string>
              <key>CFBundleVersion</key><string>$build</string>
              <key>LSMinimumSystemVersion</key><string>26.0</string>
            </dict>
            </plist>
            PLIST
            printf 'binary' > "$dest/Contents/MacOS/Trackpad App"
            chmod +x "$dest/Contents/MacOS/Trackpad App"
            printf 'installer' > "$dest/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
            """#
        )

        try stub("gh", #"""
            releases="$STUB_STATE/releases"
            case "$1 $2" in
              "auth status") exit 0 ;;
              "release list")
                for entry in "$releases"/*; do
                  [ -e "$entry" ] || continue
                  name="$(basename "$entry")"
                  echo "${name%.draft}"
                done
                exit 0 ;;
              "release view")
                if [ -e "$releases/$3.draft" ]; then echo true; exit 0; fi
                if [ -d "$releases/$3" ]; then echo false; exit 0; fi
                exit 1 ;;
              "release delete")
                rm -rf "$releases/$3" "$releases/$3.draft"
                exit 0 ;;
              "release create")
                tag="$3"
                shift 3
                assets=()
                while [ $# -gt 0 ] && [[ "$1" != --* ]]; do assets+=("$1"); shift; done
                target=""
                while [ $# -gt 0 ]; do
                  if [ "$1" = "--target" ]; then target="$2"; fi
                  shift
                done
                mkdir -p "$releases/$tag"
                for asset in "${assets[@]}"; do cp "$asset" "$releases/$tag/"; done
                /usr/bin/git --git-dir="$STUB_ORIGIN" tag "$tag" "$target"
                exit 0 ;;
              "release download")
                tag="$3"
                shift 3
                dir=""
                while [ $# -gt 0 ]; do
                  if [ "$1" = "--dir" ]; then dir="$2"; fi
                  shift
                done
                [ -d "$releases/$tag" ] || { echo "release not found" >&2; exit 1; }
                cp "$releases/$tag/"*.aar "$dir/"
                exit 0 ;;
            esac
            exit 1
            """#)

        try stub("xcodegen", "exit 0")
        try stub("security", #"echo '  1) 0123456789ABCDEF "Developer ID Application: Harness (CQK27876UL)"'"#)
        try stub("osascript", "cat > /dev/null\necho true")
        try stub("spctl", "exit 0")
        try stub("xcrun", """
            case "$1 $2" in
              "notarytool submit") echo "status: Accepted" ;;
            esac
            exit 0
            """)
        try stub("swift", #"""
            case "$1" in
              run) echo "card-contract: accepted" ;;
            esac
            exit 0
            """#)
        try stub("xcodebuild", #"""
            if [ "$1" = "-exportArchive" ] || [[ " $* " == *" -exportArchive "* ]]; then
              path=""
              while [ $# -gt 0 ]; do
                if [ "$1" = "-exportPath" ]; then path="$2"; fi
                shift
              done
              "$STUB_STATE/make-app" "$path/Trackpad App.app"
            fi
            exit 0
            """#)
        try stub("codesign", #"""
            case "$1" in
              -dv*)
                team=CQK27876UL
                if [[ "$*" == *Autoupdate* ]] && [ -f "$STUB_STATE/autoupdate-team" ]; then team="$(cat "$STUB_STATE/autoupdate-team")"; fi
                {
                  echo "Executable=/stub"
                  echo "Identifier=com.domasgru.TrackpadLauncherApp"
                  echo "CodeDirectory v=20500 size=1 flags=0x10000(runtime) hashes=1+1 location=embedded"
                  echo "Authority=Developer ID Application: Harness ($team)"
                  echo "TeamIdentifier=$team"
                } >&2 ;;
            esac
            exit 0
            """#)
        try stub("hdiutil", #"""
            last=""
            for argument in "$@"; do last="$argument"; done
            case "$1" in
              info) ;;
              create) printf 'image' > "$last" ;;
              attach) printf '/dev/disk9\tApple_partition_scheme\t\n/dev/disk9s1\tApple_HFS\t/Volumes/Trackpad App\n' ;;
              detach) ;;
              convert)
                while [ $# -gt 0 ]; do
                  if [ "$1" = "-o" ]; then printf 'image' > "$2"; fi
                  shift
                done ;;
            esac
            exit 0
            """#)
    }
}

enum HarnessError: Error {
    case command(String)
}
