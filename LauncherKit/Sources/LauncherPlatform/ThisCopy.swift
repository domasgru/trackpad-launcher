import AppKit
import LauncherCore

/// Facts about this process, parsed once into core types.
public enum ThisCopy {
    /// The `oapp` of a start (read in didFinishLaunching: the event is nil in willFinishLaunching). `.atLogin` when it
    /// carries the login-item marker; otherwise, and for nil, `.byHand`. `--eject-disk-image <volume>` names the disk
    /// image the mover ran from; any other argument is ignored.
    public static func launch(event: NSAppleEventDescriptor?, arguments: [String]) -> Launch {
        let volume = arguments.firstIndex(of: "--eject-disk-image").flatMap { arguments[safe: $0 + 1] }
        return Launch(opening: opening(of: event), diskImageToEject: volume.map { DiskImage(volume: URL(filePath: $0)) })
    }

    /// A reopen (`aevt/rapp`): `.atLogin` only when it carries the login marker; otherwise, and for nil, `.byHand`.
    public static func opening(of event: NSAppleEventDescriptor?) -> Opening {
        let marker = event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
        return marker == OSType(keyAELaunchedAsLogInItem) ? .atLogin : .byHand
    }

    /// Where this copy lies: a quarantined copy macOS translocated is traced back to the bundle the user opened. The
    /// disk-image lookup answers nil until a disk image can be told from any other folder.
    public static func location() -> Location {
        location(of: Bundle.main.bundleURL, originalIfTranslocated: Translocation.original(of:), diskImage: DiskImages.image(holding:))
    }

    /// The same composition over injected lookups. The disk image is found from the original, not the running bundle,
    /// whose translocation mount is never one.
    static func location(
        of bundle: URL, originalIfTranslocated: (URL) -> URL?, diskImage: (URL) -> DiskImage?
    ) -> Location {
        let translocatedFrom = originalIfTranslocated(bundle)
        let original = translocatedFrom ?? bundle
        return Location(
            running: bundle, original: original, isTranslocated: translocatedFrom != nil, diskImage: diskImage(original))
    }
}

/// Security.framework's two translocation functions, exported without a public header: resolved with `dlsym`, no link
/// flags. A missing symbol reads as "not translocated".
private enum Translocation {
    private typealias IsTranslocated = @convention(c) (
        CFURL, UnsafeMutablePointer<Bool>, UnsafeMutablePointer<Unmanaged<CFError>?>?
    ) -> UInt8
    private typealias CreateOriginal = @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?

    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        // RTLD_DEFAULT
        dlsym(UnsafeMutableRawPointer(bitPattern: -2), name).map { unsafeBitCast($0, to: type) }
    }

    static func original(of bundle: URL) -> URL? {
        guard let isTranslocated = symbol("SecTranslocateIsTranslocatedURL", as: IsTranslocated.self),
            let createOriginal = symbol("SecTranslocateCreateOriginalPathForURL", as: CreateOriginal.self)
        else { return nil }
        var translocated = false
        guard isTranslocated(bundle as CFURL, &translocated, nil) != 0, translocated,
            let original = createOriginal(bundle as CFURL, nil)?.takeRetainedValue()
        else { return nil }
        return original as URL
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
