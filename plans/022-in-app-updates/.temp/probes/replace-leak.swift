// Does staging in an item-replacement folder and swapping with replaceItemAt leave a TemporaryDirectory.* behind?
import Foundation

let fm = FileManager.default
let tmp = fm.temporaryDirectory
func leftovers() -> Set<String> {
    Set((try? fm.contentsOfDirectory(atPath: tmp.path).filter { $0.hasPrefix("TemporaryDirectory.") }) ?? [])
}
let root = tmp.appending(path: "tl-probe-\(UUID().uuidString)")
try fm.createDirectory(at: root, withIntermediateDirectories: true)
let dest = root.appending(path: "A.app")
try fm.createDirectory(at: dest, withIntermediateDirectories: true)
let before = leftovers()

let folder = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: dest, create: true)
print("staging folder:", folder.path)
let staged = folder.appending(path: "A.app")
try fm.createDirectory(at: staged, withIntermediateDirectories: true)
_ = try fm.replaceItemAt(dest, withItemAt: staged)
print("staging folder exists after swap:", fm.fileExists(atPath: folder.path),
      "contents:", (try? fm.contentsOfDirectory(atPath: folder.path)) ?? [])
print("new TemporaryDirectory.* after swap:", leftovers().subtracting(before).sorted())

// What BundleInstall.discard does: remove the staged item, then the folder when empty.
try? fm.removeItem(at: staged)
if (try? fm.contentsOfDirectory(atPath: folder.path))?.isEmpty == true { try? fm.removeItem(at: folder) }
print("new TemporaryDirectory.* after discard:", leftovers().subtracting(before).sorted())
try? fm.removeItem(at: root)
