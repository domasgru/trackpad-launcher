// Runs shipped BundleInstall.admits, copied verbatim from LauncherPlatform/BundleInstall.swift,
// over every entry of a bundle with Sparkle.framework embedded, named as the .aar names it.
// R16: a copy with the update card must accept the first automatic-update version's archive.
import Foundation

let archivedBundleName = "TrackpadLauncher.app"
enum ArchiveEntryKind { case directory, file, symbolicLink, other }

func admits(path: String, kind: ArchiveEntryKind, linkTarget: String?) -> Bool {
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

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let files = FileManager.default
var counts = (directories: 0, files: 0, links: 0, other: 0, refused: 0)
func check(_ relative: String) {
    let full = root.appendingPathComponent(relative).path
    var info = stat()
    lstat(full, &info)
    let kind: ArchiveEntryKind
    var target: String?
    switch info.st_mode & S_IFMT {
    case S_IFDIR: kind = .directory; counts.directories += 1
    case S_IFREG: kind = .file; counts.files += 1
    case S_IFLNK:
        kind = .symbolicLink; counts.links += 1
        target = try? files.destinationOfSymbolicLink(atPath: full)
    default: kind = .other; counts.other += 1
    }
    let path = relative.isEmpty ? archivedBundleName : "\(archivedBundleName)/\(relative)"
    if !admits(path: path, kind: kind, linkTarget: target) {
        counts.refused += 1
        print("REFUSED", path, target ?? "")
    }
}
check("")
for case let relative as String in files.enumerator(atPath: root.path)! { check(relative) }
print(counts)
