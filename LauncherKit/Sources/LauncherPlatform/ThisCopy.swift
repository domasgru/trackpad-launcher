import AppKit
import LauncherCore

/// Facts about this process, parsed once into core types.
public enum ThisCopy {
    /// The `oapp` of a start (read in didFinishLaunching: the event is nil in willFinishLaunching). `.atLogin` when it
    /// carries the login-item marker; otherwise, and for nil, `.byHand`.
    public static func launch(event: NSAppleEventDescriptor?, arguments: [String]) -> Launch {
        Launch(opening: opening(of: event))
    }

    /// A reopen (`aevt/rapp`): `.atLogin` only when it carries the login marker; otherwise, and for nil, `.byHand`.
    public static func opening(of event: NSAppleEventDescriptor?) -> Opening {
        let marker = event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
        return marker == OSType(keyAELaunchedAsLogInItem) ? .atLogin : .byHand
    }
}
