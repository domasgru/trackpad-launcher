import DiskArbitration
import Foundation
import LauncherCore

/// Telling a disk image's volume from any other folder, and ejecting it.
enum DiskImages {
    /// The disk image a path lies on: its volume's device is a `DADisk` whose model is "Disk Image". nil anywhere else,
    /// or when any step fails.
    static func image(holding url: URL) -> DiskImage? {
        var info = statfs()
        guard statfs(url.path, &info) == 0 else { return nil }
        let device = string(from: &info.f_mntfromname)
        let mountPoint = string(from: &info.f_mntonname)
        guard device.hasPrefix("/dev/"), !mountPoint.isEmpty,
            let session = DASessionCreate(kCFAllocatorDefault),
            let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, device),
            let description = DADiskCopyDescription(disk) as? [String: Any],
            let model = description[kDADiskDescriptionDeviceModelKey as String] as? String,
            model.trimmingCharacters(in: .whitespaces) == "Disk Image"
        else { return nil }
        return DiskImage(volume: URL(filePath: mountPoint))
    }

    /// Returns at once. A file on it in use makes the unmount fail and the image stays mounted: a push, never a wait.
    static func eject(_ diskImage: DiskImage) {
        FileManager.default.unmountVolume(at: diskImage.volume, options: .allPartitionsAndEjectDisk) { _ in }
    }

    private static func string<T>(from field: inout T) -> String {
        withUnsafePointer(to: &field) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
    }
}
